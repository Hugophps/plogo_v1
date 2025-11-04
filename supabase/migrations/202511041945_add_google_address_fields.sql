-- Migration: ajout des colonnes d'adresse Google pour profils et bornes

BEGIN;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS address_place_id text,
  ADD COLUMN IF NOT EXISTS address_lat double precision,
  ADD COLUMN IF NOT EXISTS address_lng double precision,
  ADD COLUMN IF NOT EXISTS address_formatted text,
  ADD COLUMN IF NOT EXISTS address_components jsonb;

ALTER TABLE public.stations
  ADD COLUMN IF NOT EXISTS location_place_id text,
  ADD COLUMN IF NOT EXISTS location_lat double precision,
  ADD COLUMN IF NOT EXISTS location_lng double precision,
  ADD COLUMN IF NOT EXISTS location_formatted text,
  ADD COLUMN IF NOT EXISTS location_components jsonb;

COMMIT;

/*
-- Rollback
BEGIN;
  ALTER TABLE public.stations
    DROP COLUMN IF EXISTS location_components,
    DROP COLUMN IF EXISTS location_formatted,
    DROP COLUMN IF EXISTS location_lng,
    DROP COLUMN IF EXISTS location_lat,
    DROP COLUMN IF EXISTS location_place_id;

  ALTER TABLE public.profiles
    DROP COLUMN IF EXISTS address_components,
    DROP COLUMN IF EXISTS address_formatted,
    DROP COLUMN IF EXISTS address_lng,
    DROP COLUMN IF EXISTS address_lat,
    DROP COLUMN IF EXISTS address_place_id;
COMMIT;
*/
