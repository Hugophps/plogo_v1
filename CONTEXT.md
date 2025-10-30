Plogo — Contexte Produit et Technique (MVP)

Objectif
- Mettre en relation des particuliers qui possèdent soit une borne de recharge, soit une voiture électrique.
- Séparer totalement l’expérience des deux profils: «Propriétaire de borne» OU «Conducteur». Un utilisateur ne peut pas être les deux.
- Permettre la réservation d’un créneau via un calendrier de disponibilité.

Cibles et Parcours
- Propriétaire de borne: publie sa borne, configure disponibilités, tarifs, contraintes, gère les réservations.
- Conducteur: recherche des bornes, consulte disponibilités, réserve, paie/valide la charge, laisse un avis.
- Authentification unique par rôle; choix du rôle au premier onboarding, non mixable ensuite.

MVP Technique
- Plateforme: Progressive Web App (PWA) ciblant le web mobile uniquement (mobile-first; desktop non prioritaire).
- Framework: Flutter (orientation future Android/iOS, mais MVP = web).
- Backend/BaaS: Supabase pour authent, base de données, stockage, et RPC si nécessaire.
- Réservation: calendrier de disponibilités (lecture/écriture), logique de conflits simple, fuseaux horaires pris en compte.
- Internationalisation: 100% en français dans l’UI et les messages.

Design & Direction Artistique
- Style: moderne, rond, rassurant, simple, clair, propre.
- Ton verbal: didactique, comique, simple.
- Valeurs de marque: fiable; simple/clair/transparent; local; accessible/disponible; friendly/chaleureux.
- Couleurs clés (selon «Direction Artistique Plogo»):
  - Bleu primaire: #2C75FF
  - Jaune d’accent: #FFB347
  - Bleu secondaire: #3B5AFF
- Fond: blanc; texte: noir; accents UI en bleu/jaune.
- Icônes: utiliser une seule collection cohérente avec un large choix (ex. Material Symbols Outlined), consistante partout.

Contraintes & Bonnes Pratiques
- Mobile-first strict: maquettes/pages optimisées téléphone; pas d’effort desktop spécifique pour le MVP.
- Pas de secrets en dur: utiliser `--dart-define`/fichiers d’environnement ou équivalent IDE.
- Architecture claire et minimaliste; composants réutilisables; styles/thèmes centralisés.
- Accessibilité: tailles cibles confortables, contrastes suffisants, labels explicites.
- Traductions/messages: toujours en français (même si sources externes sont en anglais).

Supabase (pistes de schéma MVP — à affiner au fil des features)
- `profiles` (id, role: 'owner'|'driver', prénom/nom, téléphone, etc.).
- `stations` (owner_id, adresse, geo, puissance, prix, description, actifs).
- `availabilities` (station_id, start_at, end_at, règle récurrente optionnelle).
- `bookings` (station_id, driver_id, start_at, end_at, status: pending|confirmed|canceled|completed).
- Politiques RLS: isolation stricte par rôle; propriétaires sur leurs ressources; conducteurs sur leurs réservations.

Fonctionnalités Initiales à Prioriser
- Onboarding + choix de rôle (unique et définitif pour le compte).
- Auth Supabase (email/magic link ou OTP) côté web.
- Tableau de bord par rôle (owner vs driver) avec CTA principaux.
- Création d’une station (owner) et définition des disponibilités basiques.
- Recherche/consultation des stations (driver) + réservation d’un créneau libre.

Non-Objectifs (MVP)
- Applications natives publiées (Android/iOS) — envisagées plus tard.
- Paiement en ligne complet, notation/reviews avancées, tarification dynamique.

Références d’implémentation
- Flutter: Material 3, thème custom aux couleurs Plogo, responsive breakpoints mobiles.
- PWA: manifeste web + service worker via `flutter build web` (contrôle du cache à valider).
- Données: Supabase client officiel Dart; gestion de session côté web; appels typés et sécurisés.

Rappel
- Toujours vérifier et respecter ce fichier lors de toute action de conception ou de développement.
