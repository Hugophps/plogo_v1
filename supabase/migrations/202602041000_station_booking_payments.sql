-- Migration : sessions réservées & paiements conducteur/propriétaire

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'booking_payment_status'
  ) THEN
    CREATE TYPE public.booking_payment_status AS ENUM (
      'upcoming',
      'in_progress',
      'to_pay',
      'driver_marked',
      'paid'
    );
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS public.station_booking_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  station_id uuid NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
  slot_id uuid NOT NULL UNIQUE REFERENCES public.station_slots(id) ON DELETE CASCADE,
  membership_id uuid NOT NULL REFERENCES public.station_memberships(id) ON DELETE CASCADE,
  driver_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  owner_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status public.booking_payment_status NOT NULL DEFAULT 'upcoming',
  payment_reference text NOT NULL,
  total_energy_kwh numeric,
  total_amount numeric,
  driver_marked_at timestamptz,
  owner_marked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS station_booking_payments_station_idx
  ON public.station_booking_payments (station_id);

CREATE INDEX IF NOT EXISTS station_booking_payments_driver_idx
  ON public.station_booking_payments (driver_profile_id);

CREATE INDEX IF NOT EXISTS station_booking_payments_owner_idx
  ON public.station_booking_payments (owner_profile_id);

CREATE OR REPLACE FUNCTION public.handle_station_booking_payments_updated()
RETURNS trigger AS
$$
BEGIN
  NEW.updated_at := timezone('utc', now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_station_booking_payments_updated
  ON public.station_booking_payments;
CREATE TRIGGER on_station_booking_payments_updated
BEFORE UPDATE ON public.station_booking_payments
FOR EACH ROW
EXECUTE FUNCTION public.handle_station_booking_payments_updated();

ALTER TABLE public.station_booking_payments ENABLE ROW LEVEL SECURITY;

DO $policy$
BEGIN
  CREATE POLICY station_booking_payments_select_participants
    ON public.station_booking_payments
    FOR SELECT
    USING (
      auth.uid() = driver_profile_id
      OR auth.uid() = owner_profile_id
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$policy$;

COMMIT;

/*
-- Rollback
BEGIN;
  DROP POLICY IF EXISTS station_booking_payments_select_participants
    ON public.station_booking_payments;
  DROP TRIGGER IF EXISTS on_station_booking_payments_updated
    ON public.station_booking_payments;
  DROP FUNCTION IF EXISTS public.handle_station_booking_payments_updated;
  DROP TABLE IF EXISTS public.station_booking_payments;
  DROP TYPE IF EXISTS public.booking_payment_status;
COMMIT;
*/
