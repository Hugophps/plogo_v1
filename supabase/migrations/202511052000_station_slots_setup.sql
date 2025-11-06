-- Migration : création de la table station_slots et ajout des règles récurrentes sur stations

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

BEGIN;

ALTER TABLE public.stations
  ADD COLUMN IF NOT EXISTS recurring_rules jsonb NOT NULL DEFAULT '[]'::jsonb;

CREATE TABLE IF NOT EXISTS public.station_slots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  station_id uuid NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
  start_at timestamptz NOT NULL,
  end_at timestamptz NOT NULL,
  type text NOT NULL CHECK (type IN (
    'recurring_unavailability',
    'owner_block',
    'member_booking'
  )),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS station_slots_station_start_idx
  ON public.station_slots (station_id, start_at);

CREATE OR REPLACE FUNCTION public.handle_station_slots_updated()
RETURNS trigger AS
$$
BEGIN
  NEW.updated_at := timezone('utc', now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_station_slots_updated ON public.station_slots;
CREATE TRIGGER on_station_slots_updated
BEFORE UPDATE ON public.station_slots
FOR EACH ROW
EXECUTE FUNCTION public.handle_station_slots_updated();

ALTER TABLE public.station_slots ENABLE ROW LEVEL SECURITY;

DO $policy$
BEGIN
  CREATE POLICY station_slots_select_owner_or_member
    ON public.station_slots
    FOR SELECT
    USING (
      EXISTS (
        SELECT 1
        FROM public.stations s
        WHERE s.id = station_id AND s.owner_id = auth.uid()
      )
      OR EXISTS (
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
  CREATE POLICY station_slots_insert_owner
    ON public.station_slots
    FOR INSERT
    WITH CHECK (
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

DO $policy$
BEGIN
  CREATE POLICY station_slots_update_owner
    ON public.station_slots
    FOR UPDATE
    USING (
      EXISTS (
        SELECT 1
        FROM public.stations s
        WHERE s.id = station_id AND s.owner_id = auth.uid()
      )
    )
    WITH CHECK (
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

DO $policy$
BEGIN
  CREATE POLICY station_slots_delete_owner
    ON public.station_slots
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
  ALTER TABLE public.stations DROP COLUMN IF EXISTS recurring_rules;
  DROP TRIGGER IF EXISTS on_station_slots_updated ON public.station_slots;
  DROP FUNCTION IF EXISTS public.handle_station_slots_updated;
  DROP TABLE IF EXISTS public.station_slots;
COMMIT;
*/
