// Edge Function: envia push FCM al insertar notificaciones_cliente
// Configurar Database Webhook en Supabase:
//   Table: notificaciones_cliente | Event: INSERT | URL: .../functions/v1/send-fcm
//
// Secrets requeridos (supabase secrets set):
//   FIREBASE_PROJECT_ID
//   FIREBASE_CLIENT_EMAIL
//   FIREBASE_PRIVATE_KEY  (con \n escapados)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface WebhookPayload {
  type: "INSERT";
  table: string;
  record: {
    id: string;
    cliente_id: string;
    titulo: string;
    mensaje: string;
    referencia_tipo: string | null;
    referencia_id: string | null;
  };
}

async function getAccessToken(): Promise<string> {
  const clientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL");
  const privateKey = Deno.env.get("FIREBASE_PRIVATE_KEY")?.replace(/\\n/g, "\n");
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");

  if (!clientEmail || !privateKey || !projectId) {
    throw new Error("Faltan secrets de Firebase");
  }

  const header = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: clientEmail,
    sub: clientEmail,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  };

  const encoder = new TextEncoder();
  const toBase64Url = (input: string) =>
    btoa(input).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

  const unsigned = `${toBase64Url(JSON.stringify(header))}.${toBase64Url(JSON.stringify(payload))}`;

  const pemContents = privateKey
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    encoder.encode(unsigned),
  );

  const signedJwt = `${unsigned}.${toBase64Url(String.fromCharCode(...new Uint8Array(signature)))}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: signedJwt,
    }),
  });

  const tokenJson = await tokenRes.json();
  if (!tokenJson.access_token) {
    throw new Error(`OAuth error: ${JSON.stringify(tokenJson)}`);
  }
  return tokenJson.access_token;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const body = (await req.json()) as WebhookPayload;
    const record = body.record;

    if (!record?.cliente_id) {
      return new Response(JSON.stringify({ skipped: true }), { status: 200 });
    }

    const { data: token } = await supabase.rpc("obtener_token_fcm_cliente", {
      p_cliente_id: record.cliente_id,
    });

    if (!token) {
      return new Response(JSON.stringify({ skipped: true, reason: "no_token" }), {
        status: 200,
      });
    }

    const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
    const accessToken = await getAccessToken();

    const fcmRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            notification: {
              title: record.titulo,
              body: record.mensaje,
            },
            data: {
              referencia_tipo: record.referencia_tipo ?? "",
              referencia_id: record.referencia_id ?? "",
              notificacion_id: record.id,
            },
            android: { priority: "HIGH" },
          },
        }),
      },
    );

    const fcmJson = await fcmRes.json();
    return new Response(JSON.stringify({ ok: fcmRes.ok, fcm: fcmJson }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
