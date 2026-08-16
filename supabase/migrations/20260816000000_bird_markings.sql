-- Criador Pro — marca de nacimiento y cintas de ala.
--
-- El prototipo las muestra en la ficha del ejemplar («Marca de nacimiento:
-- 1 · 4», «Cintas de ala: Roja · Azul») y las captura en el registro de cruce,
-- pero el esquema del SRS y del DDT no las recoge. Se añaden porque es como el
-- criador identifica una nidada antes de que las crías tengan placa.
--
-- Idempotente.

alter table public.birds
  add column if not exists birth_mark text,
  add column if not exists wing_band_left text,
  add column if not exists wing_band_right text;

comment on column public.birds.birth_mark is
  'Posiciones marcadas separadas por comas (1..6) o «none». 1-2 pie izquierdo, 3-4 pie derecho, 5-6 pico. «none» significa «se miró y no tiene»; nulo, «no se ha dicho».';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'birds_wing_band_left_check') then
    alter table public.birds
      add constraint birds_wing_band_left_check
      check (wing_band_left is null or wing_band_left in ('red','pink','blue','green','yellow'));
  end if;

  if not exists (select 1 from pg_constraint where conname = 'birds_wing_band_right_check') then
    alter table public.birds
      add constraint birds_wing_band_right_check
      check (wing_band_right is null or wing_band_right in ('red','pink','blue','green','yellow'));
  end if;
end $$;

-- `birth_mark` no lleva CHECK: el formato es una lista y validarlo en SQL
-- exigiría una expresión regular frágil. El cliente es quien captura, y ahí
-- está cubierto con pruebas.
