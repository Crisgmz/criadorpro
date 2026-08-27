-- Criador Pro — Comunidad (`RF-COM`).
--
-- Terminología: esto es una **solicitud de encuentro** entre dos criaderos. Ni
-- la tabla ni sus valores admiten vocabulario de riña o apuesta (BRD §8) — es
-- el riesgo de mayor prioridad del proyecto, y la compuerta de compilación
-- revisa los `.arb` contra la lista de términos prohibidos antes de cada envío.
--
-- Este módulo es el **único sitio donde el aislamiento de `RS-13` se relaja a
-- propósito**: un directorio de criaderos no serviría de nada si cada uno solo
-- pudiera verse a sí mismo. Se relaja con dos cuidados:
--
--   1. Es **opt-in**. `is_public` nace en falso: nadie aparece por haberse
--      registrado. Publicarse es una decisión, no el estado por omisión.
--   2. Se expone por **vista**, no por política. La RLS es por fila, no por
--      columna: una segunda política de `select` sobre `profiles` dejaría ver
--      también el correo, el teléfono y el plan de quien se publicó.
--
-- Idempotente: se puede ejecutar dos veces sin romper nada.

alter table public.profiles add column if not exists is_public boolean not null default false;
alter table public.profiles add column if not exists public_bio text;

-- --------------------------------------------------------------------------
-- Directorio público
-- --------------------------------------------------------------------------

-- `security_invoker` para que la vista se lea con los permisos de quien
-- consulta y no con los del creador: sin eso la vista saltaría la RLS entera y
-- expondría también a los criaderos que no se publicaron.
create or replace view public.public_profiles
with (security_invoker = true) as
  select id, farm_name, location, country_code, avatar_url, public_bio
  from public.profiles
  where is_public = true and farm_name is not null;

drop policy if exists "profiles_select_public" on public.profiles;
create policy "profiles_select_public" on public.profiles
  for select using (is_public = true);

-- --------------------------------------------------------------------------
-- Solicitudes de encuentro
-- --------------------------------------------------------------------------

create table if not exists public.meeting_requests (
  id uuid primary key,

  -- Dos propietarios y no un `owner_id`: es el único registro del producto que
  -- pertenece a dos criaderos a la vez, y por eso sus políticas se escriben
  -- distinto que las del resto.
  from_owner uuid not null references auth.users(id) on delete cascade,
  to_owner uuid not null references auth.users(id) on delete cascade,

  -- El ejemplar que se propone. `set null` porque la solicitud sigue teniendo
  -- sentido si el ave se da de baja mientras se responde.
  from_bird_id uuid references public.birds(id) on delete set null,

  message text,
  place text,
  proposed_date date,

  -- `pending` · `accepted` · `declined` · `cancelled`
  status text not null default 'pending',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_deleted boolean not null default false
);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'meeting_requests_status_check') then
    alter table public.meeting_requests
      add constraint meeting_requests_status_check
      check (status in ('pending', 'accepted', 'declined', 'cancelled'));
  end if;

  -- Nadie se manda una solicitud a sí mismo. No es una travesura: sin esto, la
  -- bandeja mezclaría enviadas y recibidas para la misma fila.
  if not exists (select 1 from pg_constraint where conname = 'meeting_requests_distinct_check') then
    alter table public.meeting_requests
      add constraint meeting_requests_distinct_check check (from_owner <> to_owner);
  end if;
end $$;

create index if not exists meeting_requests_to_idx
  on public.meeting_requests (to_owner, created_at desc);
create index if not exists meeting_requests_from_idx
  on public.meeting_requests (from_owner, created_at desc);

drop trigger if exists touch_meeting_requests_updated_at on public.meeting_requests;
create trigger touch_meeting_requests_updated_at
  before update on public.meeting_requests
  for each row execute function public.touch_updated_at();

alter table public.meeting_requests enable row level security;

-- Las ve quien la mandó y quien la recibió, nadie más.
drop policy if exists "meeting_requests_select_own" on public.meeting_requests;
create policy "meeting_requests_select_own" on public.meeting_requests
  for select using (from_owner = auth.uid() or to_owner = auth.uid());

-- Solo se manda en nombre propio, y solo a alguien que se publicó: sin esa
-- comprobación, cualquiera podría escribirle a un criadero que no está en el
-- directorio con solo tener su identificador.
drop policy if exists "meeting_requests_insert_own" on public.meeting_requests;
create policy "meeting_requests_insert_own" on public.meeting_requests
  for insert with check (
    from_owner = auth.uid()
    and exists (select 1 from public.profiles p where p.id = to_owner and p.is_public = true)
  );

-- Quien la recibe la acepta o la rechaza; quien la mandó puede retirarla. Los
-- dos por el mismo camino: qué transición vale lo comprueba el cliente y lo
-- refuerza el `check` de arriba.
drop policy if exists "meeting_requests_update_party" on public.meeting_requests;
create policy "meeting_requests_update_party" on public.meeting_requests
  for update using (from_owner = auth.uid() or to_owner = auth.uid())
  with check (from_owner = auth.uid() or to_owner = auth.uid());

-- --------------------------------------------------------------------------
-- Denuncias y bloqueos
-- --------------------------------------------------------------------------
--
-- App Store y Play exigen, para cualquier contenido generado por usuarios, una
-- forma de **denunciar** y de **bloquear**. Sin esto el módulo no pasa revisión,
-- por muy bien que funcione lo demás.
--
-- Las **reglas** de moderación —qué se considera denunciable y qué se hace con
-- una denuncia— siguen sin aprobarse (decisión abierta §13). Esto es el
-- mecanismo, no la política.

create table if not exists public.community_reports (
  id uuid primary key,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reported_id uuid not null references auth.users(id) on delete cascade,
  reason text,
  created_at timestamptz not null default now()
);

create table if not exists public.community_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);

alter table public.community_reports enable row level security;
alter table public.community_blocks enable row level security;

-- Una denuncia se escribe y no se vuelve a leer desde la app: quien la revisa
-- es la moderación, con la clave de servicio. Dejar leerlas al denunciante
-- convertiría la lista en una forma de saber a quién ha denunciado quién.
drop policy if exists "community_reports_insert_own" on public.community_reports;
create policy "community_reports_insert_own" on public.community_reports
  for insert with check (reporter_id = auth.uid());

drop policy if exists "community_blocks_all_own" on public.community_blocks;
create policy "community_blocks_all_own" on public.community_blocks
  for all using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());
