---
name: aab
description: Construit l'Android App Bundle (.aab) signé de l'app utilisateur Rando Oise pour publication sur Google Play. Utiliser quand l'utilisateur demande un bundle, une build Play Store, ou tape /aab.
---

# /aab — bundle Google Play de l'app utilisateur

Arguments optionnels : `$ARGUMENTS`
- `bump` → incrémente le numéro de build (`+N`) dans `apps/rando_user/pubspec.yaml`. Google Play exige un `versionCode` strictement croissant à chaque envoi : proposer `bump` si la version n'a pas changé depuis le dernier bundle présent dans `dist/`.
- Tout autre texte est passé à `flutter build appbundle`.

## Pré-requis : clé d'upload

Le bundle DOIT être signé avec la clé d'upload, sinon Google Play le refuse. `apps/rando_user/android/app/build.gradle.kts` lit `apps/rando_user/android/key.properties` (ignoré par git).

1. Si `android/key.properties` est absent, s'arrêter et expliquer comment le créer (ne pas générer de keystore ni de mot de passe à la place de l'utilisateur) :
   ```bash
   # depuis apps/rando_user/android
   mkdir -p keystore
   keytool -genkey -v -keystore keystore/rando-oise-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   puis `android/key.properties` :
   ```
   storeFile=keystore/rando-oise-upload.jks
   storePassword=...
   keyAlias=upload
   keyPassword=...
   ```
   Rappeler : sauvegarder le `.jks` hors du dépôt ; sa perte empêche toute mise à jour de l'app.
2. Si le fichier existe, vérifier que le `storeFile` référencé existe bien.

## Étapes

1. Se placer dans `apps/rando_user`.
2. Appliquer `bump` si demandé (ligne `version:` de `pubspec.yaml`, format `x.y.z+N`).
3. Lancer (timeout 10 minutes, en arrière-plan si nécessaire) :
   ```bash
   flutter build appbundle --release [arguments]
   ```
4. Vérifier la signature du bundle produit (`build/app/outputs/bundle/release/app-release.aab`) : `jarsigner -verify` si disponible, sinon signaler que la vérification n'a pas pu être faite.
5. Copier le bundle dans `dist/rando-oise-<version>.aab`.

## Rapport final

Version et `versionCode`, chemin dans `dist/`, taille, confirmation de la signature, et la marche à suivre : Play Console → Rando Oise → Production ou Test interne → Créer une release → déposer le `.aab`.
