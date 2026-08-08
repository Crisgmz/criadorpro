-- Criador Pro — esquema inicial.
--
-- Ejecútalo en el SQL Editor de Supabase (o con `supabase db push`).
-- Cubre las tablas que usa la app hoy: profiles, birds y clutches.
-- Las de contabilidad, nómina y evaluaciones llegarán con sus features.

-- ---------------------------------------------------------------------------
-- Tablas
-- ---------------------------------------------------------------------------

create table if not exists public.profiles (
  id              uuid primary key references auth.users (id) on delete cascade,
  email           text,
  full_name       text,
  breeder_name    text,
  country         text,
  phone           text,
  plan            text        not null default 'free' check (plan in ('free', 'pro', 'elite')),
  plan_expires_at timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  is_deleted      boolean     not null default false
);

create table if not exists public.clutches (
  id            uuid primary key,
  owner_id      uuid        not null references auth.users (id) on delete cascade,
  code          text        not null,
  father_id     uuid,
  mother_id     uuid,
  laying_date   date,
  hatch_date    date,
  egg_count     integer,
  hatched_count integer,
  notes         text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  is_deleted    boolean     not null default false
);

create table if not exists public.birds (
  id           uuid primary key,
  owner_id     uuid        not null references auth.users (id) on delete cascade,
  name         text        not null,
  ring_number  text,
  sex          text        not null default 'unknown' check (sex in ('male', 'female', 'unknown')),
  status       text        not null default 'active'
                 check (status in ('active', 'sold', 'deceased', 'transferred')),
  birth_date   date,
  color        text,
  lineage      text,
  weight_grams real,
  father_id    uuid,
  mother_id    uuid,
  clutch_id    uuid,
  photo_url    text,
  notes        text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  is_deleted   boolean     not null default false
);

-- Las referencias genealógicas se añaden aparte porque birds y clutches se
-- apuntan mutuamente y no se pueden declarar en el CREATE TABLE.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'birds_father_fk') then
    alter table public.birds
      add constraint birds_father_fk foreign key (father_id) references public.birds (id) on delete set null,
      add constraint birds_mother_fk foreign key (mother_id) references public.birds (id) on delete set null,
      add constraint birds_clutch_fk foreign key (clutch_id) references public.clutches (id) on delete set null;
  end if;

  if not exists (select 1 from pg_constraint where conname = 'clutches_father_fk') then
    alter table public.clutches
      add constraint clutches_father_fk foreign key (father_id) references public.birds (id) on delete set null,
      add constraint clutches_mother_fk foreign key (mother_id) references public.birds (id) on delete set null;
  end if;
end $$;

-- La bajada incremental filtra por owner_id + updated_at: sin estos índices
-- cada sincronización sería un seq scan.
create index if not exists birds_owner_updated_idx on public.birds (owner_id, updated_at desc);
create index if not exists clutches_owner_updated_idx on public.clutches (owner_id, updated_at desc);

-- ---------------------------------------------------------------------------
-- updated_at lo pone el servidor
--
-- El cliente también lo manda, pero el reloj de un móvil puede ir desfasado y
-- eso rompería el orden de la sincronización. Mandan siempre las marcas del
-- servidor.
-- ---------------------------------------------------------------------------

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at before insert or update on public.profiles
  for each row execute function public.touch_updated_at();

drop trigger if exists birds_touch_updated_at on public.birds;
create trigger birds_touch_updated_at before insert or update on public.birds
  for each row execute function public.touch_updated_at();

drop trigger if exists clutches_touch_updated_at on public.clutches;
create trigger clutches_touch_updated_at before insert or update on public.clutches
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Perfil automático al registrarse
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email) values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- RLS: cada criadero solo ve lo suyo
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.birds    enable row level security;
alter table public.clutches enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles for select using (id = (select auth.uid()));

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles for insert with check (id = (select auth.uid()));

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles for update
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

drop policy if exists birds_select_own on public.birds;
create policy birds_select_own on public.birds for select using (owner_id = (select auth.uid()));

drop policy if exists birds_insert_own on public.birds;
create policy birds_insert_own on public.birds for insert with check (owner_id = (select auth.uid()));

drop policy if exists birds_update_own on public.birds;
create policy birds_update_own on public.birds for update
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));

drop policy if exists birds_delete_own on public.birds;
create policy birds_delete_own on public.birds for delete using (owner_id = (select auth.uid()));

drop policy if exists clutches_select_own on public.clutches;
create policy clutches_select_own on public.clutches for select using (owner_id = (select auth.uid()));

drop policy if exists clutches_insert_own on public.clutches;
create policy clutches_insert_own on public.clutches for insert with check (owner_id = (select auth.uid()));

drop policy if exists clutches_update_own on public.clutches;
create policy clutches_update_own on public.clutches for update
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));

drop policy if exists clutches_delete_own on public.clutches;
create policy clutches_delete_own on public.clutches for delete using (owner_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- Borrado de cuenta
--
-- App Store lo exige. Borra el usuario de auth y el ON DELETE CASCADE se lleva
-- perfil, ejemplares y camadas.
-- ---------------------------------------------------------------------------

create or replace function public.delete_current_user()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_uid uuid := auth.uid();
begin
  if current_uid is null then
    raise exception 'No hay usuario autenticado';
  end if;
  delete from auth.users where id = current_uid;
end;
$$;

revoke all on function public.delete_current_user() from public;
grant execute on function public.delete_current_user() to authenticated;
