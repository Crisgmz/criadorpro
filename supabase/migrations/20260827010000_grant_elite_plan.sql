-- Criador Pro — ascenso de todos los criaderos existentes al plan Élite.
--
-- Concesión puntual, no una regla del producto: mientras `RF-CTA-04` a
-- `RF-CTA-12` (membresías y compra dentro de la app, fase 3) no existan, nadie
-- puede pagar, y dejar a los criaderos que ya están dentro con el tope de 25
-- ejemplares del plan Gratis les impide justamente lo que vinieron a hacer —
-- migrar su libro entero.
--
-- Élite es hoy el plan más alto: ejemplares ilimitados (`RS-02`), pedigrí de 4
-- generaciones (`RF-PED-03`), pruebas de campo, contabilidad y empleomanía.
--
-- `plan_expires_at` queda en NULL a propósito. `Profile.effectivePlan` degrada
-- a Gratis un plan de pago **con fecha vencida**; sin fecha, el plan no caduca.
-- Poner aquí una fecha futura sería fijar un día en que, sin previo aviso ni
-- pantalla de compra, a todo el mundo se le cerraría el libro.
--
-- No toca `handle_new_user()`: quien se dé de alta a partir de ahora nace en
-- Gratis, como manda el trigger. Esto es para los que ya están.
--
-- Sobre los dos triggers de `profiles` que intervienen aquí:
--
--   · `protect_profile_plan()` (`RS-12`) solo congela `plan` cuando quien
--     escribe es el propio dueño de la fila (`auth.uid() = new.id`). Una
--     migración corre sin sesión —`auth.uid()` es NULL—, así que pasa. Esa es
--     exactamente la puerta que la regla deja abierta al servidor.
--   · `touch_updated_at()` moverá `updated_at`. No hay riesgo de pisar una
--     edición local sin sincronizar (`RS-09`): `ProfileRepository.pull()` se
--     salta la bajada cuando el perfil tiene operaciones en la cola.
--
-- El cliente se entera sin hacer nada: el perfil se baja entero en cada ciclo
-- de sincronización, sin filtrar por `updated_at`, precisamente para que un
-- cambio de plan llegue aunque venga del servidor.
--
-- Idempotente: la segunda ejecución no encuentra filas que cambiar y ni
-- siquiera mueve `updated_at`.
--
-- Ojo al reejecutarla: si algún día se degrada a un criadero a mano, volver a
-- lanzar este archivo lo devuelve a Élite. Es una concesión con fecha, no parte
-- del esquema.

update public.profiles
   set plan            = 'elite',
       plan_expires_at = null
 where plan is distinct from 'elite'
    or plan_expires_at is not null;

-- Comprobación: después de esto la única fila debe decir `elite`, y `caducan`
-- debe ser 0 — cualquier otra cosa significa que la actualización no entró.
select plan,
       count(*)                                        as criaderos,
       count(*) filter (where plan_expires_at is not null) as caducan
  from public.profiles
 group by plan
 order by plan;
