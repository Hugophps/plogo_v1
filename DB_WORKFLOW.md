# DB Workflow (pour Codex)

- Toujours écrire des migrations **SQL** dans `supabase/migrations/`, nommées `YYYYMMDDHHMM_<description>.sql` (ex: `202510301545_profiles.sql`).
- Utiliser du SQL Postgres standard (CREATE/ALTER, FK, CHECK, TRIGGER).
- Rendre les migrations **idempotentes** (`IF NOT EXISTS`, `DROP ... IF EXISTS`, blocs `DO $$` avec gestion des doublons).
- Activer **RLS** et ajouter les **policies** nécessaires.
- Ne jamais inclure de clés API dans le code.
- Après génération, lancer la tâche VS Code **Apply Supabase migrations** (exécute `supabase db push`).
