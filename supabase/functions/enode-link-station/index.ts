/// <reference lib="deno.ns" />
/// <reference lib="deno.unstable" />

import {
  ENODE_REDIRECT_URI,
  ENODE_SCOPES,
  EnodeApiError,
  createStateToken,
  enodeJson,
} from "../_shared/enode.ts";
import { createSupabaseClient } from "../_shared/supabase.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type LinkPayload = {
  station_id?: string;
};

type ProfileRow = {
  id: string;
  role: string | null;
  enode_user_id: string | null;
};

type StationRow = {
  id: string;
  owner_id: string;
  enode_charger_id: string | null;
  name: string;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Méthode non autorisée" }),
      { status: 405, headers: withJson(corsHeaders) },
    );
  }

  const supabase = createSupabaseClient(req);

  let payload: LinkPayload;
  try {
    payload = await req.json();
  } catch (_) {
    return new Response(
      JSON.stringify({ error: "Corps de requête invalide" }),
      { status: 400, headers: withJson(corsHeaders) },
    );
  }

  const stationId = payload.station_id?.trim();
  if (!stationId) {
    return new Response(
      JSON.stringify({ error: "station_id est requis" }),
      { status: 400, headers: withJson(corsHeaders) },
    );
  }

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

    const station = await getStation(supabase, stationId);
    if (station.owner_id !== profile.id) {
      throw new ResponseError(
        "Vous ne pouvez modifier que vos propres bornes.",
        403,
      );
    }

    await ensureNoOtherEnodeStation(supabase, profile.id, stationId);

    const enodeUserId = await ensureEnodeUserId(supabase, profile);
    const stateToken = await createStateToken({
      profile_id: profile.id,
      station_id: stationId,
    });

    const redirectUriWithState = buildRedirectUri(stateToken);

    const session = await enodeJson(
      `/users/${enodeUserId}/link`,
      {
        method: "POST",
        body: JSON.stringify({
          vendorType: "charger",
          scopes: ENODE_SCOPES,
          language: "fr-FR",
          redirectUri: redirectUriWithState,
        }),
      },
      undefined,
      "Impossible de créer une session de connexion Enode.",
    ) as Record<string, unknown> | null;

    const linkUrl = session?.["linkUrl"] ??
      session?.["link_url"] ??
      session?.["url"];
    if (typeof linkUrl !== "string" || !linkUrl.trim()) {
      throw new Error("Lien de connexion Enode manquant.");
    }

    return new Response(
      JSON.stringify({ link_url: linkUrl }),
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

    console.error("enode-link-station error", error);
    return new Response(
      JSON.stringify({
        error:
          "Impossible d'initialiser la connexion Enode. Réessayez dans un instant.",
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
  profileId: string,
) {
  const { data, error } = await supabase
    .from("profiles")
    .select("id, role, enode_user_id")
    .eq("id", profileId)
    .single();

  const profile = data as ProfileRow | null;
  if (error || !profile) {
    throw new ResponseError("Profil introuvable.", 404);
  }

  return profile;
}

async function getStation(
  supabase: ReturnType<typeof createSupabaseClient>,
  stationId: string,
) {
  const { data, error } = await supabase
    .from("stations")
    .select("id, owner_id, enode_charger_id, name")
    .eq("id", stationId)
    .single();

  const station = data as StationRow | null;
  if (error || !station) {
    throw new ResponseError("Station introuvable.", 404);
  }

  return station;
}

async function ensureNoOtherEnodeStation(
  supabase: ReturnType<typeof createSupabaseClient>,
  ownerId: string,
  stationId: string,
) {
  const { data, error } = await supabase
    .from("stations")
    .select("id")
    .eq("owner_id", ownerId)
    .neq("id", stationId)
    .not("enode_charger_id", "is", null)
    .maybeSingle();

  if (error) {
    console.error("ensureNoOtherEnodeStation error", error);
    throw new ResponseError(
      "Vérification Enode impossible. Réessayez plus tard.",
      500,
    );
  }

  if (data) {
    throw new ResponseError(
      "Vous avez déjà connecté une borne Enode à une autre station.",
      400,
    );
  }
}

async function ensureEnodeUserId(
  supabase: ReturnType<typeof createSupabaseClient>,
  profile: ProfileRow,
) {
  if (profile.enode_user_id && profile.enode_user_id.trim().length > 0) {
    return profile.enode_user_id.trim();
  }

  const fallbackId = profile.id;
  const { error } = await supabase
    .from("profiles")
    .update({ enode_user_id: fallbackId })
    .eq("id", profile.id);

  if (error) {
    console.error("ensureEnodeUserId update error", error);
    throw new ResponseError(
      "Impossible de préparer l'identifiant Enode de l'utilisateur.",
      500,
    );
  }

  return fallbackId;
}

function buildRedirectUri(stateToken: string) {
  const placeholderMatch =
    ENODE_REDIRECT_URI.match(/\{(state|token)\}/i);
  if (placeholderMatch) {
    return ENODE_REDIRECT_URI.replace(
      placeholderMatch[0],
      stateToken,
    );
  }

  try {
    const url = new URL(ENODE_REDIRECT_URI);
    const search = url.search;
    url.search = "";
    const trimmedPath = url.pathname.replace(/\/+$/, "");
    const base = `${url.origin}${trimmedPath}`;
    return `${base}/${stateToken}${search}`;
  } catch (_) {
    const trimmed = ENODE_REDIRECT_URI.replace(/\/+$/, "");
    return `${trimmed}/${stateToken}`;
  }
}
