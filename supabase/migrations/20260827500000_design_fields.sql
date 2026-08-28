-- Criador Pro — los campos que pide el diseño y no estaban.
--
-- Salen del prototipo (pantallas 11, 21 y 30), que hasta ahora solo se había
-- visto en su versión de autenticación. Todos son nulos o con valor por
-- omisión: lo ya registrado sigue igual y ninguna app anterior se rompe.
--
-- Idempotente: se puede ejecutar dos veces sin romper nada.

-- --------------------------------------------------------------------------
-- Evaluaciones (pantalla 21)
-- --------------------------------------------------------------------------

-- El diseño distingue tres cosas que antes cabían todas en «prueba»: la prueba
-- de campo, la revisión física y la sesión de acondicionamiento. Sin el tipo,
-- las estadísticas mezclan un pesaje de rutina con una evaluación de
-- rendimiento y el porcentaje favorable deja de significar nada.
alter table public.evaluations
  add column if not exists type text not null default 'field_test';

alter table public.evaluations add column if not exists duration_min integer;

-- Índices de desempeño, «escala de 1 a 5 según observación del evaluador».
-- Sustituyen en la interfaz a `condition` (1–10 del SRS), que **se conserva**
-- para no perder lo ya registrado.
alter table public.evaluations add column if not exists stamina integer;
alter table public.evaluations add column if not exists agility integer;
alter table public.evaluations add column if not exists response integer;

alter table public.evaluations add column if not exists final_condition text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'evaluations_type_check') then
    alter table public.evaluations add constraint evaluations_type_check
      check (type in ('field_test', 'physical_check', 'conditioning'));
  end if;

  if not exists (select 1 from pg_constraint where conname = 'evaluations_indices_check') then
    alter table public.evaluations add constraint evaluations_indices_check check (
      (stamina  is null or stamina  between 1 and 5) and
      (agility  is null or agility  between 1 and 5) and
      (response is null or response between 1 and 5)
    );
  end if;

  if not exists (select 1 from pg_constraint where conname = 'evaluations_condition_check') then
    alter table public.evaluations add constraint evaluations_condition_check
      check (final_condition is null or final_condition in ('optimal', 'good', 'needs_rest'));
  end if;

  if not exists (select 1 from pg_constraint where conname = 'evaluations_duration_check') then
    alter table public.evaluations add constraint evaluations_duration_check
      check (duration_min is null or duration_min > 0);
  end if;
end $$;

-- --------------------------------------------------------------------------
-- Camadas (pantalla 11)
-- --------------------------------------------------------------------------

-- El estado del cruce es del criador, no del ave: dice si fue una prueba, si ya
-- está hecho, o si se repitió. Sin él, dos camadas de los mismos reproductores
-- son indistinguibles seis meses después.
alter table public.clutches
  add column if not exists cross_status text not null default 'done';

-- Marca de nacimiento y cintas **de toda la camada**. El diseño las captura una
-- vez al registrar el cruce, no ave por ave: las crías de una camada se marcan
-- igual, y repetirlo quince veces es lo que hace que no se marque ninguna.
alter table public.clutches add column if not exists birth_mark text;
alter table public.clutches add column if not exists wing_band_left text;
alter table public.clutches add column if not exists wing_band_right text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'clutches_cross_status_check') then
    alter table public.clutches add constraint clutches_cross_status_check
      check (cross_status in ('test', 'done', 'repeated'));
  end if;
end $$;

-- --------------------------------------------------------------------------
-- Empleados (pantalla 30)
-- --------------------------------------------------------------------------

-- `photo_url` viaja; la ruta local no, igual que en `birds`.
alter table public.employees add column if not exists photo_url text;
alter table public.employees add column if not exists start_date date;

-- --------------------------------------------------------------------------
-- Perfil
-- --------------------------------------------------------------------------

-- Unidad en que se **muestra** el peso. El almacenamiento sigue en gramos
-- enteros (SRS): esto es presentación. Libras por omisión, que es como pesa el
-- criador dominicano y lo que usa el diseño en todas las pantallas.
alter table public.profiles
  add column if not exists weight_unit text not null default 'lb';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_weight_unit_check') then
    alter table public.profiles add constraint profiles_weight_unit_check
      check (weight_unit in ('kg', 'lb'));
  end if;
end $$;
