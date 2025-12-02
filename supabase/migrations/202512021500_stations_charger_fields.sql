-- Migration: aligner les champs borne avec l'intégration Enode

BEGIN;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'stations'
      AND column_name = 'brand'
  ) THEN
    ALTER TABLE public.stations
      RENAME COLUMN brand TO charger_brand;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'stations'
      AND column_name = 'model'
  ) THEN
    ALTER TABLE public.stations
      RENAME COLUMN model TO charger_model;
  END IF;
END;
$$;

ALTER TABLE public.stations
  ADD COLUMN IF NOT EXISTS charger_vendor text;

COMMIT;

/*
-- Rollback
BEGIN;
  ALTER TABLE public.stations
    DROP COLUMN IF EXISTS charger_vendor;
  DO $$
  BEGIN
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'stations'
        AND column_name = 'charger_model'
    ) THEN
      ALTER TABLE public.stations
        RENAME COLUMN charger_model TO model;
    END IF;

    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'stations'
        AND column_name = 'charger_brand'
    ) THEN
      ALTER TABLE public.stations
        RENAME COLUMN charger_brand TO brand;
    END IF;
  END;
  $$;
COMMIT;
*/
