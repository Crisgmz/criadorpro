-- Criador Pro — `birds` y `clutches` alineados con el SRS §3.
--
-- Es el cambio del que cuelga todo el registro: la placa deja de ser un texto
-- opcional («anilla») y pasa a ser un entero obligatorio y correlativo, que es
-- el eje del producto. El nombre pasa a opcional por el mismo motivo: el
-- criador anota placas, no nombres, y exigirle uno lo frenaría más que el papel.
--
-- Idempotente: se puede volver a ejecutar sin romper nada.

-- ---------------------------------------------------------------------------
-- 1. birds — renombres de columna
-- ---------------------------------------------------------------------------

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'birds' and column_name = 'lineage'
  ) then
    alter table public.birds rename column lineage to line;
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'birds' and column_name = 'weight_grams'
  ) then
    alter table public.birds rename column weight_grams to weight_g;
  end if;
end $$;

alter table public.birds add column if not exists plate integer;

-- ---------------------------------------------------------------------------
-- 2. birds — traslado de datos
--
-- `ring_number` era texto libre. Lo que ya parezca un número se conserva como
-- placa; el resto recibe una correlativa por criadero, porque una placa vacía
-- no es un estado admisible en el modelo nuevo.
-- ---------------------------------------------------------------------------

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'birds' and column_name = 'ring_number'
  ) then
    update public.birds
       set plate = nullif(regexp_replace(ring_number, '\D', '', 'g'), '')::integer
     where plate is null
       and ring_number ~ '\d';
  end if;
end $$;

-- A los que quedaron sin placa se les asigna una por orden de alta, arrancando
-- por encima de la más alta que ya tenga ese criadero.
with numbered as (
  select
    b.id,
    coalesce(
      (select max(x.plate) from public.birds x where x.owner_id = b.owner_id),
      0
    ) + row_number() over (partition by b.owner_id order by b.created_at, b.id) as assigned
  from public.birds b
  where b.plate is null
)
update public.birds b
   set plate = n.assigned
  from numbered n
 where b.id = n.id;

-- El contador del perfil nunca puede quedar por detrás de lo ya registrado, o
-- la próxima alta repetiría una placa (`RS-01`).
update public.profiles p
   set next_plate = greatest(p.next_plate, coalesce(m.max_plate, 0) + 1)
  from (
    select owner_id, max(plate) as max_plate from public.birds group by owner_id
  ) m
 where p.id = m.owner_id;

-- ---------------------------------------------------------------------------
-- 3. birds — tipos, restricciones y limpieza
-- ---------------------------------------------------------------------------

-- `weight_grams` era real; el SRS pide gramos enteros.
alter table public.birds
  alter column weight_g type integer using round(weight_g)::integer;

-- El nombre pasa a opcional. Las cadenas vacías se anulan: guardarlas obligaría
-- a distinguir «sin nombre» de «nombre en blanco» en cada consulta.
alter table public.birds alter column name drop not null;
update public.birds set name = null where trim(coalesce(name, '')) = '';

alter table public.birds alter column plate set not null;

-- `transferred` pasa a `loaned`, que es el término del catálogo cerrado.
do $$
begin
  if exists (select 1 from pg_constraint where conname = 'birds_status_check') then
    alter table public.birds drop constraint birds_status_check;
  end if;
end $$;

update public.birds set status = 'loaned' where status = 'transferred';

alter table public.birds
  add constraint birds_status_check
  check (status in ('active', 'sold', 'deceased', 'loaned'));

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'birds_plate_check') then
    alter table public.birds add constraint birds_plate_check check (plate >= 1);
  end if;

  if not exists (select 1 from pg_constraint where conname = 'birds_weight_check') then
    alter table public.birds
      add constraint birds_weight_check
      check (weight_g is null or weight_g between 100 and 8000);
  end if;

  -- Un ejemplar no puede ser su propio progenitor (`RV-10`). El resto de la
  -- regla —que el padre sea macho y no descendiente— se comprueba en la app,
  -- porque exige recorrer el árbol.
  if not exists (select 1 from pg_constraint where conname = 'birds_no_self_parent') then
    alter table public.birds
      add constraint birds_no_self_parent
      check (id <> father_id and id <> mother_id);
  end if;
end $$;

alter table public.birds drop column if exists ring_number;

-- Búsqueda por placa y orden de la lista principal — `RNF-02`.
create index if not exists birds_owner_plate_idx on public.birds (owner_id, plate desc);
create index if not exists birds_owner_name_idx on public.birds (owner_id, name);

-- ---------------------------------------------------------------------------
-- 4. clutches — alineado con el SRS
--
-- El modelo nuevo guarda una sola fecha (la de nacimiento, que es la que pide
-- el registro de cruce) y los conteos de huevos y nacidos.
-- ---------------------------------------------------------------------------

alter table public.clutches
  add column if not exists date date,
  add column if not exists eggs integer,
  add column if not exists hatched integer;

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'clutches' and column_name = 'hatch_date'
  ) then
    update public.clutches set date = coalesce(date, hatch_date, laying_date);
    update public.clutches set eggs = coalesce(eggs, egg_count);
    update public.clutches set hatched = coalesce(hatched, hatched_count);
  end if;
end $$;

update public.clutches set date = coalesce(date, created_at::date) where date is null;
update public.clutches set hatched = coalesce(hatched, 1) where hatched is null;

alter table public.clutches
  alter column date set not null,
  alter column hatched set not null;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'clutches_eggs_check') then
    alter table public.clutches
      add constraint clutches_eggs_check check (eggs is null or eggs between 0 and 30);
  end if;

  if not exists (select 1 from pg_constraint where conname = 'clutches_hatched_check') then
    alter table public.clutches
      add constraint clutches_hatched_check
      check (hatched between 1 and 30 and (eggs is null or hatched <= eggs));
  end if;
end $$;

alter table public.clutches
  drop column if exists code,
  drop column if exists laying_date,
  drop column if exists hatch_date,
  drop column if exists egg_count,
  drop column if exists hatched_count;
