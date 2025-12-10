-- Migration : automatisation des enregistrements de paiements par créneau

BEGIN;

CREATE OR REPLACE FUNCTION public.generate_booking_payment_reference(
  station_name text,
  slot_start timestamptz,
  slot_uuid uuid
) RETURNS text AS
$$
DECLARE
  sanitized text;
  prefix text;
  slot_suffix text;
BEGIN
  sanitized := upper(regexp_replace(coalesce(station_name, 'PLOGO'), '[^A-Z0-9]', '', 'g'));
  IF sanitized IS NULL OR length(sanitized) = 0 THEN
    prefix := 'PLOGO';
  ELSE
    prefix := left(sanitized, 6);
  END IF;

  slot_suffix := right(replace(coalesce(slot_uuid::text, ''), '-', ''), 4);
  IF slot_suffix IS NULL OR length(slot_suffix) = 0 THEN
    slot_suffix := '0000';
  END IF;

  RETURN left(
    prefix || to_char(slot_start AT TIME ZONE 'UTC', 'YYMMDDHH24MI') || slot_suffix,
    20
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION public.handle_member_booking_payments()
RETURNS trigger AS
$$
DECLARE
  membership_id uuid;
  driver_id uuid;
  owner_id uuid;
  station_name text;
  initial_status booking_payment_status;
BEGIN
  IF NEW.type <> 'member_booking' THEN
    RETURN NEW;
  END IF;

  membership_id := (NEW.metadata ->> 'membership_id')::uuid;
  IF membership_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT profile_id INTO driver_id
  FROM public.station_memberships
  WHERE id = membership_id;

  IF driver_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT owner_id, name INTO owner_id, station_name
  FROM public.stations
  WHERE id = NEW.station_id;

  IF owner_id IS NULL THEN
    RETURN NEW;
  END IF;

  initial_status := CASE
    WHEN NEW.start_at <= timezone('utc', now()) THEN 'in_progress'
    ELSE 'upcoming'
  END;

  INSERT INTO public.station_booking_payments (
    station_id,
    slot_id,
    membership_id,
    driver_profile_id,
    owner_profile_id,
    status,
    payment_reference
  ) VALUES (
    NEW.station_id,
    NEW.id,
    membership_id,
    driver_id,
    owner_id,
    initial_status,
    public.generate_booking_payment_reference(station_name, NEW.start_at, NEW.id)
  )
  ON CONFLICT (slot_id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_member_slot_payment
  ON public.station_slots;
CREATE TRIGGER on_member_slot_payment
AFTER INSERT ON public.station_slots
FOR EACH ROW
EXECUTE FUNCTION public.handle_member_booking_payments();

INSERT INTO public.station_booking_payments (
  station_id,
  slot_id,
  membership_id,
  driver_profile_id,
  owner_profile_id,
  status,
  payment_reference
)
SELECT
  s.station_id,
  s.id,
  m.id AS membership_id,
  m.profile_id,
  st.owner_id,
  (CASE
    WHEN s.start_at <= timezone('utc', now()) THEN 'in_progress'
    ELSE 'upcoming'
  END)::public.booking_payment_status AS status,
  public.generate_booking_payment_reference(st.name, s.start_at, s.id) AS payment_reference
FROM public.station_slots s
JOIN public.station_memberships m
  ON m.id = (s.metadata ->> 'membership_id')::uuid
JOIN public.stations st ON st.id = s.station_id
WHERE s.type = 'member_booking'
ON CONFLICT (slot_id) DO NOTHING;

COMMIT;

/*
-- Rollback
BEGIN;
  DROP TRIGGER IF EXISTS on_member_slot_payment ON public.station_slots;
  DROP FUNCTION IF EXISTS public.handle_member_booking_payments;
  DROP FUNCTION IF EXISTS public.generate_booking_payment_reference;
COMMIT;
*/
