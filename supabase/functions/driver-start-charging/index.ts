/// <reference lib="deno.ns" />
/// <reference lib="deno.unstable" />

import {
  EnodeApiError,
  startChargerCharging,
} from "../_shared/enode.ts";
import {
  DriverChargingError,
  ensureBookingPaymentRecord,
  getActiveSlotForMembership,
  loadDriverStationContext,
} from "../_shared/driver_charging.ts";
import {
  extractEnodeActionId,
  handleDriverEnodeError,
  mergeRawEnodePayload,
} from "../_shared/driver_enode.ts";
import { createSupabaseClient } from "../_shared/supabase.ts";

type Payload = {
  station_id?: string;
};

type SessionRow = {
  id: string;
  station_id: string;
  driver_profile_id: string;
  slot_id: string | null;
  status: string;
  start_at: string;
  end_at: string | null;
  energy_kwh: number | null;
  amount_eur: number | null;
  enode_metadata: Record<string, unknown> | null;
  enode_action_start_id: string | null;
  enode_action_stop_id: string | null;
  raw_enode_payload: Record<string, unknown> | null;
};

type SlotSummary = {
  id: string;
  start_at: string;
  end_at: string;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
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
  if (!stationId) {
    return new Response(
      JSON.stringify({ error: "station_id est requis." }),
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
    const now = new Date();
    const nowIso = now.toISOString();
    const context = await loadDriverStationContext(
      supabase,
      stationId,
      user.id,
    );

    if (!context.station.enode_charger_id) {
      throw new DriverChargingError(
        "Aucune borne Enode n'est associée à cette station.",
        400,
      );
    }

    if (!context.owner.enode_user_id) {
      throw new DriverChargingError(
        "Le propriétaire doit terminer la connexion Enode avant de démarrer une charge.",
        400,
      );
    }

    const slot = await getActiveSlotForMembership(
      supabase,
      stationId,
      context.membership.id,
      nowIso,
    );

    if (!slot) {
      throw new DriverChargingError(
        "Aucun créneau actif trouvé pour démarrer la charge.",
        400,
      );
    }

    await ensureBookingPaymentRecord(
      supabase,
      {
        stationId,
        slotId: slot.id,
        membershipId: context.membership.id,
        driverId: user.id,
        ownerId: context.station.owner_id,
        stationName: context.station.name,
        slotStartAt: slot.start_at,
        initialStatus: "in_progress",
      },
    );

    const existingSession = await getActiveSession(
      supabase,
      stationId,
      user.id,
    );

    if (existingSession?.status === "in_progress") {
      return new Response(
        JSON.stringify({
          session: serializeSession(existingSession),
          slot: serializeSlot(slot),
          message: "Une session est déjà en cours pour cette borne.",
        }),
        { status: 200, headers: withJson(corsHeaders) },
      );
    }

    if (existingSession) {
      await supabase
        .from("station_charging_sessions")
        .update({
          status: "cancelled",
          end_at: nowIso,
        })
        .eq("id", existingSession.id);
    }

    let startAction: unknown;
    try {
      // Appel Enode pour synchroniser le démarrage réel de la charge avec l’action Plogo
      startAction = await startChargerCharging(
        context.station.enode_charger_id,
      );
    } catch (error) {
      handleDriverEnodeError(
        "driver-start-charging",
        error,
        "Impossible de démarrer la charge Enode.",
      );
    }

    const metadata = {
      start_action: startAction ?? null,
      slot: serializeSlot(slot),
    };
    const rawPayload = mergeRawEnodePayload(
      null,
      { start_action: startAction ?? null },
    );

    const { data: inserted, error: insertError } = await supabase
      .from("station_charging_sessions")
      .insert({
        station_id: stationId,
        driver_profile_id: user.id,
        slot_id: slot.id,
        status: "in_progress",
        start_at: nowIso,
        enode_action_start_id: extractEnodeActionId(startAction),
        enode_metadata: metadata,
        raw_enode_payload: rawPayload,
      })
      .select("*")
      .single();

    if (insertError || !inserted) {
      console.error("driver-start-charging insert error", insertError);
      throw new DriverChargingError(
        "Impossible d'enregistrer la session de charge.",
        500,
      );
    }

    return new Response(
      JSON.stringify({
        session: serializeSession(inserted as SessionRow),
        slot: serializeSlot(slot),
        message: "Charge démarrée avec succès.",
      }),
      { status: 200, headers: withJson(corsHeaders) },
    );
  } catch (error) {
    return handleError(error);
  }
});

async function getActiveSession(
  supabase: ReturnType<typeof createSupabaseClient>,
  stationId: string,
  driverId: string,
): Promise<SessionRow | null> {
  const { data, error } = await supabase
    .from("station_charging_sessions")
    .select("*")
    .eq("station_id", stationId)
    .eq("driver_profile_id", driverId)
    .in("status", ["pending", "ready", "in_progress"])
    .order("created_at", { ascending: false })
    .limit(1);

  if (error) {
    throw new DriverChargingError(
      "Impossible de vérifier l'état de la session de charge.",
      500,
    );
  }

  if (!data || data.length === 0) {
    return null;
  }

  return data[0] as SessionRow;
}

function serializeSession(row: SessionRow) {
  return {
    id: row.id,
    station_id: row.station_id,
    driver_profile_id: row.driver_profile_id,
    slot_id: row.slot_id,
    status: row.status,
    start_at: row.start_at,
    end_at: row.end_at,
    energy_kwh: row.energy_kwh,
    amount_eur: row.amount_eur,
  };
}

function serializeSlot(slot: { id: string; start_at: string; end_at: string }): SlotSummary {
  return {
    id: slot.id,
    start_at: slot.start_at,
    end_at: slot.end_at,
  };
}

function withJson(headers: Record<string, string>) {
  return {
    ...headers,
    "Content-Type": "application/json",
  };
}

function handleError(error: unknown) {
  if (error instanceof EnodeApiError) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: error.status >= 500 ? 502 : error.status,
        headers: withJson(corsHeaders),
      },
    );
  }
  if (error instanceof DriverChargingError) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: error.status, headers: withJson(corsHeaders) },
    );
  }
  if (error instanceof Error) {
    console.error("driver-start-charging error", error);
  } else {
    console.error("driver-start-charging unknown error", error);
  }
  return new Response(
    JSON.stringify({
      error: "Impossible de démarrer la charge. Réessayez dans un instant.",
    }),
    { status: 500, headers: withJson(corsHeaders) },
  );
}
