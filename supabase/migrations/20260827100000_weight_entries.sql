-- Criador Pro — historial de pesos (`RF-REG-14`).
--
-- `birds.weight_g` guardaba **un solo** peso, así que anotar el de hoy borraba
-- el de la semana pasada. Esa columna se queda como peso vigente —la lista y la
-- ficha la leen por fila—, pero pasa a ser un **dato derivado**: quien manda es
-- la pesada más reciente de esta tabla, y solo la escribe el cliente al
-- recalcularla.
--
-- El peso va en gramos enteros, como en `birds`: la báscula del galpón marca
-- gramos y la presentación en kilos es cosa de la pantalla.
--
-- Idempotente: se puede ejecutar dos veces sin romper nada.

create table if not exists public.weight_entries (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,

  -- `cascade`: la pesada de un ejemplar borrado no significa nada. A diferencia
  -- de los pagos de nómina, aquí no hay un mes cerrado que dependa del dato.
  bird_id uuid not null references public.birds(id) on delete cascade,

  weight_g integer not null,
  date date not null,

  -- Prueba de campo de la que salió (`RF-PRU-07`). `set null` y no `cascade`:
  -- si la prueba desaparece, la pesada sigue siendo cierta — al ave la pesaron.
  evaluation_id uuid references public.evaluations(id) on delete set null,

  notes text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_deleted boolean not null default false
);

do $$
begin
  -- Solo se rechaza lo que no es un peso. `RV-12` (100–8.000 g) **advierte y no
  -- bloquea**: un pollito de 90 g existe, y la app no puede obligar al criador
  -- a mentirle.
  if not exists (select 1 from pg_constraint where conname = 'weight_entries_positive_check') then
    alter table public.weight_entries
      add constraint weight_entries_positive_check check (weight_g > 0);
  end if;

  -- Una prueba genera **una** pesada. Es lo que hace idempotente el registro:
  -- editar la misma prueba tres veces no puede dejar tres pesadas que nadie
  -- hizo. El índice parcial deja fuera las anotadas a mano, que no tienen
  -- prueba y serían todas `null`.
  if not exists (
    select 1 from pg_indexes
    where schemaname = 'public' and indexname = 'weight_entries_evaluation_unique'
  ) then
    create unique index weight_entries_evaluation_unique
      on public.weight_entries (evaluation_id)
      where evaluation_id is not null and is_deleted = false;
  end if;
end $$;

-- El historial se consulta siempre por ejemplar y en orden de fecha.
create index if not exists weight_entries_bird_date_idx
  on public.weight_entries (bird_id, date desc);

drop trigger if exists touch_weight_entries_updated_at on public.weight_entries;
create trigger touch_weight_entries_updated_at
  before update on public.weight_entries
  for each row execute function public.touch_updated_at();

-- `RS-13` · `RNF-16`.
alter table public.weight_entries enable row level security;

drop policy if exists "weight_entries_select_own" on public.weight_entries;
create policy "weight_entries_select_own" on public.weight_entries
  for select using (owner_id = auth.uid());

drop policy if exists "weight_entries_insert_own" on public.weight_entries;
create policy "weight_entries_insert_own" on public.weight_entries
  for insert with check (owner_id = auth.uid());

drop policy if exists "weight_entries_update_own" on public.weight_entries;
create policy "weight_entries_update_own" on public.weight_entries
  for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists "weight_entries_delete_own" on public.weight_entries;
create policy "weight_entries_delete_own" on public.weight_entries
  for delete using (owner_id = auth.uid());

-- **Sin semilla aquí.** El peso que cada ejemplar ya tuviera se convierte en su
-- primera pesada en el cliente (migración local v10), con un identificador
-- derivado del propio ejemplar. Sembrarlo también en el servidor crearía dos
-- pesadas para la misma báscula: una con el id del cliente y otra con el de
-- aquí. `RS-14` es explícito — los identificadores los genera el cliente.
