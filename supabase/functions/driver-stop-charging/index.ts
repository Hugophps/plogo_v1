/// <reference lib="deno.ns" />
/// <reference lib="deno.unstable" />

import {
  EnodeApiError,
  controlChargerCharging,
  fetchChargerSessionsStats,
} from "../_shared/enode.ts";
import {
  DriverChargingError,
  ensureBookingPaymentRecord,
  loadDriverStationContext,
  updateBookingPaymentTotals,
} from "../_shared/driver_charging.ts";
import { createSupabaseClient } from "../_shared/supabase.ts";

type Payload = { station_id?: string };

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
};

type SlotSummary = {
  id: string | null;
  start_at: string | null;
  end_at: string | null;
};

type SlotRow = {
  id: string;
  station_id: string;
  start_at: string;
  end_at: string;
  metadata: Record<string, unknown> | null;
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
        "Le propriétaire doit terminer la connexion Enode avant d'arrêter la charge.",
        400,
      );
    }

    const session = await getRunningSession(
      supabase,
      stationId,
      user.id,
    );

    if (!session) {
      throw new DriverChargingError(
        "Aucune session de charge en cours à arrêter.",
        400,
      );
    }

    const slot = await getSlotById(supabase, session.slot_id);
    if (!slot) {
      throw new DriverChargingError(
        "Impossible de retrouver les informations du créneau.",
        500,
      );
    }

    const membershipId = slot.metadata?.["membership_id"];
    if (!membershipId || typeof membershipId !== "string") {
      throw new DriverChargingError(
        "Créneau de réservation invalide.",
        500,
      );
    }

    await ensureBookingPaymentRecord(
      supabase,
      {
        stationId: slot.station_id,
        slotId: slot.id,
        membershipId,
        driverId: user.id,
        ownerId: context.station.owner_id,
        stationName: context.station.name,
        slotStartAt: slot.start_at,
      },
    );

    const stopAction = await controlChargerCharging(
      context.station.enode_charger_id,
      "STOP",
      context.owner.enode_user_id ?? undefined,
    );

    const stats = await collectSessionStats(
      context.owner.enode_user_id,
      context.station.enode_charger_id,
      session.start_at,
    );

    const nowIso = new Date().toISOString();
    const updatedMetadata = {
      ...(session.enode_metadata ?? {}),
      stop_action: stopAction ?? null,
      stats_session: stats ?? null,
    };

    const energyKwh = typeof stats?.kwhSum === "number"
      ? stats.kwhSum
      : null;
    const amountEur = computeAmount(
      energyKwh,
      context.station.price_per_kwh,
    );

    const { data: updated, error: updateError } = await supabase
      .from("station_charging_sessions")
      .update({
        status: "completed",
        end_at: nowIso,
        energy_kwh: energyKwh,
        amount_eur: amountEur,
        enode_metadata: updatedMetadata,
      })
      .eq("id", session.id)
      .select("*")
      .single();

    if (updateError || !updated) {
      console.error("driver-stop-charging update error", updateError);
      throw new DriverChargingError(
        "Impossible de mettre à jour la session de charge.",
        500,
      );
    }

    await updateBookingPaymentTotals(
      supabase,
      {
        slotId: slot.id,
        slotEndAt: slot.end_at,
      },
    );

    return new Response(
      JSON.stringify({
        session: serializeSession(updated as SessionRow),
        slot: serializeSlot(session),
        stats: stats ?? null,
        message: "Charge arrêtée avec succès.",
      }),
      { status: 200, headers: withJson(corsHeaders) },
    );
  } catch (error) {
    return handleError(error);
  }
});

async function getRunningSession(
  supabase: ReturnType<typeof createSupabaseClient>,
  stationId: string,
  driverId: string,
): Promise<SessionRow | null> {
  const { data, error } = await supabase
    .from("station_charging_sessions")
    .select("*")
    .eq("station_id", stationId)
    .eq("driver_profile_id", driverId)
    .eq("status", "in_progress")
    .order("created_at", { ascending: false })
    .limit(1);

  if (error) {
    throw new DriverChargingError(
      "Impossible de récupérer la session de charge en cours.",
      500,
    );
  }

  if (!data || data.length === 0) {
    return null;
  }

  return data[0] as SessionRow;
}

async function collectSessionStats(
  enodeUserId: string,
  chargerId: string,
  sessionStartIso: string,
) {
  const startWindow = new Date(Date.parse(sessionStartIso) - 15 * 60 * 1000)
    .toISOString();
  const endWindow = new Date(Date.now() + 5 * 60 * 1000).toISOString();
  const stats = await fetchChargerSessionsStats(enodeUserId, {
    startDate: startWindow,
    endDate: endWindow,
    chargerId,
  });

  if (!stats || stats.length === 0) {
    return null;
  }

  const sessionStart = Date.parse(sessionStartIso);
  let bestMatch: Record<string, unknown> | null = null;
  let smallestDelta = Number.POSITIVE_INFINITY;
  for (const entry of stats) {
    const from = Date.parse((entry["from"] as string) ?? "");
    const to = Date.parse((entry["to"] as string) ?? "");
    if (Number.isNaN(from) || Number.isNaN(to)) continue;

    const overlaps = from <= sessionStart && to >= sessionStart;
    if (!overlaps) continue;

    const delta = Math.abs(from - sessionStart);
    if (delta < smallestDelta) {
      smallestDelta = delta;
      bestMatch = entry;
    }
  }

  return bestMatch;
}

function computeAmount(energyKwh: number | null, pricePerKwh: number | null) {
  if (
    energyKwh == null || Number.isNaN(energyKwh) || pricePerKwh == null ||
    Number.isNaN(pricePerKwh)
  ) {
    return null;
  }
  const raw = energyKwh * pricePerKwh;
  return Math.round(raw * 100) / 100;
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

function serializeSlot(session: SessionRow): SlotSummary {
  return {
    id: session.slot_id,
    start_at: session.start_at,
    end_at: session.end_at,
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
    console.error("driver-stop-charging error", error);
  } else {
    console.error("driver-stop-charging unknown error", error);
  }

  return new Response(
    JSON.stringify({
      error: "Impossible d'arrêter la charge. Réessayez dans un instant.",
    }),
    { status: 500, headers: withJson(corsHeaders) },
  );
}

async function getSlotById(
  supabase: ReturnType<typeof createSupabaseClient>,
  slotId: string | null,
): Promise<SlotRow | null> {
  if (!slotId) return null;
  const { data, error } = await supabase
    .from("station_slots")
    .select("id, station_id, start_at, end_at, metadata")
    .eq("id", slotId)
    .maybeSingle();

  if (error) {
    throw new DriverChargingError(
      "Impossible de récupérer le créneau réservé.",
      500,
    );
  }

  return data as SlotRow | null;
}
