-- Criador Pro — el plan solo lo escribe el servidor (`RS-12`).
--
-- `profiles_update_own` deja al criador actualizar **cualquier** columna de su
-- propia fila, `plan` y `plan_expires_at` incluidas. La clave publicable es
-- pública por diseño —lo que protege los datos es la RLS—, así que con esa
-- clave y una sesión normal basta un `PATCH` para darse Élite gratis:
--
--   PATCH /rest/v1/profiles?id=eq.<uno mismo>   {"plan": "elite"}
--
-- El cliente de la app no lo hace: `Profile.toRemoteJson()` deja el plan fuera
-- a propósito. Pero eso es que el cliente se porte bien, no que la base lo
-- impida — y `RS-13` dice que el aislamiento se impone en la base, no en la
-- aplicación. Lo mismo vale aquí.
--
-- El disparador revierte en silencio cualquier cambio de esas dos columnas que
-- no venga del `service_role`, que es el único que usa `verify_receipt`. Se
-- revierte en vez de fallar para que una escritura legítima del perfil —nombre,
-- ubicación, idioma— siga funcionando aunque el payload arrastre el plan viejo.
--
-- `next_plate` **no** se bloquea: el onboarding lo fija desde el cliente una
-- vez, y es lo que permite migrar el libro sin retranscribirlo. A partir de ahí
-- solo lo mueve la RPC `next_plate()`.
--
-- Idempotente: se puede ejecutar dos veces sin romper nada.

create or replace function public.lock_plan_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- `service_role` es quien valida el recibo. Cualquier otro rol —incluido el
  -- criador autenticado— se queda con el plan que ya tenía.
  if auth.role() = 'service_role' then
    return new;
  end if;

  new.plan := old.plan;
  new.plan_expires_at := old.plan_expires_at;
  return new;
end;
$$;

drop trigger if exists lock_plan_on_profiles on public.profiles;
create trigger lock_plan_on_profiles
  before update on public.profiles
  for each row execute function public.lock_plan_columns();
