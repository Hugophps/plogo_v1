-- Ajout du prix du kWh pour les stations

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'stations'
      AND column_name = 'price_per_kwh'
  ) THEN
    ALTER TABLE public.stations
      ADD COLUMN price_per_kwh numeric(10,2);
  END IF;
END
$$;

COMMENT ON COLUMN public.stations.price_per_kwh IS 'Tarif défini par le propriétaire (€/kWh).';
