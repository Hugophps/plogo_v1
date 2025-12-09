/// <reference lib="deno.ns" />
/// <reference lib="deno.unstable" />

export const config = {
  verifyJwt: false,
};

import {
  EnodeApiError,
  extractChargerLabels,
  enodeJson,
  verifyStateToken,
} from "../_shared/enode.ts";
import { createSupabaseClient } from "../_shared/supabase.ts";

const HTML_HEADERS = {
  "Content-Type": "text/html; charset=utf-8",
};
const APP_BASE_URL = Deno.env.get("APP_BASE_URL") ??
  "https://plogo-energy.netlify.app";

type StatePayload = {
  profile_id: string;
  station_id: string;
};

type ProfileRow = {
  id: string;
  enode_user_id: string | null;
};

type StationRow = {
  id: string;
  owner_id: string;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204 });
  }

  if (req.method !== "GET") {
    return htmlResponse(
      "Méthode non autorisée pour ce point d'entrée.",
      405,
    );
  }

  const url = new URL(req.url);
  const state = extractStateToken(url);

  if (!state) {
    return htmlResponse("Lien Enode invalide : identifiant de session absent.", {
      status: 400,
      success: false,
    });
  }

  try {
    const stateData = await verifyStateToken<StatePayload>(state);
    if (!stateData?.profile_id || !stateData?.station_id) {
      throw new ResponseError("State incomplet.");
    }

    const supabase = createSupabaseClient();
    const profile = await loadProfile(supabase, stateData.profile_id);
    const station = await loadStation(supabase, stateData.station_id);

    if (station.owner_id !== profile.id) {
      throw new ResponseError("Cette station n'appartient pas au profil indiqué.");
    }
    if (!profile.enode_user_id) {
      throw new ResponseError("Utilisateur Enode introuvable pour ce profil.");
    }

    await ensureSingleEnodeStation(
      supabase,
      profile.id,
      station.id,
    );

    const charger = await pickFirstCharger(profile.enode_user_id);
    const chargerId =
      (typeof charger["id"] === "string" && charger["id"].trim()) ||
      (typeof charger["charger_id"] === "string" && charger["charger_id"].trim());
    if (!chargerId) {
      throw new ResponseError("Identifiant de borne Enode manquant.");
    }

    const metadata = charger as Record<string, unknown>;
    const { brand, model, vendor } = extractChargerLabels(metadata);
    const brandLabel = brand && brand.trim() ? brand.trim() : "Borne Enode";
    const modelLabel = model && model.trim() ? model.trim() : "Modèle Enode";
    const vendorLabel = vendor && vendor.trim() ? vendor.trim() : null;
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
      .eq("id", station.id);

    if (updateError) {
      console.error("Station update error", updateError);
      throw new ResponseError(
        "Impossible d'associer la borne à la station.",
      );
    }

    await ensureMembershipApproved(supabase, station.id, profile.id, now);

    return htmlResponse(
      "Connexion Enode réussie. Vous pouvez fermer cette fenêtre et revenir sur Plogo.",
      { status: 200, success: true },
    );
  } catch (error) {
    if (error instanceof ResponseError) {
      return htmlResponse(error.message, { status: 400, success: false });
    }
    if (error instanceof EnodeApiError) {
      console.error("enode-callback enode error", {
        status: error.status,
        body: error.body,
      });
      return htmlResponse(
        "Connexion Enode indisponible pour le moment. Réessayez plus tard.",
        { status: 502, success: false },
      );
    }

    console.error("enode-callback error", error);
    return htmlResponse(
      "Une erreur inattendue est survenue pendant la connexion Enode.",
      { status: 500, success: false },
    );
  }
});

function htmlResponse(
  message: string,
  options: { status?: number; success?: boolean } = {},
) {
  const { status = 200, success = true } = options;
  const title = "Plogo · Connexion Enode";
  const styles = `
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: #f7f8fc;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      padding: 24px;
      color: #111827;
      margin: 0;
    }
    .card {
      max-width: 420px;
      background: #fff;
      border-radius: 20px;
      padding: 32px;
      box-shadow: 0 20px 60px rgba(44, 117, 255, 0.15);
      text-align: center;
    }
    h1 {
      font-size: 1.4rem;
      margin-bottom: 12px;
    }
    p { margin: 0; line-height: 1.5; }
    a {
      color: #2c75ff;
      text-decoration: none;
    }
  `;
  const autoRedirect = success
    ? `<script>setTimeout(()=>{window.location.href="${APP_BASE_URL}";},2500);</script>`
    : "";
  const body = `<!DOCTYPE html>
<html lang="fr">
  <head>
    <meta charset="utf-8" />
    <title>${title}</title>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <style>${styles}</style>
    ${autoRedirect}
  </head>
  <body>
    <div class="card">
      <h1>Plogo · Connexion Enode</h1>
      <p>${message}</p>
      <p style="margin-top:16px;">
        <a href="${APP_BASE_URL}">Retourner sur Plogo</a>
      </p>
    </div>
  </body>
</html>`;

  return new Response(body, {
    status,
    headers: HTML_HEADERS,
  });
}

function extractStateToken(url: URL): string | null {
  const param = url.searchParams.get("state") ??
    url.searchParams.get("token");
  if (param && param.trim().length > 0) {
    return param.trim();
  }

  const segments = url.pathname.split("/").filter(Boolean);
  const last = segments[segments.length - 1];
  if (last && last !== "enode-callback") {
    return last;
  }

  return null;
}

class ResponseError extends Error {}

async function loadProfile(
  supabase: ReturnType<typeof createSupabaseClient>,
  profileId: string,
) {
  const { data, error } = await supabase
    .from("profiles")
    .select("id, enode_user_id")
    .eq("id", profileId)
    .single();

  const profile = data as ProfileRow | null;
  if (error || !profile) {
    throw new ResponseError("Profil introuvable.");
  }
  return profile;
}

async function loadStation(
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
    throw new ResponseError("Station introuvable.");
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
    .select("id")
    .eq("owner_id", ownerId)
    .neq("id", stationId)
    .not("enode_charger_id", "is", null)
    .maybeSingle();

  if (error) {
    console.error("ensureSingleEnodeStation error", error);
    throw new ResponseError(
      "Vérification Enode impossible pour le propriétaire.",
    );
  }

  if (data) {
    throw new ResponseError(
      "Une autre station est déjà connectée à Enode pour ce profil.",
    );
  }
}

async function pickFirstCharger(userId: string) {
  const chargersResponse = await enodeJson(
    `/users/${userId}/chargers`,
    { method: "GET" },
    undefined,
    "Impossible de récupérer les bornes Enode.",
  );

  const chargers = normalizeChargers(chargersResponse);
  if (!chargers.length) {
    throw new ResponseError(
      "Aucune borne n'a été trouvée sur le compte Enode.",
    );
  }

  return chargers[0];
}

function normalizeChargers(payload: unknown) {
  if (Array.isArray(payload)) {
    return payload.filter((item): item is Record<string, unknown> =>
      item !== null && typeof item === "object"
    );
  }

  if (payload && typeof payload === "object") {
    const candidates = ["chargers", "data", "items"];
    for (const key of candidates) {
      const value = (payload as Record<string, unknown>)[key];
      if (Array.isArray(value)) {
        return value.filter((item): item is Record<string, unknown> =>
          item !== null && typeof item === "object"
        );
      }
    }
  }

  return [];
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
      "Impossible de vérifier le statut du propriétaire sur la station.",
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
        "Impossible de créer le rattachement à la station.",
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
      );
    }
  }
}
