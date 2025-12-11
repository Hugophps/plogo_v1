/// <reference lib="deno.ns" />
/// <reference lib="deno.unstable" />

import { EnodeApiError } from "../_shared/enode.ts";
import {
  EnodeHttpError,
  extractEnodeActionId,
  fetchEnodeChargerAction,
  mergeRawEnodePayload,
} from "../_shared/driver_enode.ts";
import { createSupabaseClient } from "../_shared/supabase.ts";

type Payload = { session_id?: string };

type ChargingSessionStatus =
  | "pending"
  | "ready"
  | "in_progress"
  | "completed"
  | "failed"
  | "cancelled";

type ActionState = "PENDING" | "CONFIRMED" | "FAILED" | "CANCELLED";

type SessionRow = {
  id: string;
  station_id: string;
  driver_profile_id: string;
  status: ChargingSessionStatus;
  slot_id: string | null;
  start_at: string;
  end_at: string | null;
  enode_action_start_id: string | null;
  enode_action_stop_id: string | null;
  enode_metadata: Record<string, unknown> | null;
  raw_enode_payload: Record<string, unknown> | null;
  station: {
    id: string;
    owner_id: string;
    enode_charger_id: string | null;
  } | null;
};

type EnodeAction = Record<string, unknown> | null;

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

  const sessionId = payload.session_id?.trim();
  if (!sessionId) {
    return new Response(
      JSON.stringify({ error: "session_id est requis." }),
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
    const session = await loadSession(supabase, sessionId);
    if (!session) {
      return new Response(
        JSON.stringify({ error: "Session introuvable." }),
        { status: 404, headers: withJson(corsHeaders) },
      );
    }

    if (
      session.driver_profile_id !== user.id &&
      session.station?.owner_id !== user.id
    ) {
      return new Response(
        JSON.stringify({ error: "Accès non autorisé à cette session." }),
        { status: 403, headers: withJson(corsHeaders) },
      );
    }

    const rawPayload = asRecord(session.raw_enode_payload) ?? {};
    const existingStartAction = asRecord(rawPayload["start_action"]);
    const existingStopAction = asRecord(rawPayload["stop_action"]);
    const startActionId = session.enode_action_start_id ??
      extractEnodeActionId(existingStartAction);
    const stopActionId = session.enode_action_stop_id ??
      extractEnodeActionId(existingStopAction);

    if (!startActionId && !stopActionId) {
      return new Response(
        JSON.stringify({
          error:
            "Aucune action Enode à synchroniser pour cette session de charge.",
        }),
        { status: 400, headers: withJson(corsHeaders) },
      );
    }

    const refreshedStartAction = startActionId
      ? await fetchEnodeChargerAction({
        actionId: startActionId,
        contextLabel: `driver-sync-charging-session:start:${sessionId}`,
      })
      : null;
    const refreshedStopAction = stopActionId
      ? await fetchEnodeChargerAction({
        actionId: stopActionId,
        contextLabel: `driver-sync-charging-session:stop:${sessionId}`,
      })
      : null;

    const finalStartAction = refreshedStartAction ?? existingStartAction;
    const finalStopAction = refreshedStopAction ?? existingStopAction;

    const startState = mapActionState(finalStartAction?.["state"]);
    const stopState = mapActionState(finalStopAction?.["state"]);
    const startFailure = finalStartAction?.["failureReason"] ?? null;
    const stopFailure = finalStopAction?.["failureReason"] ?? null;

    const stopCompletedIso = normalizeIso(
      finalStopAction?.["completedAt"],
    );
    const updatedPayload = mergeRawEnodePayload(
      rawPayload,
      {
        ...(refreshedStartAction ? { start_action: refreshedStartAction } : {}),
        ...(refreshedStopAction ? { stop_action: refreshedStopAction } : {}),
      },
    );

    const nextStatus = computeSessionStatus(
      session.status,
      startState,
      stopState,
    );

    const nowIso = new Date().toISOString();
    const updatedMetadata = {
      ...(asRecord(session.enode_metadata) ?? {}),
      // Synchronisation pour aligner les statuts Plogo avec ceux décrits par la doc Enode (PENDING, CONFIRMED, FAILED, CANCELLED).
      last_enode_sync_at: nowIso,
      start_action_state: startState,
      start_action_failure: startFailure ?? null,
      start_action_completed_at: normalizeIso(finalStartAction?.["completedAt"]),
      stop_action_state: stopState,
      stop_action_failure: stopFailure ?? null,
      stop_action_completed_at: stopCompletedIso,
    };

    const updatePayload: Record<string, unknown> = {
      raw_enode_payload: updatedPayload,
      enode_metadata: updatedMetadata,
    };
    if (nextStatus !== session.status) {
      updatePayload.status = nextStatus;
    }
    if (stopCompletedIso && stopCompletedIso !== session.end_at) {
      updatePayload.end_at = stopCompletedIso;
    }

    const { data: updated, error: updateError } = await supabase
      .from("station_charging_sessions")
      .update(updatePayload)
      .eq("id", session.id)
      .select("id, status, end_at")
      .single();

    if (updateError || !updated) {
      console.error("driver-sync-charging-session update error", updateError);
      return new Response(
        JSON.stringify({
          error: "Impossible de mettre à jour la session de charge.",
        }),
        { status: 500, headers: withJson(corsHeaders) },
      );
    }

    const summary = {
      session_id: updated.id,
      status: updated.status,
      start_action_state: startState,
      stop_action_state: stopState,
      start_failure: startFailure ?? null,
      stop_failure: stopFailure ?? null,
    };

    return new Response(
      JSON.stringify(summary),
      { status: 200, headers: withJson(corsHeaders) },
    );
  } catch (error) {
    return handleError(error);
  }
});

