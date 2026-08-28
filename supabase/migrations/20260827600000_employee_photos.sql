-- Criador Pro — fotos del personal (pantalla 30).
--
-- Bucket aparte del de los ejemplares y no una carpeta dentro: la foto de una
-- persona no es la de un ave. Separarlos permite borrar unas sin tocar las
-- otras, y darles políticas o límites distintos el día que haga falta.
--
-- Mismas reglas que `bird-photos`: privado, ruta `{owner_id}/{employee_id}.jpg`
-- con el propietario en el primer segmento —es lo que comparan las políticas—,
-- y 2 MB por archivo.
--
-- Idempotente: se puede ejecutar dos veces sin romper nada.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('employee-photos', 'employee-photos', false, 2097152, array['image/jpeg', 'image/png'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "employee_photos_select_own" on storage.objects;
create policy "employee_photos_select_own" on storage.objects
  for select using (
    bucket_id = 'employee-photos' and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "employee_photos_insert_own" on storage.objects;
create policy "employee_photos_insert_own" on storage.objects
  for insert with check (
    bucket_id = 'employee-photos' and (storage.foldername(name))[1] = auth.uid()::text
  );

-- El `update` hace falta para que subir con `upsert: true` sustituya la foto
-- anterior; sin él, cambiarla fallaría en silencio.
drop policy if exists "employee_photos_update_own" on storage.objects;
create policy "employee_photos_update_own" on storage.objects
  for update using (
    bucket_id = 'employee-photos' and (storage.foldername(name))[1] = auth.uid()::text
  ) with check (
    bucket_id = 'employee-photos' and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "employee_photos_delete_own" on storage.objects;
create policy "employee_photos_delete_own" on storage.objects
  for delete using (
    bucket_id = 'employee-photos' and (storage.foldername(name))[1] = auth.uid()::text
  );
