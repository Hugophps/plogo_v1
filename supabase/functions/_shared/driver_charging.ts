import { createSupabaseClient } from "./supabase.ts";

type SupabaseClient = ReturnType<typeof createSupabaseClient>;

export class DriverChargingError extends Error {
  constructor(message: string, readonly status: number = 400) {
    super(message);
  }
}

type MembershipRow = {
  id: string;
  station_id: string;
  profile_id: string;
  status: string;
  station: StationRow | null;
};

type StationRow = {
  id: string;
  owner_id: string;
  name: string | null;
  enode_charger_id: string | null;
  price_per_kwh: number | null;
};

type OwnerProfile = {
  id: string;
  enode_user_id: string | null;
};

export type DriverStationContext = {
  membership: MembershipRow;
  station: StationRow;
  owner: OwnerProfile;
};

type SlotRow = {
  id: string;
  station_id: string;
  start_at: string;
  end_at: string;
  metadata: Record<string, unknown> | null;
};

export async function loadDriverStationContext(
  supabase: SupabaseClient,
  stationId: string,
  driverId: string,
): Promise<DriverStationContext> {
  const { data, error } = await supabase
    .from("station_memberships")
    .select(`
      id,
      station_id,
      profile_id,
      status,
      station:stations(
        id,
        owner_id,
        name,
        enode_charger_id,
        price_per_kwh
      )
    `)
    .eq("station_id", stationId)
    .eq("profile_id", driverId)
    .eq("status", "approved")
    .maybeSingle();

  if (error) {
    throw new DriverChargingError(
      "Impossible de vérifier votre accès à cette station.",
      500,
    );
  }

  const membership = data as MembershipRow | null;
  if (!membership || !membership.station) {
    throw new DriverChargingError(
      "Vous devez être membre approuvé de cette station.",
      403,
    );
  }

  const { data: ownerProfile, error: ownerError } = await supabase
    .from("profiles")
    .select("id, enode_user_id")
    .eq("id", membership.station.owner_id)
    .maybeSingle();

  if (ownerError) {
    throw new DriverChargingError(
      "Impossible de récupérer les informations du propriétaire.",
      500,
    );
  }

  if (!ownerProfile) {
    throw new DriverChargingError(
      "Propriétaire introuvable pour cette station.",
      404,
    );
  }

  return {
    membership,
    station: membership.station,
    owner: ownerProfile as OwnerProfile,
  };
}

export async function getActiveSlotForMembership(
  supabase: SupabaseClient,
  stationId: string,
  membershipId: string,
  referenceIsoDate: string,
): Promise<SlotRow | null> {
  const { data, error } = await supabase
    .from("station_slots")
    .select("id, station_id, start_at, end_at, metadata")
    .eq("station_id", stationId)
    .eq("type", "member_booking")
    .eq("metadata->>membership_id", membershipId)
    .lte("start_at", referenceIsoDate)
    .gte("end_at", referenceIsoDate)
    .order("start_at", { ascending: true })
    .limit(1);

  if (error) {
    throw new DriverChargingError(
      "Impossible de vérifier votre créneau de réservation.",
      500,
    );
  }

  if (!data || data.length === 0) {
    return null;
  }

  return data[0] as SlotRow;
}

type BookingPaymentRow = {
  id: string;
  status: string;
  driver_marked_at: string | null;
  owner_marked_at: string | null;
};

type BookingPaymentStatus =
  | "upcoming"
  | "in_progress"
  | "to_pay"
  | "driver_marked"
  | "paid";

