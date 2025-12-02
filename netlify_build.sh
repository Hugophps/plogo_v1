#!/usr/bin/env bash
# Script de build exécuté par Netlify pour compiler l'application Flutter Web.
# Netlify appelle `bash netlify_build.sh` depuis la racine du dépôt à chaque build.
# Il installe Flutter localement, active la cible web, récupère les dépendances
# et produit la version release dans `build/web` que Netlify publie ensuite.

set -euo pipefail

require_env() {
  local name=$1
  local value=${!name:-}
  if [[ -z "$value" ]]; then
    echo "[Netlify] Erreur: la variable d'environnement $name doit être définie." >&2
    exit 1
  fi
}

require_env SUPABASE_URL
require_env SUPABASE_ANON_KEY

SUPABASE_REDIRECT_URL=${SUPABASE_REDIRECT_URL:-}
GOOGLE_MAPS_API_KEY=${GOOGLE_MAPS_API_KEY:-}

ROOT_DIR="$(pwd)"
FLUTTER_SDK_DIR="${ROOT_DIR}/flutter_sdk"

echo "[Netlify] Installation de Flutter stable..."
rm -rf "$FLUTTER_SDK_DIR"
git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_SDK_DIR"

export PATH="${FLUTTER_SDK_DIR}/bin:${PATH}"

echo "[Netlify] Version Flutter utilisée:" 
flutter --version

echo "[Netlify] Activation du support Web..."
flutter config --enable-web

echo "[Netlify] Récupération des dépendances..."
flutter pub get

echo "[Netlify] Build Flutter Web (release)..."

BUILD_ARGS=(
  "--dart-define=SUPABASE_URL=${SUPABASE_URL}"
  "--dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}"
)

if [[ -n "$SUPABASE_REDIRECT_URL" ]]; then
  BUILD_ARGS+=("--dart-define=SUPABASE_REDIRECT_URL=${SUPABASE_REDIRECT_URL}")
fi

if [[ -n "$GOOGLE_MAPS_API_KEY" ]]; then
  BUILD_ARGS+=("--dart-define=GOOGLE_MAPS_API_KEY=${GOOGLE_MAPS_API_KEY}")
fi

flutter build web --release "${BUILD_ARGS[@]}"

REDIRECTS_FILE="${ROOT_DIR}/build/web/_redirects"
REQUIRED_REDIRECT='/*  /index.html  200'

echo "[Netlify] Vérification du fichier _redirects..."
if [[ -f "$REDIRECTS_FILE" ]]; then
  if ! grep -Fxq "$REQUIRED_REDIRECT" "$REDIRECTS_FILE"; then
    echo "$REQUIRED_REDIRECT" >> "$REDIRECTS_FILE"
  fi
else
  mkdir -p "$(dirname "$REDIRECTS_FILE")"
  echo "$REQUIRED_REDIRECT" > "$REDIRECTS_FILE"
fi

echo "[Netlify] Build Flutter Web terminé."
