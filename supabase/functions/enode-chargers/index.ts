/// <reference lib="deno.ns" />
/// <reference lib="deno.unstable" />

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const ENODE_CLIENT_ID = Deno.env.get("ENODE_CLIENT_ID") ?? "";
const ENODE_CLIENT_SECRET = Deno.env.get("ENODE_CLIENT_SECRET") ?? "";
const ENODE_API_URL = Deno.env.get("ENODE_API_URL") ?? "";
const ENODE_OAUTH_URL = Deno.env.get("ENODE_OAUTH_URL") ?? "";

if (!ENODE_CLIENT_ID || !ENODE_CLIENT_SECRET || !ENODE_API_URL || !ENODE_OAUTH_URL) {
  throw new Error("Missing Enode environment variables");
}

type Payload =
  | { action: "vendors" }
  | { action: "list_chargers"; userId?: string }
  | { action: "charger"; chargerId: string };

let cachedToken: { token: string; expiresAt: number } | null = null;

async function getAccessToken(): Promise<string> {
  const now = Date.now();
  if (cachedToken && cachedToken.expiresAt > now + 30_000) {
    return cachedToken.token;
  }

  const basicAuth = btoa(`${ENODE_CLIENT_ID}:${ENODE_CLIENT_SECRET}`);
  const response = await fetch(ENODE_OAUTH_URL, {
    method: "POST",
    headers: {
      Authorization: `Basic ${basicAuth}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Enode OAuth error: ${text}`);
  }

  const json = await response.json() as {
    access_token: string;
    expires_in: number;
  };

  cachedToken = {
    token: json.access_token,
    expiresAt: now + json.expires_in * 1000,
  };

  return cachedToken.token;
}

async function proxyEnode(path: string, searchParams?: Record<string, string>) {
  const token = await getAccessToken();
  const url = new URL(path, ENODE_API_URL);
  if (searchParams) {
    Object.entries(searchParams).forEach(([k, v]) => url.searchParams.set(k, v));
  }

  const response = await fetch(url.toString(), {
    headers: { Authorization: `Bearer ${token}` },
  });

  const text = await response.text();
  return new Response(text, {
    status: response.status,
    headers: {
      ...corsHeaders,
      "Content-Type": response.headers.get("content-type") ?? "application/json",
    },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  let payload: Payload;
  try {
    payload = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON payload" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    switch (payload.action) {
      case "vendors":
        return await proxyEnode("/health/chargers");
      case "list_chargers":
        if (payload.userId) {
          return await proxyEnode(`/users/${payload.userId}/chargers`);
        }
        return await proxyEnode("/chargers");
      case "charger":
        return await proxyEnode(`/chargers/${payload.chargerId}`);
      default:
        return new Response(JSON.stringify({ error: "Unsupported action" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
    }
  } catch (error) {
    console.error("enode-chargers error", error);
    return new Response(
      JSON.stringify({ error: "Service Enode indisponible" }),
      { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
