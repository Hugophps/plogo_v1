# Plogo — Contexte Produit et Technique (MVP)

## Objectif
Mettre en relation des particuliers qui possèdent soit une borne de recharge, soit une voiture électrique.

### Règles principales
- Séparation stricte des rôles : un utilisateur est soit "Propriétaire de borne", soit "Conducteur" (jamais les deux).
- Réservation possible via un calendrier de disponibilités.

## Cibles et Parcours
Propriétaire de borne : publie sa borne, configure disponibilités, tarifs, contraintes, gère les réservations.  
Conducteur : recherche des bornes, consulte les disponibilités, réserve, paie/valide la charge, laisse un avis.  
Authentification unique par rôle, choisie à l’onboarding, non modifiable ensuite.

## MVP Technique
- Plateforme : Progressive Web App (PWA), web mobile uniquement.
- Framework : Flutter (Android/iOS envisagés plus tard, MVP = web).
- Backend : Supabase (authentification, base de données, stockage, RPC).
- Réservation : calendrier de disponibilités avec gestion simple des conflits et fuseaux horaires.
- Langue : 100 % français (UI, messages, labels).

## Design & Direction Artistique
- Style : moderne, simple, clair, rassurant.
- Ton : didactique, accessible, léger.
- Valeurs : fiabilité, clarté, proximité, accessibilité, convivialité.
- Couleurs :  
  - Bleu primaire : #2C75FF  
  - Jaune d’accent : #FFB347  
  - Bleu secondaire : #3B5AFF  
- Fond : blanc ; texte : noir ; accents : bleu/jaune.
- Icônes : collection unique cohérente (ex : Material Symbols Outlined).

## Bonnes pratiques et contraintes
- Mobile-first strict : aucune optimisation desktop prioritaire.
- Pas de secrets en dur : utiliser `--dart-define` ou des fichiers d’environnement.
- Architecture claire et modulaire : composants réutilisables, thèmes centralisés.
- Accessibilité : tailles confortables, contrastes suffisants, labels explicites.
- Langue : tout en français, même si les sources sont en anglais.

## Fonctionnalités à prioriser
- Onboarding + choix de rôle unique.
- Authentification Supabase (email, magic link ou OTP).
- Tableau de bord par rôle (owner vs driver).
- Création d’une station et gestion des disponibilités (owner).
- Recherche et réservation de stations (driver).

## Non-objectifs (MVP)
- Publication sur stores Android/iOS.
- Paiement complet, avis avancés, tarification dynamique.

## Références d’implémentation
- Flutter : Material 3 + thème custom Plogo.
- PWA : manifeste web + service worker via `flutter build web`.
- Données : Supabase client Dart, gestion sécurisée de session côté web.

## Règles spécifiques pour les agents IA (VS Code, Codex, Lovable, etc.)
1. Ne pas scanner l’ensemble du projet sans raison.  
   Limiter toute analyse aux fichiers directement liés à la demande de modification.  
   Ne pas parcourir les dossiers non concernés (`/build`, `/lib`, `/node_modules`, `/assets`, etc.) sans instruction explicite.

2. Ne pas utiliser de tokens pour défaire un changement.  
   Si une modification ne fonctionne pas, utiliser le bouton "Undo" de VS Code (Ctrl+Z / Cmd+Z) au lieu de tenter un rollback par prompts.

3. Privilégier la précision à la réécriture.  
   Ne pas réécrire un fichier complet si un ajustement local suffit.  
   Ne pas reformater ou restructurer le code sans instruction explicite.

4. Respecter ce document comme référence produit et technique.  
   Avant toute action, vérifier la cohérence avec ce fichier.  
   Ce contexte prévaut sur tout autre commentaire ou hypothèse.

## Rappel
Ce fichier définit le cadre du MVP Plogo et doit être respecté pour toute action de conception, de développement ou de refactorisation.