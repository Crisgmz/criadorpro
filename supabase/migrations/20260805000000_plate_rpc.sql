-- Criador Pro — funciones de servidor para la numeración de placas.
--
-- `next_plate()` es la que sostiene `RS-01`: la placa se reserva en el
-- servidor, no en el cliente. Dos dispositivos del mismo criador registrando a
-- la vez —cosa normal cuando alguien tiene el teléfono y la tablet en el
-- galpón— generarían placas repetidas si el contador viviera solo en local.
--
-- Idempotente: se puede volver a ejecutar sin romper nada.

-- ---------------------------------------------------------------------------
-- next_plate(p_owner, p_count) — reserva un bloque y devuelve la primera
--
-- El UPDATE toma un bloqueo de fila, así que dos llamadas simultáneas se
-- serializan y ninguna ve el mismo valor. Devuelve el inicio del rango: quien
-- pide 8 placas desde la 1688 recibe 1688 y usa hasta la 1695.
--
-- Eliminar un ejemplar no lo decrementa nunca (`RS-01`): la placa gastada no
-- se reasigna.
-- ---------------------------------------------------------------------------

create or replace function public.next_plate(p_owner uuid, p_count int default 1)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_start integer;
begin
  if p_count < 1 then
    raise exception 'p_count debe ser al menos 1';
  end if;

  -- `security definer` se salta la RLS, así que la pertenencia se comprueba
  -- aquí: sin esto, cualquiera podría avanzar el contador de otro criadero.
  if p_owner is distinct from auth.uid() then
    raise exception 'no autorizado';
  end if;

  update public.profiles
     set next_plate = next_plate + p_count
   where id = p_owner
  returning next_plate - p_count into v_start;

  if v_start is null then
    raise exception 'perfil no encontrado';
  end if;

  return v_start;
end;
$$;

revoke all on function public.next_plate(uuid, int) from public;
grant execute on function public.next_plate(uuid, int) to authenticated;

-- ---------------------------------------------------------------------------
-- active_bird_count(p_owner) — conteo autoritativo para el límite de plan
--
-- `RS-02`: cuenta solo los activos y no borrados. El cliente lleva su propio
-- conteo local para poder decidir sin conexión; este es el que manda cuando la
-- hay.
-- ---------------------------------------------------------------------------

create or replace function public.active_bird_count(p_owner uuid)
returns integer
language sql
security definer
set search_path = public
stable
as $$
  select count(*)::int
    from public.birds
   where owner_id = p_owner
     and p_owner = auth.uid()
     and status = 'active'
     and is_deleted = false;
$$;

revoke all on function public.active_bird_count(uuid) from public;
grant execute on function public.active_bird_count(uuid) to authenticated;
