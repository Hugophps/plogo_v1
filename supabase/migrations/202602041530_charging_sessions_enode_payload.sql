-- Migration : ajout de colonnes Enode pour les sessions de charge

BEGIN;

ALTER TABLE public.station_charging_sessions
  ADD COLUMN IF NOT EXISTS enode_action_start_id text,
  ADD COLUMN IF NOT EXISTS enode_action_stop_id text,
  ADD COLUMN IF NOT EXISTS raw_enode_payload jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMIT;