export async function ensureBookingPaymentRecord(
  supabase: SupabaseClient,
  params: {
    stationId: string;
    slotId: string;
    membershipId: string;
    driverId: string;
    ownerId: string;
    stationName: string | null;
    slotStartAt: string;
    initialStatus?: BookingPaymentStatus;
  },
): Promise<string> {
  const { data: existing, error } = await supabase
    .from("station_booking_payments")
    .select("id")
    .eq("slot_id", params.slotId)
    .maybeSingle();

  if (error) {
    throw new DriverChargingError(
      "Impossible de préparer le suivi de paiement.",
      500,
    );
  }

  if (existing?.id) {
    return existing.id as string;
  }

  const status = params.initialStatus ??
    (new Date(params.slotStartAt).getTime() <= Date.now()
      ? "in_progress"
      : "upcoming");

  const paymentReference = generatePaymentReference(
    params.stationName,
    params.slotStartAt,
    params.slotId,
  );

  const { data: inserted, error: insertError } = await supabase
    .from("station_booking_payments")
    .insert({
      station_id: params.stationId,
      slot_id: params.slotId,
      membership_id: params.membershipId,
      driver_profile_id: params.driverId,
      owner_profile_id: params.ownerId,
      status,
      payment_reference: paymentReference,
    })
    .select("id")
    .single();

  if (insertError || !inserted) {
    console.error("ensureBookingPaymentRecord insert error", insertError);
    throw new DriverChargingError(
      "Impossible de suivre la session réservée.",
      500,
    );
  }

  return inserted.id as string;
}

export async function updateBookingPaymentTotals(
  supabase: SupabaseClient,
  params: {
    slotId: string;
    slotEndAt: string;
  },
) {
  const { data: paymentRow, error: paymentError } = await supabase
    .from("station_booking_payments")
    .select("id, status, driver_marked_at, owner_marked_at")
    .eq("slot_id", params.slotId)
    .maybeSingle();

  if (paymentError) {
    throw new DriverChargingError(
      "Impossible de récupérer les informations de paiement.",
      500,
    );
  }

  if (!paymentRow) {
    return;
  }

  const { data: sessionRows, error: sessionsError } = await supabase
    .from("station_charging_sessions")
    .select("energy_kwh, amount_eur")
    .eq("slot_id", params.slotId);

  if (sessionsError) {
    throw new DriverChargingError(
      "Impossible de recalculer le montant du créneau.",
      500,
    );
  }

  let totalEnergy = 0;
  let totalAmount = 0;
  for (const row of sessionRows ?? []) {
    const energy = typeof row.energy_kwh === "number"
      ? row.energy_kwh
      : null;
    const amount = typeof row.amount_eur === "number"
      ? row.amount_eur
      : null;
    if (energy) totalEnergy += energy;
    if (amount) totalAmount += amount;
  }

  const hasAmount = totalAmount > 0.009;
  const slotEnded = Date.parse(params.slotEndAt) <= Date.now();
  let nextStatus = paymentRow.status as BookingPaymentStatus;
  if (
    slotEnded && hasAmount &&
    (nextStatus === "upcoming" || nextStatus === "in_progress")
  ) {
    nextStatus = "to_pay";
  } else if (
    !slotEnded &&
    nextStatus === "upcoming"
  ) {
    nextStatus = "in_progress";
  }

  const { error: updateError } = await supabase
    .from("station_booking_payments")
    .update({
      total_energy_kwh: hasAmount ? totalEnergy : null,
      total_amount: hasAmount ? roundCurrency(totalAmount) : null,
      status: nextStatus,
    })
    .eq("id", paymentRow.id as string);

  if (updateError) {
    console.error("updateBookingPaymentTotals error", updateError);
    throw new DriverChargingError(
      "Impossible de mettre à jour le paiement de ce créneau.",
      500,
    );
  }
}

function roundCurrency(value: number) {
  return Math.round(value * 100) / 100;
}

export function generatePaymentReference(
  stationName: string | null,
  slotStartIso: string,
  slotId?: string,
): string {
  const sanitized = (stationName ?? "PLOGO")
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, "");
  const prefix = sanitized.slice(0, 6) || "PLOGO";
  const slotDate = new Date(slotStartIso);
  const yy = slotDate.getUTCFullYear().toString().slice(-2);
  const mm = `${slotDate.getUTCMonth() + 1}`.padStart(2, "0");
  const dd = `${slotDate.getUTCDate()}`.padStart(2, "0");
  const hh = `${slotDate.getUTCHours()}`.padStart(2, "0");
  const min = `${slotDate.getUTCMinutes()}`.padStart(2, "0");
  const seed = `${prefix}${yy}${mm}${dd}${hh}${min}`;
  const slotSuffix = slotId
    ? slotId.replace(/[^A-Z0-9]/gi, "").toUpperCase().slice(-4)
    : "00";
  const combined = `${seed}${slotSuffix}`;
  return combined.slice(0, 20);
}
