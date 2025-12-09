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
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type ProfileRow = {
  id: string;
  role: string | null;
  enode_user_id: string | null;
};

type StationRow = {
  id: string;
  owner_id: string;
};

type Payload = {
  station_id?: string;
  charger_id?: string;
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

  let payload: Payload;
  try {
    payload = await req.json();
  } catch (_) {
    return new Response(
      JSON.stringify({ error: "Corps de requête invalide" }),
      { status: 400, headers: withJson(corsHeaders) },
    );
  }

  const stationId = payload.station_id?.trim();
  const chargerId = payload.charger_id?.trim();
  if (!stationId || !chargerId) {
    return new Response(
      JSON.stringify({ error: "station_id et charger_id sont requis." }),
      { status: 400, headers: withJson(corsHeaders) },
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

    const station = await getStation(supabase, stationId);
    if (station.owner_id !== profile.id) {
      throw new ResponseError(
        "Vous ne pouvez modifier que vos propres bornes.",
        403,
      );
    }

    await ensureSingleEnodeStation(
      supabase,
      profile.id,
      stationId,
    );

    const charger = await fetchCharger(profile.enode_user_id!, chargerId);
    const metadata = charger as Record<string, unknown>;
    const { brand, model, vendor } = extractChargerLabels(metadata);
    const brandLabel = brand && brand.trim().length > 0
      ? brand.trim()
      : "Borne Enode";
    const modelLabel = model && model.trim().length > 0
      ? model.trim()
      : "Modèle Enode";
    const vendorLabel = vendor && vendor.trim().length > 0
      ? vendor.trim()
      : null;
    const now = new Date().toISOString();

    const { error: updateError } = await supabase
      .from("stations")
      .update({
        enode_charger_id: chargerId,
        enode_metadata: metadata,
        charger_brand: brandLabel,
        charger_model: modelLabel,
        charger_vendor: vendorLabel,
        updated_at: now,
      })
      .eq("id", stationId)
      .eq("owner_id", profile.id);

    if (updateError) {
      console.error("enode-select update error", updateError);
      throw new ResponseError(
        "Impossible d'associer la borne sélectionnée.",
        500,
      );
    }

    await ensureMembershipApproved(supabase, stationId, profile.id, now);

    return new Response(
      JSON.stringify({ success: true }),
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
    console.error("enode-select-charger error", error);
    return new Response(
      JSON.stringify({
        error: "Impossible d'associer la borne. Réessayez plus tard.",
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

async function getStation(
  supabase: ReturnType<typeof createSupabaseClient>,
  stationId: string,
) {
  const { data, error } = await supabase
    .from("stations")
    .select("id, owner_id")
    .eq("id", stationId)
    .single();

  const station = data as StationRow | null;
  if (error || !station) {
    throw new ResponseError("Station introuvable.", 404);
  }
  return station;
}

async function ensureSingleEnodeStation(
  supabase: ReturnType<typeof createSupabaseClient>,
  ownerId: string,
  stationId: string,
) {
  const { data, error } = await supabase
    .from("stations")
    .select("id, enode_charger_id")
    .eq("owner_id", ownerId);

  if (error) {
    console.error("ensureSingleEnodeStation error", error);
    throw new ResponseError(
      "Vérification Enode impossible pour le propriétaire.",
      500,
    );
  }

  if (!Array.isArray(data)) return;
  for (const station of data) {
    if (station.id !== stationId && station.enode_charger_id) {
      throw new ResponseError(
        "Une autre station est déjà connectée à Enode pour ce profil.",
        400,
      );
    }
  }
}

async function fetchCharger(userId: string, chargerId: string) {
  const chargers = await enodeJson(
    `/users/${userId}/chargers`,
    { method: "GET" },
    undefined,
    "Impossible de récupérer les bornes Enode.",
  );

  if (Array.isArray(chargers)) {
    const found = chargers.find((item) => {
      const id = (item as Record<string, unknown>)["id"] ??
        (item as Record<string, unknown>)["charger_id"];
      return id?.toString() === chargerId;
    });
    if (found) return found;
  }

  if (chargers && typeof chargers === "object") {
    const list = (chargers as Record<string, unknown>)["chargers"];
    if (Array.isArray(list)) {
      const match = list.find((item) => {
        const id = (item as Record<string, unknown>)["id"] ??
          (item as Record<string, unknown>)["charger_id"];
        return id?.toString() === chargerId;
      });
      if (match) return match;
    }
  }

  throw new ResponseError(
    "La borne sélectionnée n'appartient pas à votre compte Enode.",
    404,
  );
}

async function ensureMembershipApproved(
  supabase: ReturnType<typeof createSupabaseClient>,
  stationId: string,
  profileId: string,
  now: string,
) {
  const { data, error } = await supabase
    .from("station_memberships")
    .select("id, status")
    .eq("station_id", stationId)
    .eq("profile_id", profileId)
    .maybeSingle();

  if (error) {
    console.error("ensureMembershipApproved select error", error);
    throw new ResponseError(
      "Impossible de vérifier le rattachement à la station.",
      500,
    );
  }

  if (!data) {
    const { error: insertError } = await supabase
      .from("station_memberships")
      .insert({
        station_id: stationId,
        profile_id: profileId,
        status: "approved",
        approved_at: now,
      });

    if (insertError) {
      console.error("ensureMembershipApproved insert error", insertError);
      throw new ResponseError(
        "Impossible de rattacher le propriétaire à la station.",
        500,
      );
    }
    return;
  }

  if (data.status !== "approved") {
    const { error: updateError } = await supabase
      .from("station_memberships")
      .update({
        status: "approved",
        approved_at: now,
      })
      .eq("id", data.id);

    if (updateError) {
      console.error("ensureMembershipApproved update error", updateError);
      throw new ResponseError(
        "Impossible de valider le rattachement à la station.",
        500,
      );
    }
  }
}
