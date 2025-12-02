#!/usr/bin/env bash
# Script de build exécuté par Netlify pour compiler l'application Flutter Web.
# Netlify appelle `bash netlify_build.sh` depuis la racine du dépôt à chaque build.
# Il installe Flutter localement, active la cible web, récupère les dépendances
# et produit la version release dans `build/web` que Netlify publie ensuite.

set -euo pipefail

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
flutter build web --release

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
