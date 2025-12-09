# Enode API (version 2024-10-01)

Ce fichier fournit un aperçu condensé de l'OpenAPI Enode partagé par l'utilisateur. Il sert de référence rapide côté code pour les structures principales, les champs et les endpoints clés utilisés par Plogo. Se reporter à la documentation officielle pour les détails exhaustifs.

## Généralités
- Base URL (prod) : `https://enode-api.production.enode.io`
- OAuth2 (client credentials) : `https://oauth.production.enode.io/oauth2/token`
- Les tokens générés portent l'accès à l'ensemble des endpoints. Plogo doit rester sur l'environnement sandbox (URL custom définie par nos variables d'environnement).

## Principaux endpoints (résumé)

### Users (User Management)
- `POST /users/{userId}/link` : crée une session Link UI (24h). Payload : `scopes`, `language`, `redirectUri`, etc. Réponse : `{ linkUrl, linkToken }`.
- `POST /assets/{assetId}/relink` : relancer une liaison pour un asset déjà connu.
- `GET /users/{userId}` : métadonnées utilisateur, vendors associés.
- `DELETE /users/{userId}` : supprime l'utilisateur et toutes ses données Enode.
- `DELETE /users/{userId}/authorization` : révoque les autorisations sans tout supprimer.

### Chargers
- `GET /users/{userId}/chargers` : liste paginée des bornes liées à un user.
- `GET /chargers/{chargerId}` : informations détaillées sur la borne.
- `GET /users/{userId}/chargers/{chargerId}` non listé explicitement mais accessible via `/users/{id}/chargers`.
- `POST /users/{userId}/chargers/{chargerId}/link` (implicite via Link UI).
- `POST /chargers/{chargerId}/charging` : `{"action": "START"|"STOP"}`.
- `GET /users/{userId}/chargers/{chargerId}` : charge state, capabilities, etc.
- `GET /users/{userId}/chargers` => réponse `PaginatedChargerList` (avec `chargeState`, `information.brand`, `information.model`, etc.).
- `GET /health/chargers` : statut global des vendors (READY/outage).

### Chargers : sélection côté Plogo
- `GET /users/{userId}/chargers/{chargerId}` pour récupérer une borne précise (utilisé lors du select manuel).
- `GET /users/{userId}/chargers` pour la liste. Les objets contiennent :
  ```json
  {
    "id": "...",
    "vendor": "WALLBOX",
    "information": { "brand": "Wallbox", "model": "Pulsar Max", "serialNumber": "...", "year": null },
    "chargeState": { "isPluggedIn": true, "isCharging": false, ... },
    "capabilities": { "information": { "isCapable": true }, ... },
    "scopes": ["charger:control:charging", ...]
  }
  ```
- Pflags importants : `chargeState.isPluggedIn`, `chargeState.powerDeliveryState`.

### Link Sessions
- `POST /users/{userId}/link` (Link UI) : permet de demander `vendorType`, `scopes`, `language`, `redirectUri` (80 char max). Optionnel `colorScheme`.
- `POST /assets/{assetId}/relink` : usage identique mais pour replacer un vendor per asset.
- Les `scopes` typiques : `charger:read:data`, `charger:control:charging`, `charger:read:location`.

### Structures utiles

#### ChargerInformation
```json
{
  "brand": "Wallbox",
  "model": "Pulsar Max",
  "serialNumber": "12345678",
  "year": 2023
}
```
(Côté Enode, `serialNumber` sert de fallback pour `id`.)

#### ChargerChargeState
- `powerDeliveryState` (`PLUGGED_IN:CHARGING` etc.)
- `isPluggedIn`, `isCharging`, `chargeRate`, `lastUpdated`

#### Capabilities
- `startCharging`, `stopCharging`, `setMaxCurrent`, etc. `isCapable` + `interventionIds`.

### Endpoints additionnels
- `GET /health/ready` (status global).
- `GET /integrations` : vendors actifs par asset.
- `GET /interventions` : guide pour les actions (ex : accepter des T&C).

### Webhooks principaux (extraits)
- `user:charger:discovered/updated/deleted`
- `user:vehicle:smart-charging-status-updated`
- `user:vendor-action:updated` (suivi action START/STOP, etc.)

## Notes d’implémentation Plogo
- Utiliser les endpoints sandbox fournis via `ENODE_API_URL` / `ENODE_OAUTH_URL`.
- `ENODE_SCOPES` dans Plogo = `["charger:read:data","charger:control:charging"]` (plus tard on pourra élargir si besoin).
- Les IDs renvoyés par Enode sont de type UUID/CHAINE ; ne jamais les transformer.
- `redirectUri` : Enode ne permet pas de config globale ; elle doit être fournie dans la requête POST `/users/{id}/link`.

## Fichier complet
Le JSON complet (OpenAPI 3.1) transmis par l’utilisateur permet d’automatiser la génération d’un client si nécessaire. Pour éviter la duplication, il n’est pas recopié en intégralité ici : se référer au fichier `docs/ENODE_API.json` (ci-dessous) pour l’intégralité.
