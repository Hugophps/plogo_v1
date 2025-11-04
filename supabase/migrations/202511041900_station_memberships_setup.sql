-- Migration: création de la table station_memberships pour gérer les membres des bornes

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

BEGIN;

CREATE TABLE IF NOT EXISTS public.station_memberships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  station_id uuid NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved')),
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  approved_at timestamptz
);

CREATE UNIQUE INDEX IF NOT EXISTS station_memberships_unique
  ON public.station_memberships (station_id, profile_id);

CREATE OR REPLACE FUNCTION public.handle_station_memberships_updated()
RETURNS trigger AS
$$
BEGIN
  NEW.updated_at := timezone('utc', now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_station_memberships_updated ON public.station_memberships;
CREATE TRIGGER on_station_memberships_updated
BEFORE UPDATE ON public.station_memberships
FOR EACH ROW
EXECUTE FUNCTION public.handle_station_memberships_updated();

ALTER TABLE public.station_memberships ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  CREATE POLICY station_memberships_select_self_or_owner
    ON public.station_memberships
    FOR SELECT
    USING (
      auth.uid() = profile_id
      OR EXISTS (
        SELECT 1 FROM public.stations s
        WHERE s.id = station_id AND s.owner_id = auth.uid()
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$$;

DO $$
BEGIN
  CREATE POLICY station_memberships_insert_self
    ON public.station_memberships
    FOR INSERT
    WITH CHECK (auth.uid() = profile_id);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$$;

DO $$
BEGIN
  CREATE POLICY station_memberships_update_owner
    ON public.station_memberships
    FOR UPDATE
    USING (
      EXISTS (
        SELECT 1 FROM public.stations s
        WHERE s.id = station_id AND s.owner_id = auth.uid()
      )
    )
    WITH CHECK (
      EXISTS (
        SELECT 1 FROM public.stations s
        WHERE s.id = station_id AND s.owner_id = auth.uid()
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$$;

DO $$
BEGIN
  CREATE POLICY station_memberships_delete_owner_or_self
    ON public.station_memberships
    FOR DELETE
    USING (
      auth.uid() = profile_id
      OR EXISTS (
        SELECT 1 FROM public.stations s
        WHERE s.id = station_id AND s.owner_id = auth.uid()
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$$;

COMMIT;

/*
-- Rollback
BEGIN;
  DROP TRIGGER IF EXISTS on_station_memberships_updated ON public.station_memberships;
  DROP FUNCTION IF EXISTS public.handle_station_memberships_updated;
  DROP TABLE IF EXISTS public.station_memberships;
COMMIT;
*/
