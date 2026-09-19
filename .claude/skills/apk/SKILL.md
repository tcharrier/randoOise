---
name: apk
description: Construit l'APK Android (release) de l'app utilisateur Rando Oise, dans apps/rando_user. Utiliser quand l'utilisateur demande un APK, une build Android à installer directement, ou tape /apk.
---

# /apk — APK release de l'app utilisateur

Arguments optionnels : `$ARGUMENTS`
- `split` → un APK par architecture (`--split-per-abi`), plus léger à installer.
- `bump` → incrémente le numéro de build (`+N`) dans `apps/rando_user/pubspec.yaml` avant de compiler.
- Tout autre texte est passé tel quel à `flutter build apk` (ex. `--build-name=1.2.0 --build-number=7`).

## Étapes

1. Se placer dans `apps/rando_user` (chemins Git Bash : `/c/projects/randoOise/apps/rando_user`).
2. Si `bump` est demandé : lire la ligne `version:` de `pubspec.yaml` (format `x.y.z+N`), remplacer `N` par `N+1`, et annoncer la nouvelle version.
3. Vérifier la signature : si `android/key.properties` existe, l'APK sera signé avec la clé de release ; sinon il sera signé avec la clé debug (installable, mais pas publiable). Le dire en une ligne.
4. Lancer, avec un timeout de 10 minutes et en arrière-plan si la commande dépasse 2 minutes :
   ```bash
   flutter build apk --release [--split-per-abi] [autres arguments]
   ```
5. En cas d'échec d'analyse ou de compilation, corriger la cause puis relancer. Ne pas contourner avec `--no-tree-shake-icons` ou des désactivations de lints sans expliquer pourquoi.
6. Copier le ou les APK dans `dist/` à la racine du dépôt, nommés `rando-oise-<version>.apk` (ou `rando-oise-<version>-<abi>.apk`). Créer `dist/` si besoin ; le dossier est ignoré par git.

## Rapport final

Indiquer : version compilée, chemin(s) de sortie dans `dist/`, taille, type de signature (release ou debug), et rappeler que l'APK universel s'installe sur n'importe quel Android (`adb install dist/<fichier>.apk`).
