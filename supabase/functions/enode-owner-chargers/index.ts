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
  const chargers = Array.isArray(payload)
    ? payload
    : (typeof payload === "object" && payload !== null)
    ? ((payload as Record<string, unknown>)["chargers"] as unknown[])
    : [];

  return chargers
    .filter((item): item is Record<string, unknown> =>
      item !== null && typeof item === "object"
    )
    .map((item) => {
      const { brand, model, vendor } = extractChargerLabels(item);
      return {
        id: (item["id"] ?? item["charger_id"] ?? "")?.toString(),
        brand,
        model,
        vendor,
        label: [brand, model].filter((part) => part && part.trim().length > 0)
          .join(" · "),
        raw: item,
      };
    })
    .filter((charger) => (charger.id?.trim().length ?? 0) > 0);
}
