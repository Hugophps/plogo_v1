-- Migration : création des sessions de charge conducteur

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typname = 'charging_session_status'
  ) THEN
    CREATE TYPE public.charging_session_status AS ENUM (
      'pending',
      'ready',
      'in_progress',
      'completed',
      'failed',
      'cancelled'
    );
  END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS public.station_charging_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  station_id uuid NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
  driver_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  slot_id uuid REFERENCES public.station_slots(id) ON DELETE SET NULL,
  status public.charging_session_status NOT NULL DEFAULT 'pending',
  start_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  end_at timestamptz,
  energy_kwh numeric,
  amount_eur numeric,
  enode_action_id text,
  enode_metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS station_charging_sessions_station_idx
  ON public.station_charging_sessions (station_id, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS station_charging_sessions_active_unique
  ON public.station_charging_sessions (station_id, driver_profile_id)
  WHERE status IN ('pending', 'ready', 'in_progress');

CREATE OR REPLACE FUNCTION public.handle_station_charging_sessions_updated()
RETURNS trigger AS
$$
BEGIN
  NEW.updated_at := timezone('utc', now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_station_charging_sessions_updated
  ON public.station_charging_sessions;
CREATE TRIGGER on_station_charging_sessions_updated
BEFORE UPDATE ON public.station_charging_sessions
FOR EACH ROW
EXECUTE FUNCTION public.handle_station_charging_sessions_updated();

ALTER TABLE public.station_charging_sessions ENABLE ROW LEVEL SECURITY;

DO $policy$
BEGIN
  CREATE POLICY station_charging_sessions_select_owner_or_driver
    ON public.station_charging_sessions
    FOR SELECT
    USING (
      EXISTS (
        SELECT 1
        FROM public.stations s
        WHERE s.id = station_id AND s.owner_id = auth.uid()
      )
      OR driver_profile_id = auth.uid()
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$policy$;

DO $policy$
BEGIN
  CREATE POLICY station_charging_sessions_insert_driver
    ON public.station_charging_sessions
    FOR INSERT
    WITH CHECK (
      driver_profile_id = auth.uid()
      AND EXISTS (
        SELECT 1
        FROM public.station_memberships m
        WHERE m.station_id = station_id
          AND m.profile_id = auth.uid()
          AND m.status = 'approved'
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$policy$;

DO $policy$
BEGIN
  CREATE POLICY station_charging_sessions_update_owner_or_driver
    ON public.station_charging_sessions
    FOR UPDATE
    USING (
      driver_profile_id = auth.uid()
      OR EXISTS (
        SELECT 1
        FROM public.stations s
        WHERE s.id = station_id AND s.owner_id = auth.uid()
      )
    )
    WITH CHECK (
      driver_profile_id = auth.uid()
      OR EXISTS (
        SELECT 1
        FROM public.stations s
        WHERE s.id = station_id AND s.owner_id = auth.uid()
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$policy$;

DO $policy$
BEGIN
  CREATE POLICY station_charging_sessions_delete_owner
    ON public.station_charging_sessions
    FOR DELETE
    USING (
      EXISTS (
        SELECT 1
        FROM public.stations s
        WHERE s.id = station_id AND s.owner_id = auth.uid()
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$policy$;

COMMIT;

/*
-- Rollback
BEGIN;
  DROP POLICY IF EXISTS station_charging_sessions_delete_owner
    ON public.station_charging_sessions;
  DROP POLICY IF EXISTS station_charging_sessions_update_owner_or_driver
    ON public.station_charging_sessions;
  DROP POLICY IF EXISTS station_charging_sessions_insert_driver
    ON public.station_charging_sessions;
  DROP POLICY IF EXISTS station_charging_sessions_select_owner_or_driver
    ON public.station_charging_sessions;
  DROP TRIGGER IF EXISTS on_station_charging_sessions_updated
    ON public.station_charging_sessions;
  DROP FUNCTION IF EXISTS public.handle_station_charging_sessions_updated;
  DROP INDEX IF EXISTS station_charging_sessions_active_unique;
  DROP INDEX IF EXISTS station_charging_sessions_station_idx;
  DROP TABLE IF EXISTS public.station_charging_sessions;
  DROP TYPE IF EXISTS public.charging_session_status;
COMMIT;
*/
