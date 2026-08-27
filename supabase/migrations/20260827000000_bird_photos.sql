-- Criador Pro — almacenamiento de las fotos de los ejemplares (`RF-REG-15`).
--
-- Bucket **privado**: la foto de un ejemplar es del criadero que la tomó, y un
-- bucket público la dejaría accesible a cualquiera con la URL, sin sesión.
-- Se lee con la credencial del usuario, y las políticas de abajo son las que
-- imponen el aislamiento (`RS-13` · `RNF-16`).
--
-- La ruta de cada objeto es `{owner_id}/{bird_id}.jpg`. El primer segmento es
-- el propietario a propósito: es lo que las políticas comparan contra
-- `auth.uid()`. Y es determinista, así que volver a subir **sustituye** en
-- lugar de acumular — con nombres aleatorios, cambiar cinco veces la foto de un
-- ejemplar dejaría cuatro huérfanas que nadie borraría nunca.
--
-- Idempotente: se puede ejecutar dos veces sin romper nada.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'bird-photos',
  'bird-photos',
  false,
  -- `RV-19` — 2 MB por foto. El cliente ya recomprime hasta cumplirlo; esto es
  -- el tope que no depende de que el cliente esté bien escrito.
  2097152,
  array['image/jpeg', 'image/png']
)
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- `storage.foldername(name)` devuelve los segmentos de la ruta; el primero es
-- el `owner_id`. Comparar contra `auth.uid()` es lo que impide que un criadero
-- lea, escriba o borre las fotos de otro.

drop policy if exists "bird_photos_select_own" on storage.objects;
create policy "bird_photos_select_own" on storage.objects
  for select using (
    bucket_id = 'bird-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "bird_photos_insert_own" on storage.objects;
create policy "bird_photos_insert_own" on storage.objects
  for insert with check (
    bucket_id = 'bird-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- El `update` hace falta para que subir con `upsert: true` pueda sustituir la
-- foto anterior; sin él, cambiar la foto de un ejemplar fallaría en silencio.
drop policy if exists "bird_photos_update_own" on storage.objects;
create policy "bird_photos_update_own" on storage.objects
  for update using (
    bucket_id = 'bird-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  ) with check (
    bucket_id = 'bird-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "bird_photos_delete_own" on storage.objects;
create policy "bird_photos_delete_own" on storage.objects
  for delete using (
    bucket_id = 'bird-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
