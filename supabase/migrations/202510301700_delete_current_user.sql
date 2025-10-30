-- Migration: create delete_current_user helper to remove auth + profile rows

BEGIN;

CREATE OR REPLACE FUNCTION public.delete_current_user()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'delete_current_user: aucun utilisateur connecté';
  END IF;

  DELETE FROM public.profiles WHERE id = v_uid;
  DELETE FROM auth.users WHERE id = v_uid;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_current_user() TO authenticated;

COMMIT;

/*
-- Rollback
BEGIN;
  REVOKE EXECUTE ON FUNCTION public.delete_current_user() FROM authenticated;
  DROP FUNCTION IF EXISTS public.delete_current_user();
COMMIT;
*/
