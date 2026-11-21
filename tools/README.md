# Outils (`tools/`)

Scripts Node (Firebase Admin SDK) pour administrer le projet `rando-oise-a4efa`.
Installer les dépendances une fois : `cd tools && npm install`.

| Script | Rôle |
| --- | --- |
| `create_admin.js` | Crée ou met à jour un compte administrateur (Auth + document `admins/{uid}`). |
| `import_source.js` | Importe une source d'itinéraires dans Firestore. |
| `import_cyclo.js` | Importe le jeu de données cyclo (plan ARC). |
| `test_e2e.js` | Tests de bout en bout des règles de sécurité Firestore (voir ci-dessous). |

## Tests de bout en bout

`test_e2e.js` rejoue le parcours réel des utilisateurs contre les **règles de
sécurité** (`firestore.rules`) : connexion anonyme via l'API REST Identity
Toolkit, lectures/écritures Firestore via l'API REST avec le jeton d'identité
(les règles s'appliquent donc exactement comme pour l'app), et SDK Admin
uniquement pour la mise en place privilégiée (`admins/{uid}`) et le nettoyage.

Sept scénarios, chaque vérification affiche `OK` ou `KO` avec sa raison :

1. un anonyme A crée un signalement valide (`votes == 1`, `voters == [A]`) ;
2. créations invalides refusées (mauvais `auteurId`, statut non initial, `votes != 1`, champ hors liste
   comme `email`, sans connexion) ;
3. un anonyme B lit la liste publique et fait **+1** avec la forme exacte de l'app
   (`FieldValue.increment(1)` + `arrayUnion`, envoyée comme `updateTransforms`) ;
4. limites : second +1 de B, +1 de A sur son propre signalement, modification de
   `description`/`statut` et suppression par B → tous refusés ;
5. admin (e-mail/mot de passe + document `admins/{uid}`) : passage à `valide`,
   suppression, relecture 404 ; sans le document `admins/{uid}` le compte est refusé ;
6. éléments remarquables : création `en_attente` seulement (et sans champ hors liste), validation et suppression par l'admin ;
7. anonymat : le document ne porte que `auteurId` (ni e-mail, ni nom) et le compte anonyme n'a aucun e-mail.

Codes de sortie : `0` tout OK, `1` au moins un KO, `2` Firebase Authentication
non activée sur le projet (mode `--live`).

### Mode émulateurs (par défaut)

Les émulateurs Auth + Firestore chargent le vrai `firestore.rules`
(ports 9099 / 8080 déclarés dans `firebase.json`) ; rien n'est écrit dans le
projet réel.

```sh
# depuis tools/
npm run test:e2e
# ou, depuis la racine du dépôt
firebase emulators:exec --only auth,firestore --project rando-oise-a4efa "node tools/test_e2e.js"
```

Le script lit `FIREBASE_AUTH_EMULATOR_HOST` et `FIRESTORE_EMULATOR_HOST`
(injectés par `emulators:exec`, sinon `127.0.0.1:9099` / `127.0.0.1:8080`).

**Java est requis** par l'émulateur Firestore (JDK 11 ou plus). Si `java`
n'est pas dans le `PATH`, le runtime embarqué d'Android Studio convient :

```sh
# Git Bash
export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"
export PATH="/c/Program Files/Android/Android Studio/jbr/bin:$PATH"
npm run test:e2e
```

```powershell
# PowerShell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
npm run test:e2e
```

Le premier lancement télécharge le jar de l'émulateur Firestore (~60 Mo) dans
`~/.cache/firebase/emulators`.

### Mode projet réel (`--live`)

```sh
npm run test:e2e:live          # ou : node tools/test_e2e.js --live
```

Mêmes scénarios contre le projet `rando-oise-a4efa` : connexion anonyme avec la
clé API web lue dans `apps/rando_admin/lib/firebase_options.dart`, Firestore
via `firestore.googleapis.com`, SDK Admin avec la clé de service unique de
`secret/*.json`. Tous les documents et comptes créés sont préfixés `test-` et
supprimés en fin d'exécution (y compris en cas d'échec, au mieux).

Prérequis : Firebase Authentication activée dans la console (Authentication →
Commencer → fournisseurs **Anonyme** et **E-mail/mot de passe**). Tant que ce
n'est pas fait, le script s'arrête avec le code `2` et le message
« Firebase Authentication n'est pas activée ».
