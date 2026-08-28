-- Criador Pro — borrado de cuenta (`RNF-20`, `RF-CTA-11`).
--
-- `delete_current_user()` ya existía desde la migración inicial y borraba la
-- fila de `auth.users` confiando en que el `on delete cascade` de cada tabla
-- arrastrara el resto. Para las tablas es cierto: perfil, ejemplares, camadas,
-- pruebas, movimientos, nómina, pesadas y solicitudes cuelgan todas de ahí.
--
-- **Las fotos no.** `storage.objects` no tiene clave foránea contra
-- `auth.users`, así que los buckets conservaban las imágenes del
-- criadero después de borrar la cuenta. El criador pulsaba «eliminar mi cuenta»
-- y sus fotos seguían en el servidor, que es exactamente lo que `RNF-20` dice
-- que no puede pasar — y lo que App Store revisa.
--
-- Idempotente: se puede ejecutar dos veces sin romper nada.

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

  -- Las fotos primero, y **antes** de borrar el usuario: después de borrarlo,
  -- `auth.uid()` deja de resolver y el prefijo con el que están guardadas
  -- (`{owner}/{bird}.jpg`) ya no se puede calcular.
  --
  -- Si esto falla, la transacción entera se deshace y la cuenta no se borra.
  -- Es lo correcto: una cuenta borrada a medias, con las fotos vivas, es peor
  -- que un borrado que hay que reintentar.
  delete from storage.objects
  where bucket_id in ('bird-photos', 'employee-photos')
    and (storage.foldername(name))[1] = current_uid::text;

  -- Y ahora sí. El resto cuelga de aquí por `on delete cascade`.
  delete from auth.users where id = current_uid;
end;
$$;

revoke all on function public.delete_current_user() from public;
grant execute on function public.delete_current_user() to authenticated;
