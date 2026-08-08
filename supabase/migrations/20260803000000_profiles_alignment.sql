-- Criador Pro — alineación de `profiles` con el SRS §3.
--
-- El alta (`RF-AUT-03`) manda nombre, teléfono, país e idioma como metadatos
-- del usuario, pero `handle_new_user()` solo guardaba `id` y `email`: esos
-- datos se perdían. Esta migración pone las columnas que especifica el SRS y
-- hace que el trigger las lea.
--
-- Es idempotente: se puede ejecutar sobre una base ya migrada sin romper nada.

-- ---------------------------------------------------------------------------
-- 1. Renombres — `breeder_name` → `farm_name`, `country` → `country_code`
-- ---------------------------------------------------------------------------

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'breeder_name'
  ) then
    alter table public.profiles rename column breeder_name to farm_name;
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'country'
  ) then
    alter table public.profiles rename column country to country_code;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Columnas que faltaban
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column if not exists farm_name    text,
  add column if not exists location     text,
  add column if not exists country_code char(2),
  add column if not exists locale       char(2),
  -- `RS-01`: el contador de placas del criadero. Arranca en 1 y solo crece;
  -- eliminar un ejemplar no lo decrementa ni libera su placa.
  add column if not exists next_plate   integer,
  add column if not exists avatar_url   text;

-- ---------------------------------------------------------------------------
-- 3. Tipos y relleno de las filas existentes antes de imponer NOT NULL
--
-- `country_code` y `locale` pueden llegar por dos caminos: nuevas con el tipo
-- correcto, o heredadas del rename de `country`, que era `text` libre. Se
-- normaliza el contenido primero y se estrecha el tipo después; al revés,
-- un valor como «República Dominicana» reventaría el ALTER.
-- ---------------------------------------------------------------------------

-- Un código ISO tiene exactamente dos letras; cualquier otra cosa era texto
-- libre del esquema anterior y no se puede rescatar.
update public.profiles
set country_code = case
  when country_code ~ '^[A-Za-z]{2}$' then upper(trim(country_code))
  else 'DO'
end;

update public.profiles
set locale = case
  when lower(trim(coalesce(locale, ''))) in ('es', 'en') then lower(trim(locale))
  else 'es'
end;

update public.profiles
set
  email = lower(coalesce(nullif(trim(email), ''), '')),
  -- Cada alternativa se anula si queda vacía, para que el `coalesce` siga
  -- bajando: con `split_part` de un correo vacío obtendríamos '' y el CHECK
  -- de longitud mínima rechazaría la fila.
  full_name = coalesce(
    nullif(trim(full_name), ''),
    nullif(split_part(coalesce(email, ''), '@', 1), ''),
    'Criador'
  ),
  next_plate = coalesce(next_plate, 1);

alter table public.profiles
  alter column country_code type char(2) using left(country_code, 2),
  alter column locale       type char(2) using left(locale, 2);

-- ---------------------------------------------------------------------------
-- 4. Restricciones y valores por omisión
--
-- `farm_name` y `location` quedan NULOS a propósito, aunque el SRS los liste
-- como no nulos: el perfil nace en el alta y el nombre del criadero se pide
-- después, en el onboarding (`RF-ONB-01`). `farm_name is null` es justo la
-- señal de «configuración pendiente» que la guardia del router necesita.
-- ---------------------------------------------------------------------------

alter table public.profiles
  alter column email        set not null,
  alter column full_name    set not null,
  alter column country_code set not null,
  alter column country_code set default 'DO',
  alter column locale       set not null,
  alter column locale       set default 'es',
  alter column next_plate   set not null,
  alter column next_plate   set default 1;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_locale_check') then
    alter table public.profiles
      add constraint profiles_locale_check check (locale in ('es', 'en'));
  end if;

  if not exists (select 1 from pg_constraint where conname = 'profiles_next_plate_check') then
    alter table public.profiles
      add constraint profiles_next_plate_check check (next_plate >= 1);
  end if;

  if not exists (select 1 from pg_constraint where conname = 'profiles_full_name_check') then
    alter table public.profiles
      add constraint profiles_full_name_check check (char_length(full_name) between 1 and 80);
  end if;

  if not exists (select 1 from pg_constraint where conname = 'profiles_farm_name_check') then
    alter table public.profiles
      add constraint profiles_farm_name_check
      check (farm_name is null or char_length(farm_name) between 2 and 60);
  end if;

  if not exists (select 1 from pg_constraint where conname = 'profiles_location_check') then
    alter table public.profiles
      add constraint profiles_location_check
      check (location is null or char_length(location) <= 120);
  end if;
end $$;

-- El correo ya es único en `auth.users`; el índice aquí evita que una escritura
-- del cliente introduzca un duplicado por otra vía (`RV-01`). Es parcial porque
-- una cuenta creada sin correo (teléfono, o un proveedor que no lo entregue)
-- guarda cadena vacía, y dos vacías no deben colisionar entre sí.
create unique index if not exists profiles_email_key
  on public.profiles (lower(email))
  where email <> '';

-- ---------------------------------------------------------------------------
-- 5. `handle_new_user()` — ahora lee los metadatos del alta
--
-- Cualquier excepción aquí haría fallar el registro entero con un opaco
-- «Database error saving new user», así que todo valor se sanea antes de
-- insertarse y nada depende de que el metadato exista: el acceso con Google o
-- Apple no trae teléfono, y puede no traer nombre.
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  meta        jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_email     text  := lower(coalesce(new.email, ''));
  v_full_name text;
  v_locale    text;
begin
  v_full_name := nullif(trim(coalesce(meta ->> 'full_name', meta ->> 'name', '')), '');
  -- Sin nombre, la parte local del correo es mejor marcador que una cadena
  -- vacía: el usuario lo corrige luego en «Datos del criadero».
  v_full_name := left(coalesce(v_full_name, nullif(split_part(v_email, '@', 1), ''), 'Criador'), 80);

  v_locale := lower(coalesce(nullif(meta ->> 'locale', ''), 'es'));
  if v_locale not in ('es', 'en') then
    v_locale := 'es';
  end if;

  insert into public.profiles (id, email, full_name, phone, country_code, locale, next_plate, plan)
  values (
    new.id,
    v_email,
    v_full_name,
    nullif(trim(coalesce(meta ->> 'phone', new.phone, '')), ''),
    upper(left(coalesce(nullif(trim(meta ->> 'country_code'), ''), 'DO'), 2)),
    v_locale,
    1,
    'free'
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- 6. El cliente no decide su propio plan
--
-- `RS-12`: el plan lo escribe la validación del recibo en el servidor. Sin
-- esto, cualquiera podría ascenderse a Élite con un UPDATE desde la app.
-- ---------------------------------------------------------------------------

create or replace function public.protect_profile_plan()
returns trigger
language plpgsql
as $$
begin
  -- `security definer` (el trigger de alta y, más adelante, verify_receipt())
  -- corre como propietario de la tabla y sí puede cambiarlo.
  if auth.uid() is not null and auth.uid() = new.id then
    new.plan            := old.plan;
    new.plan_expires_at := old.plan_expires_at;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_protect_plan on public.profiles;
create trigger profiles_protect_plan before update on public.profiles
  for each row execute function public.protect_profile_plan();
