// Criador Pro — validación del recibo de tienda (`RF-CTA`, `RS-12`).
//
// **El cliente nunca escribe su propio plan.** Manda el recibo, esta función lo
// valida contra Apple o Google y es ella —con `service_role`— quien escribe
// `plan` y `plan_expires_at`. El disparador `lock_plan_columns` impide que
// nadie más los toque.
//
// Se despliega con:
//
//   supabase functions deploy verify-receipt
//   supabase secrets set APPLE_SHARED_SECRET=... GOOGLE_SERVICE_ACCOUNT_JSON=...
//
// Sin esos secretos la función **rechaza todo**: sin forma de comprobar un
// recibo, concederlo por las buenas convertiría la suscripción en un honor
// system. Fallar cerrado es lo correcto aquí.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

/// Producto de tienda → plan. Los identificadores son los de `AppConfig`.
const PLAN_BY_PRODUCT: Record<string, string> = {
  'com.criadorpro.pro.monthly': 'pro',
  'com.criadorpro.elite.monthly': 'elite',
};

type Platform = 'ios' | 'android';

interface VerifyRequest {
  platform: Platform;
  productId: string;
  /// iOS: recibo en base64. Android: `purchaseToken`.
  receipt: string;
}

interface Verdict {
  ok: boolean;
  /// Fin del período pagado. El plan vive hasta aquí aunque no se renueve.
  expiresAt?: Date;
  reason?: string;
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return json({ error: 'method_not_allowed' }, 405);
  }

  // Quién llama sale del token, **nunca del cuerpo**: aceptar un `ownerId` del
  // payload dejaría a cualquiera activarle el plan a otro —o a sí mismo con el
  // recibo de otro.
  const authorization = request.headers.get('Authorization') ?? '';
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;

  const caller = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
  });

  const { data: userData, error: userError } = await caller.auth.getUser();
  if (userError || !userData.user) {
    return json({ error: 'unauthorized' }, 401);
  }
  const ownerId = userData.user.id;

  let body: VerifyRequest;
  try {
    body = await request.json();
  } catch {
    return json({ error: 'bad_request' }, 400);
  }

  const plan = PLAN_BY_PRODUCT[body.productId];
  if (!plan) {
    return json({ error: 'unknown_product' }, 400);
  }

  const verdict = body.platform === 'ios'
    ? await verifyApple(body.receipt, body.productId)
    : await verifyGoogle(body.receipt, body.productId);

  if (!verdict.ok) {
    // No se degrada aquí. `RS-12` conserva el último estado conocido 72 horas
    // antes de bajar de plan, y quien lo hace es el trabajo de caducidad, no
    // una validación que pudo fallar porque la tienda estaba caída.
    return json({ error: 'invalid_receipt', reason: verdict.reason }, 402);
  }

  // Solo aquí se escribe el plan, y solo con `service_role`.
  const admin = createClient(supabaseUrl, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const { error: writeError } = await admin
    .from('profiles')
    .update({ plan, plan_expires_at: verdict.expiresAt?.toISOString() ?? null })
    .eq('id', ownerId);

  if (writeError) {
    return json({ error: 'write_failed' }, 500);
  }

  return json({ plan, expiresAt: verdict.expiresAt?.toISOString() ?? null });
});

/// Apple — `verifyReceipt`.
///
/// Se prueba primero contra producción y, si Apple responde 21007, contra
/// sandbox. Ese orden lo pide Apple explícitamente: los revisores de App Store
/// compran en sandbox contra el binario de producción, y probar solo contra
/// producción hace que la revisión falle.
async function verifyApple(receipt: string, productId: string): Promise<Verdict> {
  const secret = Deno.env.get('APPLE_SHARED_SECRET');
  if (!secret) return { ok: false, reason: 'apple_not_configured' };

  const payload = {
    'receipt-data': receipt,
    password: secret,
    'exclude-old-transactions': true,
  };

  let response = await postJson('https://buy.itunes.apple.com/verifyReceipt', payload);
  if (response.status === 21007) {
    response = await postJson('https://sandbox.itunes.apple.com/verifyReceipt', payload);
  }
  if (response.status !== 0) {
    return { ok: false, reason: `apple_status_${response.status}` };
  }

  // La última renovación de ese producto es la que manda: `latest_receipt_info`
  // llega ordenado de forma no garantizada, así que se busca el vencimiento
  // mayor en lugar de fiarse del primero.
  const entries = (response.latest_receipt_info ?? []) as Array<Record<string, string>>;
  let latest = 0;
  for (const entry of entries) {
    if (entry.product_id !== productId) continue;
    const expires = Number(entry.expires_date_ms ?? 0);
    if (expires > latest) latest = expires;
  }

  if (latest === 0) return { ok: false, reason: 'apple_no_transaction' };
  if (latest < Date.now()) return { ok: false, reason: 'apple_expired' };

  return { ok: true, expiresAt: new Date(latest) };
}

/// Google Play — `purchases.subscriptions.get`.
async function verifyGoogle(purchaseToken: string, productId: string): Promise<Verdict> {
  const raw = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_JSON');
  const packageName = Deno.env.get('ANDROID_PACKAGE_NAME');
  if (!raw || !packageName) return { ok: false, reason: 'google_not_configured' };

  let token: string;
  try {
    token = await googleAccessToken(JSON.parse(raw));
  } catch (error) {
    return { ok: false, reason: `google_auth_failed_${error}` };
  }

  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${packageName}/purchases/subscriptions/${productId}/tokens/${purchaseToken}`;

  const response = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (!response.ok) return { ok: false, reason: `google_http_${response.status}` };

  const data = await response.json();
  const expires = Number(data.expiryTimeMillis ?? 0);
  if (expires === 0) return { ok: false, reason: 'google_no_expiry' };
  if (expires < Date.now()) return { ok: false, reason: 'google_expired' };

  return { ok: true, expiresAt: new Date(expires) };
}

/// Token de acceso de la cuenta de servicio, firmando un JWT con RS256.
///
/// A mano y no con la librería de Google: `googleapis` arrastra medio Node y en
/// una Edge Function eso son segundos de arranque en frío por cada compra.
async function googleAccessToken(account: { client_email: string; private_key: string }) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };

  const encode = (value: unknown) =>
    btoa(JSON.stringify(value)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

  const unsigned = `${encode(header)}.${encode(claims)}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToBytes(account.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned));
  const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${unsigned}.${encodedSignature}`,
    }),
  });

  const data = await response.json();
  if (!data.access_token) throw new Error(data.error ?? 'no_token');
  return data.access_token as string;
}

function pemToBytes(pem: string): ArrayBuffer {
  // La clave del JSON de la cuenta de servicio trae los saltos de línea
  // escapados; sin deshacerlos, `atob` recibe basura y falla sin decir por qué.
  const body = pem
    .replace(/\\n/g, '\n')
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');

  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

async function postJson(url: string, payload: unknown) {
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  return await response.json();
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
