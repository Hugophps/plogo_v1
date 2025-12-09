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
