# Plogo (MVP)

PWA Flutter (web) pour mettre en relation propriétaires de bornes et conducteurs de voitures électriques.

Important: toujours lire et respecter `CONTEXT.md` avant toute modification. L’app est mobile‑first, 100% en français, et utilise Supabase (auth + données).

## Démarrer

1) Installer Flutter stable et configurer le canal web: `flutter config --enable-web`.
2) Renseigner les secrets via `--dart-define` ou configuration IDE (pas de secrets dans le code).
3) Lancer en mode web: `flutter run -d chrome`.

## Lignes directrices clés

- Rôles exclusifs: «Propriétaire de borne» OU «Conducteur».
- UI conforme à la DA Plogo (bleu #2C75FF, jaune #FFB347, bleu secondaire #3B5AFF; fond blanc, texte noir).
- Icônes cohérentes (ex. Material Symbols Outlined) et textes en français.
- Voir `CONTEXT.md` pour objectifs, priorités MVP, et schéma Supabase suggéré.
