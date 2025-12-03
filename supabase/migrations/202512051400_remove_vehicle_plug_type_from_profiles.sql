-- Suppression de la colonne vehicle_plug_type (champ obsolète)

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
      AND column_name = 'vehicle_plug_type'
  ) THEN
    ALTER TABLE public.profiles
      DROP COLUMN vehicle_plug_type;
  END IF;
END
$$;
