#!/usr/bin/env node
// Creates (or updates) an admin account for the admin web app.
//
//   node tools/create_admin.js admin admin [--key secret/sa.json]
//
// Identifier without '@' -> <identifiant>@rando-oise.app ; password shorter
// than 6 chars is padded with '#' (admin -> admin#). Same mapping as
// adminCredentials() in apps/rando_admin/lib/session.dart.
// Requires Firebase Authentication (Email/Password) to be enabled in the
// Firebase console. The user is created in Firebase Auth and an
// admins/{uid} document is written; the Firestore rules grant admin rights to
// any uid present in that collection.
'use strict';

const fs = require('fs');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

const args = process.argv.slice(2);
const positional = args.filter((a, i) => !a.startsWith('--') && args[i - 1] !== '--key');
const [identifiant, motDePasse] = positional;
const email = identifiant && (identifiant.includes('@') ? identifiant.trim() : `${identifiant.trim()}@rando-oise.app`);
const password = motDePasse && (motDePasse.length < 6 ? motDePasse.padEnd(6, '#') : motDePasse);
const keyIdx = args.indexOf('--key');
if (!identifiant || !motDePasse) {
  console.error('Usage: node tools/create_admin.js <identifiant> <motdepasse> [--key sa.json]');
  process.exit(1);
}

function findKey(explicit) {
  if (explicit) return path.resolve(explicit);
  const dir = path.resolve(__dirname, '..', 'secret');
  const files = fs.existsSync(dir) ? fs.readdirSync(dir).filter((f) => f.endsWith('.json')) : [];
  if (files.length !== 1) throw new Error(`Passez --key <fichier.json> (${files.length} clé(s) dans ${dir}).`);
  return path.join(dir, files[0]);
}

(async () => {
  initializeApp({ credential: cert(require(findKey(keyIdx >= 0 ? args[keyIdx + 1] : null))) });
  let user;
  try {
    user = await getAuth().getUserByEmail(email);
    await getAuth().updateUser(user.uid, { password });
    console.log(`Utilisateur existant, mot de passe mis à jour : ${user.uid}`);
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
    user = await getAuth().createUser({ email, password, emailVerified: true });
    console.log(`Utilisateur créé : ${user.uid}`);
  }
  await getFirestore().collection('admins').doc(user.uid).set({
    email,
    role: 'admin',
    createdAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  console.log(`admins/${user.uid} écrit. Connexion possible sur l'app admin avec ${email}.`);
})().catch((e) => {
  const code = String((e && (e.code || (e.errorInfo && e.errorInfo.code))) || '');
  if (code.includes('configuration-not-found') || code.includes('operation-not-allowed') ||
      String(e && e.message).includes('CONFIGURATION_NOT_FOUND')) {
    console.error('Authentification Firebase non activée : dans la console Firebase, Authentication → Commencer, puis activer “E‑mail/mot de passe” et “Anonyme”.');
    process.exit(2);
  }
  console.error(e);
  process.exit(1);
});