async function loadSession(
  supabase: ReturnType<typeof createSupabaseClient>,
  sessionId: string,
): Promise<SessionRow | null> {
  const { data, error } = await supabase
    .from("station_charging_sessions")
    .select(`
      id,
      station_id,
      driver_profile_id,
      status,
      slot_id,
      start_at,
      end_at,
      enode_action_start_id,
      enode_action_stop_id,
      enode_metadata,
      raw_enode_payload,
      station:stations (
        id,
        owner_id,
        enode_charger_id
      )
    `)
    .eq("id", sessionId)
    .maybeSingle();

  if (error) {
    console.error("driver-sync-charging-session load error", error);
    throw new Error("Impossible de charger la session demandée.");
  }

  return data as SessionRow | null;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return null;
}

function mapActionState(value: unknown): ActionState | null {
  if (typeof value !== "string") return null;
  const upper = value.toUpperCase();
  if (
    upper === "PENDING" || upper === "CONFIRMED" || upper === "FAILED" ||
    upper === "CANCELLED"
  ) {
    return upper as ActionState;
  }
  return null;
}

function computeSessionStatus(
  currentStatus: ChargingSessionStatus,
  startState: ActionState | null,
  stopState: ActionState | null,
): ChargingSessionStatus {
  if (startState === "FAILED" || stopState === "FAILED") {
    return "failed";
  }
  if (stopState === "CONFIRMED") {
    return "completed";
  }
  if (
    (startState === "CANCELLED" || stopState === "CANCELLED") &&
    startState !== "CONFIRMED" && stopState !== "CONFIRMED"
  ) {
    return "cancelled";
  }
  if (startState === "CONFIRMED" && (stopState === null || stopState === "PENDING")) {
    // La doc Enode indique qu'une action START CONFIRMED signifie que la borne délivre la charge.
    return "in_progress";
  }
  if (
    startState === "PENDING" &&
    (!stopState || stopState === "PENDING")
  ) {
    return "pending";
  }
  return currentStatus;
}

function normalizeIso(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const parsed = Date.parse(value);
  if (Number.isNaN(parsed)) return null;
  return new Date(parsed).toISOString();
}

function withJson(headers: Record<string, string>) {
  return {
    ...headers,
    "Content-Type": "application/json",
  };
}

function handleError(error: unknown) {
  if (error instanceof EnodeHttpError) {
    return new Response(
      JSON.stringify({
        error: "Erreur Enode lors de la synchronisation.",
        enode_status: error.status,
        enode_body: error.body,
        context: error.context,
      }),
      {
        status: error.status >= 500 ? 502 : error.status,
        headers: withJson(corsHeaders),
      },
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

  if (error instanceof Error) {
    console.error("driver-sync-charging-session error", error);
  } else {
    console.error("driver-sync-charging-session unknown error", error);
  }

  return new Response(
    JSON.stringify({
      error:
        "Impossible de synchroniser la session de charge. Réessayez dans un instant.",
    }),
    { status: 500, headers: withJson(corsHeaders) },
  );
}
