-- Migration: création de la table stations et de ses politiques
-- Exécuter via `supabase db push`

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

BEGIN;

INSERT INTO storage.buckets (id, name, public)
VALUES ('stations', 'stations', true)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  public = EXCLUDED.public;

CREATE TABLE IF NOT EXISTS public.stations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name text NOT NULL,
  brand text NOT NULL,
  model text NOT NULL,
  use_profile_address boolean NOT NULL DEFAULT true,
  street_name text NOT NULL,
  street_number text NOT NULL,
  postal_code text NOT NULL,
  city text NOT NULL,
  country text NOT NULL,
  photo_url text,
  additional_info text,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE UNIQUE INDEX IF NOT EXISTS stations_owner_unique
  ON public.stations (owner_id);

CREATE OR REPLACE FUNCTION public.handle_stations_updated()
RETURNS trigger AS
$$
BEGIN
  NEW.updated_at := timezone('utc', now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_stations_updated ON public.stations;
CREATE TRIGGER on_stations_updated
BEFORE UPDATE ON public.stations
FOR EACH ROW
EXECUTE FUNCTION public.handle_stations_updated();

ALTER TABLE public.stations ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  CREATE POLICY stations_select_self
    ON public.stations
    FOR SELECT
    USING (auth.uid() = owner_id);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$$;

DO $$
BEGIN
  CREATE POLICY stations_insert_self
    ON public.stations
    FOR INSERT
    WITH CHECK (auth.uid() = owner_id);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$$;

DO $$
BEGIN
  CREATE POLICY stations_update_self
    ON public.stations
    FOR UPDATE
    USING (auth.uid() = owner_id)
    WITH CHECK (auth.uid() = owner_id);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$$;

DO $$
BEGIN
  CREATE POLICY stations_delete_self
    ON public.stations
    FOR DELETE
    USING (auth.uid() = owner_id);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$$;

DO $$
BEGIN
  CREATE POLICY "Stations public lecture"
    ON storage.objects
    FOR SELECT
    USING (bucket_id = 'stations');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$$;

DO $$
BEGIN
  CREATE POLICY "Stations propriétaires upload"
    ON storage.objects
    FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'stations' AND auth.uid() = owner);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$$;

DO $$
BEGIN
  CREATE POLICY "Stations propriétaires mise à jour"
    ON storage.objects
    FOR UPDATE
    TO authenticated
    USING (bucket_id = 'stations' AND auth.uid() = owner)
    WITH CHECK (bucket_id = 'stations' AND auth.uid() = owner);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$$;

DO $$
BEGIN
  CREATE POLICY "Stations propriétaires suppression"
    ON storage.objects
    FOR DELETE
    TO authenticated
    USING (bucket_id = 'stations' AND auth.uid() = owner);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$$;

COMMIT;

/*
-- Rollback manuel
BEGIN;
  DROP TRIGGER IF EXISTS on_stations_updated ON public.stations;
  DROP FUNCTION IF EXISTS public.handle_stations_updated;
  DROP TABLE IF EXISTS public.stations;
COMMIT;
*/
