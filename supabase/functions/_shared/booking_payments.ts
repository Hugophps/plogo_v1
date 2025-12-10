import { createSupabaseClient } from "./supabase.ts";

export type SupabaseClient = ReturnType<typeof createSupabaseClient>;

export const BOOKING_PAYMENT_SELECT = `
  id,
  station_id,
  slot_id,
  membership_id,
  driver_profile_id,
  owner_profile_id,
  status,
  payment_reference,
  total_energy_kwh,
  total_amount,
  driver_marked_at,
  owner_marked_at,
  created_at,
  updated_at,
  station:stations(
    id,
    name,
    street_name,
    street_number,
    postal_code,
    city,
    country,
    price_per_kwh
  ),
  slot:station_slots(
    id,
    start_at,
    end_at
  ),
  membership:station_memberships(
    id,
    profile_id,
    profile:profiles(
      id,
      full_name,
      vehicle_brand,
      vehicle_model,
      vehicle_plate
    )
  )
`;

export type BookingPaymentRole = "driver" | "owner";

export function serializeBookingPayment(
  row: Record<string, unknown>,
  role: BookingPaymentRole,
) {
  const station = (row["station"] ?? null) as Record<string, unknown> | null;
  const slot = (row["slot"] ?? null) as Record<string, unknown> | null;
  const membership = (row["membership"] ?? null) as Record<string, unknown> | null;
  const driverProfile = membership?.["profile"] as
    | Record<string, unknown>
    | null
    | undefined;

  return {
    id: row["id"] ?? null,
    station_id: row["station_id"] ?? null,
    slot_id: row["slot_id"] ?? null,
    membership_id: row["membership_id"] ?? null,
    driver_profile_id: row["driver_profile_id"] ?? null,
    owner_profile_id: row["owner_profile_id"] ?? null,
    status: row["status"] ?? null,
    payment_reference: row["payment_reference"] ?? null,
    total_energy_kwh: asNumber(row["total_energy_kwh"]),
    total_amount: asNumber(row["total_amount"]),
    driver_marked_at: row["driver_marked_at"] ?? null,
    owner_marked_at: row["owner_marked_at"] ?? null,
    created_at: row["created_at"] ?? null,
    updated_at: row["updated_at"] ?? null,
    role,
    station: station
      ? {
          id: station["id"] ?? row["station_id"],
          name: station["name"] ?? null,
          street_name: station["street_name"] ?? null,
          street_number: station["street_number"] ?? null,
          postal_code: station["postal_code"] ?? null,
          city: station["city"] ?? null,
          country: station["country"] ?? null,
          price_per_kwh: asNumber(station["price_per_kwh"]),
        }
      : null,
    slot: slot
      ? {
          id: slot["id"] ?? row["slot_id"],
          start_at: slot["start_at"] ?? null,
          end_at: slot["end_at"] ?? null,
        }
      : null,
    driver: driverProfile
      ? {
          id: driverProfile["id"] ?? null,
          full_name: driverProfile["full_name"] ?? null,
          vehicle_brand: driverProfile["vehicle_brand"] ?? null,
          vehicle_model: driverProfile["vehicle_model"] ?? null,
          vehicle_plate: driverProfile["vehicle_plate"] ?? null,
        }
      : null,
  };
}

function asNumber(value: unknown): number | null {
  if (typeof value === "number") return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  if (typeof value === "bigint") {
    return Number(value);
  }
  return null;
}
