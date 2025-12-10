/// <reference lib="deno.ns" />
/// <reference lib="deno.unstable" />

import {
  BOOKING_PAYMENT_SELECT,
  serializeBookingPayment,
} from "../_shared/booking_payments.ts";
import { createSupabaseClient } from "../_shared/supabase.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type Payload = {
  slot_id?: string;
  action?: string;
};

type Action = "confirm" | "cancel";

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

  let payload: Payload;
  try {
    payload = await req.json();
  } catch (_) {
    return new Response(
      JSON.stringify({ error: "Corps de requête invalide" }),
      { status: 400, headers: withJson(corsHeaders) },
    );
  }

  const slotId = payload.slot_id?.trim();
  if (!slotId) {
    return new Response(
      JSON.stringify({ error: "slot_id est requis" }),
      { status: 400, headers: withJson(corsHeaders) },
    );
  }

  const action: Action = payload.action === "cancel" ? "cancel" : "confirm";

  try {
    const { data: paymentRow, error } = await supabase
      .from("station_booking_payments")
      .select(BOOKING_PAYMENT_SELECT)
      .eq("slot_id", slotId)
      .maybeSingle();

    if (error) {
      console.error("owner action select error", error);
      throw new Error("Impossible de récupérer le créneau.");
    }

    if (!paymentRow) {
      return new Response(
        JSON.stringify({ error: "Session réservée introuvable." }),
        { status: 404, headers: withJson(corsHeaders) },
      );
    }

    if (paymentRow.owner_profile_id !== user.id) {
      return new Response(
        JSON.stringify({ error: "Action non autorisée." }),
        { status: 403, headers: withJson(corsHeaders) },
      );
    }

    const currentStatus = `${paymentRow.status ?? ""}`;

    if (action === "confirm") {
      if (currentStatus !== "driver_marked") {
        return new Response(
          JSON.stringify({ error: "Le conducteur n'a pas encore signalé le paiement." }),
          { status: 400, headers: withJson(corsHeaders) },
        );
      }
      const updatePayload = {
        status: "paid",
        owner_marked_at: new Date().toISOString(),
      };
      const { data: updated, error: updateError } = await supabase
        .from("station_booking_payments")
        .update(updatePayload)
        .eq("id", paymentRow.id)
        .select(BOOKING_PAYMENT_SELECT)
        .maybeSingle();
      if (updateError || !updated) {
        console.error("owner action update error", updateError);
        throw new Error("Impossible de valider le paiement.");
      }
      return new Response(
        JSON.stringify({ item: serializeBookingPayment(updated, "owner") }),
        { status: 200, headers: withJson(corsHeaders) },
      );
    }

    if (currentStatus !== "paid") {
      return new Response(
        JSON.stringify({ error: "Aucune validation finale à annuler." }),
        { status: 400, headers: withJson(corsHeaders) },
      );
    }

    const { data: reverted, error: revertError } = await supabase
      .from("station_booking_payments")
      .update({
        status: "driver_marked",
        owner_marked_at: null,
      })
      .eq("id", paymentRow.id)
      .select(BOOKING_PAYMENT_SELECT)
      .maybeSingle();

    if (revertError || !reverted) {
      console.error("owner action revert error", revertError);
      throw new Error("Impossible d'annuler la validation.");
    }

    return new Response(
      JSON.stringify({ item: serializeBookingPayment(reverted, "owner") }),
      { status: 200, headers: withJson(corsHeaders) },
    );
  } catch (error) {
    console.error("booking-payments-owner-action error", error);
    return new Response(
      JSON.stringify({ error: "Impossible de mettre à jour le paiement." }),
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
