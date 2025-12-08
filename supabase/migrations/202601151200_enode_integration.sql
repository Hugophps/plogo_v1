-- Migration : ajout du support Enode sur les profils/stations
-- À exécuter via `supabase db push`

BEGIN;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS enode_user_id text;

ALTER TABLE public.stations
  ADD COLUMN IF NOT EXISTS enode_charger_id text,
  ADD COLUMN IF NOT EXISTS enode_metadata jsonb,
  ALTER COLUMN charger_brand DROP NOT NULL,
  ALTER COLUMN charger_model DROP NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'stations_owner_enode_unique'
  ) THEN
    EXECUTE 'CREATE UNIQUE INDEX stations_owner_enode_unique
      ON public.stations (owner_id)
      WHERE enode_charger_id IS NOT NULL';
  END IF;
END
$$;

COMMIT;

/*
-- Rollback manuel
BEGIN;
  ALTER TABLE public.stations
    ALTER COLUMN charger_brand SET NOT NULL,
    ALTER COLUMN charger_model SET NOT NULL,
    DROP COLUMN IF EXISTS enode_charger_id,
    DROP COLUMN IF EXISTS enode_metadata;
  ALTER TABLE public.profiles
    DROP COLUMN IF EXISTS enode_user_id;
  DROP INDEX IF EXISTS public.stations_owner_enode_unique;
COMMIT;
*/
