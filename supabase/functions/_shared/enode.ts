const ENODE_CLIENT_ID = Deno.env.get("ENODE_CLIENT_ID") ?? "";
const ENODE_CLIENT_SECRET = Deno.env.get("ENODE_CLIENT_SECRET") ?? "";
const ENODE_API_URL = Deno.env.get("ENODE_API_URL") ?? "";
const ENODE_OAUTH_URL = Deno.env.get("ENODE_OAUTH_URL") ?? "";
const ENODE_REDIRECT_URI = Deno.env.get("ENODE_REDIRECT_URI") ?? "";
const ENODE_STATE_SECRET = Deno.env.get("ENODE_STATE_SECRET") ?? "";

if (
  !ENODE_CLIENT_ID || !ENODE_CLIENT_SECRET || !ENODE_API_URL ||
  !ENODE_OAUTH_URL || !ENODE_REDIRECT_URI || !ENODE_STATE_SECRET
) {
  throw new Error("Missing Enode configuration");
}

const encoder = new TextEncoder();
const decoder = new TextDecoder();

const scopeEnv = Deno.env.get("ENODE_CHARGER_SCOPES");
export const ENODE_SCOPES = scopeEnv
  ? scopeEnv.split(",").map((scope) => scope.trim()).filter((scope) => scope)
  : ["charger:read:data", "charger:control:charging"];

export { ENODE_REDIRECT_URI };

type TokenCache = { token: string; expiresAt: number } | null;
let cachedToken: TokenCache = null;

async function fetchAccessToken(): Promise<string> {
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

export async function enodeFetch(
  path: string,
  init: RequestInit = {},
  searchParams?: Record<string, string>,
) {
  const token = await fetchAccessToken();
  const url = new URL(
    path.startsWith("http")
      ? path
      : `${ENODE_API_URL}${path.startsWith("/") ? path : `/${path}`}`,
  );
  if (searchParams) {
    Object.entries(searchParams).forEach(([key, value]) => {
      url.searchParams.set(key, value);
    });
  }

  const headers = new Headers(init.headers ?? {});
  headers.set("Authorization", `Bearer ${token}`);
  if (init.body && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }

  return await fetch(url.toString(), {
    ...init,
    headers,
  });
}

export class EnodeApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly body: unknown,
  ) {
    super(message);
  }
}

export async function enodeJson(
  path: string,
  init: RequestInit = {},
  searchParams?: Record<string, string>,
  errorMessage?: string,
) {
  const response = await enodeFetch(path, init, searchParams);
  const text = await response.text();

  let json: unknown = null;
  if (text) {
    try {
      json = JSON.parse(text);
    } catch {
      json = null;
    }
  }

  if (!response.ok) {
    console.error("Enode API error", {
      status: response.status,
      body: text || null,
    });
    let message = errorMessage ?? "Erreur lors de l'appel à Enode.";
    if (json && typeof json === "object") {
      const errorText =
        (json as Record<string, unknown>)["detail"] ??
        (json as Record<string, unknown>)["title"] ??
        (json as Record<string, unknown>)["error_description"] ??
        (json as Record<string, unknown>)["error"];
      if (typeof errorText === "string") {
        const trimmed = errorText.trim();
        if (trimmed.length > 0) {
          message = trimmed;
        }
      }
    }
    throw new EnodeApiError(message, response.status, text || json);
  }

  return json;
}

let stateKeyPromise: Promise<CryptoKey> | null = null;

async function getStateKey(): Promise<CryptoKey> {
  if (!stateKeyPromise) {
    stateKeyPromise = crypto.subtle.importKey(
      "raw",
      encoder.encode(ENODE_STATE_SECRET),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign", "verify"],
    );
  }
  return await stateKeyPromise;
}

function bufferEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff === 0;
}

export async function createStateToken(
  payload: Record<string, string>,
): Promise<string> {
  const rawPayload = encoder.encode(
    JSON.stringify({
      ...payload,
      ts: Date.now(),
    }),
  );

  const key = await getStateKey();
  const signature = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, rawPayload),
  );

  return `${base64UrlEncode(rawPayload)}.${base64UrlEncode(signature)}`;
}

export async function verifyStateToken<T = Record<string, unknown>>(
  token: string,
): Promise<T> {
  const [rawPart, signaturePart] = token.split(".");
  if (!rawPart || !signaturePart) {
    throw new Error("State invalide");
  }

  const payloadBytes = base64UrlDecode(rawPart);
  const signatureBytes = base64UrlDecode(signaturePart);
  const key = await getStateKey();
  const expectedSignature = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, payloadBytes),
  );

  if (!bufferEqual(signatureBytes, expectedSignature)) {
    throw new Error("State invalide (signature)");
  }

  const decoded = decoder.decode(payloadBytes);
  const data = JSON.parse(decoded) as T;
  return data;
}

export function extractChargerLabels(metadata: Record<string, unknown>) {
  const vendorLabel = normalizeVendor(metadata["vendor"]);
  const brandCandidate = metadata["brand"] ??
    metadata["manufacturer"] ??
    (vendorLabel.trim().length > 0 ? vendorLabel : null);

  const friendlyName = metadata["name"] ??
    metadata["charger_name"] ??
    metadata["display_name"] ??
    metadata["product_name"] ??
    metadata["label"];
  const modelCandidate = metadata["model"] ??
    friendlyName ??
    metadata["product_label"] ??
    metadata["id"];

  const brandLabel = typeof brandCandidate === "string"
    ? brandCandidate.trim()
    : "";
  const modelLabel = typeof modelCandidate === "string"
    ? modelCandidate.trim()
    : "";

  return {
    brand: brandLabel,
    model: modelLabel,
    vendor: vendorLabel,
  };
}

function normalizeVendor(value: unknown): string {
  if (typeof value === "string") {
    return value.trim();
  }
  if (value && typeof value === "object") {
    const data = value as Record<string, unknown>;
    for (const key of ["name", "label", "slug"]) {
      const label = data[key];
      if (typeof label === "string" && label.trim()) {
        return label.trim();
      }
    }
  }
  return "";
}

function base64UrlEncode(data: Uint8Array): string {
  const base64 = encodeBase64(data);
  return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function base64UrlDecode(value: string): Uint8Array {
  let base64 = value.replace(/-/g, "+").replace(/_/g, "/");
  const padding = base64.length % 4;
  if (padding === 2) base64 += "==";
  else if (padding === 3) base64 += "=";
  else if (padding !== 0) {
    base64 += "==";
  }
  return decodeBase64(base64);
}

function encodeBase64(data: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < data.length; i++) {
    binary += String.fromCharCode(data[i]);
  }
  return btoa(binary);
}

function decodeBase64(value: string): Uint8Array {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}
