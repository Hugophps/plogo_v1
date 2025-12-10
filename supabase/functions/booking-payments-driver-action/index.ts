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

type Action = "mark" | "cancel";

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

  const action: Action = payload.action === "cancel" ? "cancel" : "mark";

  try {
    const { data: paymentRow, error } = await supabase
      .from("station_booking_payments")
      .select(BOOKING_PAYMENT_SELECT)
      .eq("slot_id", slotId)
      .maybeSingle();

    if (error) {
      console.error("driver action select error", error);
      throw new Error("Impossible de récupérer le créneau.");
    }

    if (!paymentRow) {
      return new Response(
        JSON.stringify({ error: "Session réservée introuvable." }),
        { status: 404, headers: withJson(corsHeaders) },
      );
    }

    if (paymentRow.driver_profile_id !== user.id) {
      return new Response(
        JSON.stringify({ error: "Action non autorisée." }),
        { status: 403, headers: withJson(corsHeaders) },
      );
    }

    const currentStatus = `${paymentRow.status ?? ""}`;

    if (action === "mark" && currentStatus === "driver_marked") {
      return new Response(
        JSON.stringify({ item: serializeBookingPayment(paymentRow, "driver") }),
        { status: 200, headers: withJson(corsHeaders) },
      );
    }

    if (currentStatus === "paid") {
      return new Response(
        JSON.stringify({ error: "Le propriétaire a déjà confirmé ce paiement." }),
        { status: 400, headers: withJson(corsHeaders) },
      );
    }

    if (action === "mark" && presentAmount(paymentRow.total_amount) <= 0) {
      return new Response(
        JSON.stringify({ error: "Aucun montant à régler pour ce créneau." }),
        { status: 400, headers: withJson(corsHeaders) },
      );
    }

    let updatePayload: Record<string, unknown>;
    if (action === "mark") {
      if (!currentStatus || !["to_pay", "driver_marked"].includes(currentStatus)) {
        return new Response(
          JSON.stringify({ error: "Ce créneau n'est pas à régler pour le moment." }),
          { status: 400, headers: withJson(corsHeaders) },
        );
      }
      updatePayload = {
        status: "driver_marked",
        driver_marked_at: paymentRow.driver_marked_at ?? new Date().toISOString(),
      };
    } else {
      if (currentStatus !== "driver_marked") {
        return new Response(
          JSON.stringify({ error: "Vous n'avez pas signalé de paiement pour ce créneau." }),
          { status: 400, headers: withJson(corsHeaders) },
        );
      }
      updatePayload = {
        status: "to_pay",
        driver_marked_at: null,
        owner_marked_at: null,
      };
    }

    const { data: updatedRow, error: updateError } = await supabase
      .from("station_booking_payments")
      .update(updatePayload)
      .eq("id", paymentRow.id)
      .select(BOOKING_PAYMENT_SELECT)
      .maybeSingle();

    if (updateError || !updatedRow) {
      console.error("driver action update error", updateError);
      throw new Error("Impossible de mettre à jour le paiement.");
    }

    return new Response(
      JSON.stringify({ item: serializeBookingPayment(updatedRow, "driver") }),
      { status: 200, headers: withJson(corsHeaders) },
    );
  } catch (error) {
    console.error("booking-payments-driver-action error", error);
    return new Response(
      JSON.stringify({ error: "Impossible de mettre à jour le paiement." }),
      { status: 500, headers: withJson(corsHeaders) },
    );
  }
});

function presentAmount(value: unknown): number {
  if (typeof value === "number") return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

function withJson(headers: Record<string, string>) {
  return {
    ...headers,
    "Content-Type": "application/json",
  };
}
