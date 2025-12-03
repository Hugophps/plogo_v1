# Plogo (MVP)

PWA Flutter (web) pour mettre en relation propriétaires de bornes et conducteurs de voitures électriques.

Important: toujours lire et respecter `CONTEXT.md` avant toute modification. L’app est mobile‑first, 100% en français, et utilise Supabase (auth + données).

## Démarrer

1) Installer Flutter stable et configurer le canal web: `flutter config --enable-web`.
2) Renseigner les secrets via `--dart-define` ou configuration IDE (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_MAPS_API_KEY` pour la carte web; aucun secret dans le code). La fonction Supabase `google-places` attend la clé `GOOGLE_PLACES_API_KEY` dans `supabase/.env` ou via `supabase secrets`.
3) Lancer en mode web: `flutter run -d chrome`.

## Lignes directrices clés

- Rôles exclusifs: «Propriétaire de borne» OU «Conducteur».
- UI conforme à la DA Plogo (bleu #2C75FF, jaune #FFB347, bleu secondaire #3B5AFF; fond blanc, texte noir).
- Icônes cohérentes (ex. Material Symbols Outlined) et textes en français.
- Voir `CONTEXT.md` pour objectifs, priorités MVP, et schéma Supabase suggéré.

## Déploiement Netlify

Chaque `git push` sur la branche connectée déclenche un build Netlify qui exécute automatiquement `bash netlify_build.sh` pour installer Flutter, lancer `flutter build web --release` et publier le contenu généré dans `build/web`. Pour déployer, il suffit de coder, `git add && git commit && git push`, attendre la fin du build Netlify puis actualiser l’URL du site : aucune autre action manuelle n’est requise.
