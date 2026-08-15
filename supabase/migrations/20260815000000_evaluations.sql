-- Criador Pro — pruebas de campo (`RF-PRU`).
--
-- Terminología: esto es una **evaluación de rendimiento**. Ni la tabla ni sus
-- valores admiten vocabulario de riña o apuesta (BRD §8), y el catálogo de
-- resultados es cerrado: favorable · unfavorable · undefined.
--
-- Idempotente: se puede ejecutar dos veces sin romper nada.

create table if not exists public.evaluations (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,

  -- El ejemplar evaluado. `on delete cascade`: borrar un ejemplar de verdad
  -- —solo ocurre al eliminar la cuenta— se lleva sus pruebas.
  bird_id uuid not null references public.birds(id) on delete cascade,

  date date not null,
  place text,
  result text not null default 'undefined',
  condition integer,
  weight_g integer,
  notes text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_deleted boolean not null default false
);

-- Catálogo cerrado de resultados.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'evaluations_result_check') then
    alter table public.evaluations
      add constraint evaluations_result_check
      check (result in ('favorable', 'unfavorable', 'undefined'));
  end if;

  if not exists (select 1 from pg_constraint where conname = 'evaluations_condition_check') then
    alter table public.evaluations
      add constraint evaluations_condition_check
      check (condition is null or condition between 1 and 10);
  end if;

  -- Mismo rango que `birds.weight_g` (`RV-12`).
  if not exists (select 1 from pg_constraint where conname = 'evaluations_weight_check') then
    alter table public.evaluations
      add constraint evaluations_weight_check
      check (weight_g is null or weight_g between 100 and 8000);
  end if;
end $$;

-- `evaluations(bird_id, date)` — el índice que pide el SRS: sostiene tanto el
-- historial de la ficha como el listado general, que ordena por fecha.
create index if not exists evaluations_bird_date_idx
  on public.evaluations (bird_id, date desc);

create index if not exists evaluations_owner_date_idx
  on public.evaluations (owner_id, date desc);

-- `updated_at` al día: es la base de la resolución de conflictos (`RS-09`).
drop trigger if exists touch_evaluations_updated_at on public.evaluations;
create trigger touch_evaluations_updated_at
  before update on public.evaluations
  for each row execute function public.touch_updated_at();

-- `RS-13` · `RNF-16`: el aislamiento entre criaderos se impone aquí, no en la
-- aplicación. Ninguna consulta puede devolver filas de otro propietario aunque
-- el cliente esté mal escrito.
alter table public.evaluations enable row level security;

drop policy if exists "evaluations_select_own" on public.evaluations;
create policy "evaluations_select_own" on public.evaluations
  for select using (owner_id = auth.uid());

drop policy if exists "evaluations_insert_own" on public.evaluations;
create policy "evaluations_insert_own" on public.evaluations
  for insert with check (owner_id = auth.uid());

drop policy if exists "evaluations_update_own" on public.evaluations;
create policy "evaluations_update_own" on public.evaluations
  for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists "evaluations_delete_own" on public.evaluations;
create policy "evaluations_delete_own" on public.evaluations
  for delete using (owner_id = auth.uid());
