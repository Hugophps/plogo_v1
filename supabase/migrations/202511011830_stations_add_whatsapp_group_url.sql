-- Migration: ajout du lien de groupe WhatsApp pour les bornes

BEGIN;

ALTER TABLE public.stations
  ADD COLUMN IF NOT EXISTS whatsapp_group_url text;

COMMIT;

/*
-- Rollback
BEGIN;
  ALTER TABLE public.stations
    DROP COLUMN IF EXISTS whatsapp_group_url;
COMMIT;
*/
