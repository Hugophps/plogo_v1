-- Migration: Initialise/mettre à jour la table profiles et ses politiques
-- Exécutée via `supabase db push`

BEGIN;

CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text,
  full_name text,
  phone_number text,
  street_name text,
  street_number text,
  postal_code text,
  city text,
  country text,
  vehicle_brand text,
  vehicle_model text,
  vehicle_plate text,
  vehicle_plug_type text,
  avatar_url text,
  station_name text,
  next_session_status text,
  role text,
  profile_completed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS email text,
  ADD COLUMN IF NOT EXISTS full_name text,
  ADD COLUMN IF NOT EXISTS phone_number text,
  ADD COLUMN IF NOT EXISTS street_name text,
  ADD COLUMN IF NOT EXISTS street_number text,
  ADD COLUMN IF NOT EXISTS postal_code text,
  ADD COLUMN IF NOT EXISTS city text,
  ADD COLUMN IF NOT EXISTS country text,
  ADD COLUMN IF NOT EXISTS vehicle_brand text,
  ADD COLUMN IF NOT EXISTS vehicle_model text,
  ADD COLUMN IF NOT EXISTS vehicle_plate text,
  ADD COLUMN IF NOT EXISTS vehicle_plug_type text,
  ADD COLUMN IF NOT EXISTS avatar_url text,
  ADD COLUMN IF NOT EXISTS station_name text,
  ADD COLUMN IF NOT EXISTS next_session_status text,
  ADD COLUMN IF NOT EXISTS role text,
  ADD COLUMN IF NOT EXISTS profile_completed boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT timezone('utc', now());

ALTER TABLE public.profiles
  ALTER COLUMN profile_completed SET DEFAULT false,
  ALTER COLUMN profile_completed SET NOT NULL,
  ALTER COLUMN created_at SET DEFAULT timezone('utc', now()),
  ALTER COLUMN created_at SET NOT NULL,
  ALTER COLUMN updated_at SET DEFAULT timezone('utc', now()),
  ALTER COLUMN updated_at SET NOT NULL;

DO $$
BEGIN
  ALTER TABLE public.profiles
    ADD CONSTRAINT profiles_role_check
    CHECK (role IN ('owner', 'driver'));
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$$;

CREATE OR REPLACE FUNCTION public.handle_profiles_updated()
RETURNS trigger AS
$$
BEGIN
  NEW.updated_at := timezone('utc', now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_profiles_updated ON public.profiles;
CREATE TRIGGER on_profiles_updated
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.handle_profiles_updated();

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  CREATE POLICY profiles_select_self
    ON public.profiles
    FOR SELECT
    USING (auth.uid() = id);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$$;

DO $$
BEGIN
  CREATE POLICY profiles_insert_self
    ON public.profiles
    FOR INSERT
    WITH CHECK (auth.uid() = id);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$$;

DO $$
BEGIN
  CREATE POLICY profiles_update_self
    ON public.profiles
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$$;

COMMIT;

/*
-- Rollback manuel (à exécuter uniquement si nécessaire)
BEGIN;
  DROP TRIGGER IF EXISTS on_profiles_updated ON public.profiles;
  DROP FUNCTION IF EXISTS public.handle_profiles_updated;
  DROP TABLE IF EXISTS public.profiles;
COMMIT;
*/
