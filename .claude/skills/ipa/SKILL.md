---
name: ipa
description: Construit l'archive iOS (.ipa) de l'app utilisateur Rando Oise pour l'App Store / TestFlight. Utiliser quand l'utilisateur demande une build iOS, un IPA, TestFlight, ou tape /ipa.
---

# /ipa — build App Store de l'app utilisateur

Arguments optionnels : `$ARGUMENTS`
- `bump` → incrémente le numéro de build (`+N`) dans `apps/rando_user/pubspec.yaml` (App Store Connect exige un build number croissant).
- `export=<méthode>` → méthode d'export : `app-store` (défaut), `ad-hoc`, `development`.
- Tout autre texte est passé à `flutter build ipa`.

## Pré-requis (vérifier dans cet ordre, s'arrêter au premier manquant)

1. **macOS obligatoire.** Vérifier l'OS (`uname -s` doit renvoyer `Darwin`). Sur Windows ou Linux, s'arrêter et expliquer : la compilation iOS exige Xcode ; alternatives = un Mac, ou un service CI macOS (Codemagic, GitHub Actions `macos-latest`) qui exécute les mêmes commandes.
2. Xcode installé et acceptée (`xcodebuild -version`), CocoaPods installé (`pod --version`).
3. Firebase iOS : `apps/rando_user/ios/Runner/GoogleService-Info.plist` présent (généré par `flutterfire configure`, ignoré par git). S'il manque, le régénérer :
   ```bash
   cd apps/rando_user && dart pub global run flutterfire_cli:flutterfire configure --project=rando-oise-a4efa --platforms=ios --yes --ios-bundle-id=fr.randooise.randoUser
   ```
4. Signature : ouvrir `ios/Runner.xcworkspace` une première fois pour définir l'équipe Apple Developer (Signing & Capabilities → Team) avec signature automatique. Le bundle id est `fr.randooise.randoUser`. Si aucune équipe n'est configurée (`grep DEVELOPMENT_TEAM ios/Runner.xcodeproj/project.pbxproj` vide), s'arrêter et le demander.

## Étapes

1. Se placer dans `apps/rando_user`, appliquer `bump` si demandé.
2. Installer les pods si nécessaire : `cd ios && pod install && cd ..`.
3. Lancer (timeout 10 minutes, en arrière-plan si nécessaire) :
   ```bash
   flutter build ipa --release --export-method <méthode> [arguments]
   ```
   Sortie : `build/ios/ipa/rando_user.ipa` et l'archive `build/ios/archive/Runner.xcarchive`.
4. Copier l'IPA dans `dist/rando-oise-<version>.ipa`.

## Rapport final

Version et build number, chemin dans `dist/`, taille, méthode d'export, et comment envoyer : `xcrun altool --upload-app -f dist/<fichier>.ipa -t ios --apiKey ... --apiIssuer ...`, ou l'app Transporter, ou Xcode → Organizer → Distribute App. Rappeler que la clé `NSLocationWhenInUseUsageDescription` est déjà renseignée dans `Info.plist`.
