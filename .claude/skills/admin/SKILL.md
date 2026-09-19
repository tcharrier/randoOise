---
name: admin
description: Compile l'app admin web Rando Oise (apps/rando_admin) et la déploie sur Firebase Hosting (cible "admin", projet rando-oise-a4efa). Utiliser quand l'utilisateur demande de déployer, publier ou mettre en ligne l'admin, ou tape /admin.
---

# /admin — déployer le site d'administration

Arguments optionnels : `$ARGUMENTS`
- `rules` → déploie aussi les règles Firestore (`firebase deploy --only hosting:admin,firestore:rules`).
- `preview` → déploie sur un canal de prévisualisation temporaire (`firebase hosting:channel:deploy preview --expires 7d`) au lieu de la production.
- `no-build` → saute la compilation et redéploie `apps/rando_admin/build/web` existant.

## Étapes

1. Vérifier que la CLI Firebase est connectée (`firebase projects:list` doit lister `rando-oise-a4efa`). Sinon, s'arrêter et demander `firebase login` (interactif, l'utilisateur doit le lancer lui-même).
2. Sauf `no-build`, dans `apps/rando_admin` :
   ```bash
   flutter analyze
   flutter build web --release
   ```
   Corriger toute erreur d'analyse ou de compilation avant de continuer. Ne jamais déployer un build qui date d'une version antérieure du code sans le dire.
3. Depuis la racine du dépôt (`/c/projects/randoOise`, où se trouvent `firebase.json` et `.firebaserc`) :
   ```bash
   firebase deploy --only hosting:admin --project rando-oise-a4efa
   ```
   (adapter selon `rules` / `preview`). Timeout 5 minutes.
4. Récupérer l'URL affichée par la CLI (production : `https://rando-oise-a4efa.web.app`) et vérifier qu'elle répond : `curl -s -o /dev/null -w "%{http_code}" <url>` doit renvoyer `200`.

## Rapport final

URL déployée, version du code déployé (dernier commit ou état du working tree), ce qui a été déployé (hosting seul, ou hosting + règles), et rappeler que la connexion exige un compte présent dans la collection Firestore `admins` (`node tools/create_admin.js <email> <mot de passe>`).
