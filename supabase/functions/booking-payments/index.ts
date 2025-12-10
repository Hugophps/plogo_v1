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
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

type MatchedRole = "driver" | "owner";

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

  const url = new URL(req.url);
  const roleParam = (url.searchParams.get("role") ?? "driver").toLowerCase();
  const role: MatchedRole = roleParam === "owner" ? "owner" : "driver";
  const statusParam = url.searchParams.get("status");
  const statuses = statusParam
    ? statusParam
      .split(",")
      .map((value) => value.trim())
      .filter((value) => value.length > 0)
    : [];

  try {
    let query = supabase
      .from("station_booking_payments")
      .select(BOOKING_PAYMENT_SELECT)
      .eq(role === "driver" ? "driver_profile_id" : "owner_profile_id", user.id)
      .order("slot(start_at)", { ascending: false })
      .limit(200);

    if (statuses.length > 0) {
      query = query.in("status", statuses);
    }

    const { data, error } = await query;
    if (error) {
      console.error("booking-payments select error", error);
      throw new Error("Impossible de récupérer les sessions de charges.");
    }

    const rows = Array.isArray(data) ? data : [];
    const items = rows.map((row) => serializeBookingPayment(row, role));

    return new Response(
      JSON.stringify({ items, role }),
      { status: 200, headers: withJson(corsHeaders) },
    );
  } catch (error) {
    console.error("booking-payments error", error);
    return new Response(
      JSON.stringify({ error: "Impossible de récupérer les sessions de charges." }),
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
