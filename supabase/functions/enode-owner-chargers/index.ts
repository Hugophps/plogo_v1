/// <reference lib="deno.ns" />
/// <reference lib="deno.unstable" />

import {
  EnodeApiError,
  extractChargerLabels,
  enodeJson,
} from "../_shared/enode.ts";
import { createSupabaseClient } from "../_shared/supabase.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

type ProfileRow = {
  id: string;
  role: string | null;
  enode_user_id: string | null;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "GET") {
    return new Response(
      JSON.stringify({ error: "Méthode non autorisée" }),
      { status: 405, headers: withJson(corsHeaders) },
    );
  }

  const supabase = createSupabaseClient(req);
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();

  if (authError || !user) {
    return new Response(
      JSON.stringify({ error: "Utilisateur non authentifié" }),
      { status: 401, headers: withJson(corsHeaders) },
    );
  }

  try {
    const profile = await getProfile(supabase, user.id);
    if (profile.role !== "owner") {
      throw new ResponseError("Réservé aux propriétaires.", 403);
    }

    const chargers = await enodeJson(
      `/users/${profile.enode_user_id}/chargers`,
      { method: "GET" },
      undefined,
      "Impossible de récupérer les bornes Enode.",
    );

    const normalized = normalizeChargers(chargers);
    return new Response(
      JSON.stringify({ chargers: normalized }),
      { status: 200, headers: withJson(corsHeaders) },
    );
  } catch (error) {
    if (error instanceof ResponseError) {
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: error.status, headers: withJson(corsHeaders) },
      );
    }
    if (error instanceof EnodeApiError) {
      return new Response(
        JSON.stringify({ error: error.message }),
        {
          status: error.status >= 500 ? 502 : error.status,
          headers: withJson(corsHeaders),
        },
      );
    }
    console.error("enode-owner-chargers error", error);
    return new Response(
      JSON.stringify({
        error: "Service Enode indisponible. Réessayez dans un instant.",
      }),
      { status: 500, headers: withJson(corsHeaders) },
    );
  }
});

function withJson(headers: Record<string, string>) {
  return {
    ...headers,
    "Content-Type": "application/json",
  };
}

class ResponseError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
  }
}

async function getProfile(
  supabase: ReturnType<typeof createSupabaseClient>,
  userId: string,
) {
  const { data, error } = await supabase
    .from("profiles")
    .select("id, role, enode_user_id")
    .eq("id", userId)
    .single();

  const profile = data as ProfileRow | null;
  if (error || !profile) {
    throw new ResponseError("Profil introuvable.", 404);
  }
  if (!profile.enode_user_id) {
    throw new ResponseError(
      "Aucun compte Enode n'est encore associé à ce profil.",
      400,
    );
  }
  return profile;
}

function normalizeChargers(payload: unknown) {
  let rawList: unknown[] = [];
  if (Array.isArray(payload)) {
    rawList = payload;
  } else if (payload && typeof payload === "object") {
    const container = payload as Record<string, unknown>;
    rawList =
      (container["chargers"] as unknown[] | undefined) ??
      (container["data"] as unknown[] | undefined) ??
      (container["items"] as unknown[] | undefined) ??
      [];
  }

  const normalized = [];
  for (const entry of rawList) {
    if (!entry || typeof entry !== "object") continue;
    const item = entry as Record<string, unknown>;
    const idValue = (item["id"] ??
      item["charger_id"] ??
      item["chargerId"])?.toString() ?? "";
    if (idValue.trim().length === 0) continue;

    const { brand, model, vendor } = extractChargerLabels(item);
    const friendlyName = (item["name"] ??
      item["charger_name"] ??
      item["product_name"] ??
      item["display_name"])?.toString() ?? "";
    const parts = [brand.trim(), model.trim()].filter((part) =>
      part.length > 0
    );
    const label = parts.length > 0 ? parts.join(" · ") : "Borne Enode";
    const displayName =
      friendlyName.trim().length > 0 ? friendlyName.trim() : label;
    normalized.push({
      id: idValue,
      brand,
      model,
      vendor,
      label: displayName,
      raw: item,
    });
  }
  return normalized;
}
