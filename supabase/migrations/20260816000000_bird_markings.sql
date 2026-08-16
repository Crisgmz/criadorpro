-- Criador Pro — marca de nacimiento en pie y pico.
--
-- El prototipo del PRD muestra este dato en la ficha del ejemplar («Marca de
-- nacimiento: 1 · 4») pero el esquema del SRS no lo recoge. Se añade porque es
-- como el criador reconoce al ave antes de que tenga placa.
--
-- `color` pasa de texto libre a clave de catálogo cerrado. Los valores que ya
-- existan se conservan tal cual: la app los muestra sin muestra de color en
-- lugar de perderlos.
--
-- Idempotente.

alter table public.birds
  add column if not exists foot_mark text,
  add column if not exists beak_mark text;

comment on column public.birds.foot_mark is
  'Marca en las membranas del pie. Formato «izquierda|derecha», posiciones 1-4 separadas por comas: 1,3|2';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'birds_beak_mark_check') then
    alter table public.birds
      add constraint birds_beak_mark_check
      check (beak_mark is null or beak_mark in ('upper', 'lower', 'left', 'right'));
  end if;
end $$;

-- `color` NO lleva CHECK a propósito: hay instalaciones con texto libre escrito
-- antes de cerrar el catálogo, y una restricción rechazaría su sincronización.
-- El catálogo se impone en el cliente, que es quien captura.
