Ce document guide les agents et contributeurs travaillant sur ce dépôt.

Portée
- S’applique à tout le dépôt.

Principes obligatoires
- Toujours lire et respecter `CONTEXT.md` avant d’écrire du code ou des docs.
- L’application est une PWA Flutter orientée web mobile (mobile‑first). Le desktop n’est pas prioritaire pour le MVP.
- UI 100% en français. Éviter tout libellé anglais; traduire systématiquement.
- Respecter la Direction Artistique Plogo: fond blanc, texte noir, accents bleu #2C75FF et jaune #FFB347 (bleu secondaire #3B5AFF). Une seule famille d’icônes cohérente dans tout le projet.
- Backend: Supabase (auth, base de données, stockage). Aucun secret en dur; utiliser `--dart-define`/config IDE.

Style et structure de code
- Composants Flutter réutilisables; thème et styles centralisés.
- Accessibilité: contrastes, tailles, labels explicites.
- Nommez clairement les pages par rôle: `owner_*` vs `driver_*`.

Vérifications rapides avant PR
- Textes en français uniquement.
- Responsive mobile ok (petites largeurs).
- Pas de secrets en dur.
- Références aux couleurs et icônes conformes à `CONTEXT.md`.
