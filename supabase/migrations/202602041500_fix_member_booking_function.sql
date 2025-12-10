-- Migration : correction de la fonction de paiement des réservations (alias explicites)

BEGIN;

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

  SELECT m.profile_id INTO driver_id
  FROM public.station_memberships m
  WHERE m.id = membership_id;

  IF driver_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT s.owner_id, s.name
    INTO owner_id, station_name
  FROM public.stations s
  WHERE s.id = NEW.station_id;

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

COMMIT;
