-- Migration: add optional description column and constraint length for profiles

BEGIN;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS description text;

DO $$
BEGIN
  ALTER TABLE public.profiles
    ADD CONSTRAINT profiles_description_length
    CHECK (description IS NULL OR char_length(description) <= 150);
EXCEPTION
  WHEN duplicate_object THEN NULL;
END
$$;

COMMIT;

/*
-- Rollback (manuel)
BEGIN;
  ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_description_length;
  ALTER TABLE public.profiles DROP COLUMN IF EXISTS description;
COMMIT;
*/
