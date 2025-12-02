#!/usr/bin/env bash
# Petit utilitaire pour éviter de retenir les commandes Supabase.
# Usage : ./supabase/functions_helper.sh <action> <fonction> [payload]
# action  : serve | invoke | deploy
# fonction: enode-chargers | google-places | ...
# payload : JSON (chaîne) à transmettre lors d'un invoke (facultatif)

set -euo pipefail

if ! command -v supabase >/dev/null 2>&1; then
  echo "Le CLI Supabase n'est pas installé. Installe-le puis relance." >&2
  exit 1
fi

ACTION=${1:-}
FUNCTION=${2:-}
PAYLOAD=${3:-}

if [[ -z "$ACTION" || -z "$FUNCTION" ]]; then
  echo "Usage : ./supabase/functions_helper.sh <serve|invoke|deploy> <nom_fonction> [payload]" >&2
  exit 1
fi

ENV_FILE="$(dirname "$0")/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Fichier $ENV_FILE introuvable. Crée-le avec tes secrets." >&2
  exit 1
fi

case "$ACTION" in
  serve)
    supabase functions serve "$FUNCTION" --env-file "$ENV_FILE"
    ;;
  deploy)
    supabase functions deploy "$FUNCTION"
    ;;
  invoke)
    if [[ -z "$PAYLOAD" ]]; then
      echo "Tu dois fournir un payload JSON, exemple : '{\"action\":\"vendors\"}'" >&2
      exit 1
    fi
    supabase functions invoke "$FUNCTION" --env-file "$ENV_FILE" --body "$PAYLOAD"
    ;;
  *)
    echo "Action inconnue : $ACTION (serve, invoke ou deploy)" >&2
    exit 1
    ;;
esac
