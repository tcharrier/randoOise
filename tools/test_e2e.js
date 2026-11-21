#!/usr/bin/env node
// End-to-end tests of the Firestore security rules (signalements, elements,
// admins), played the way the mobile app and the admin site do it:
//  - anonymous accounts through the Identity Toolkit REST API,
//  - Firestore reads/writes through the Firestore REST API with the user's ID
//    token, so that firestore.rules are enforced,
//  - the Admin SDK only for privileged setup (admins/{uid}) and cleanup.
//
//   Emulators (default):
//     firebase emulators:exec --only auth,firestore --project rando-oise-a4efa \
//       "node tools/test_e2e.js"            (or, from tools/: npm run test:e2e)
//   Live project:
//     node tools/test_e2e.js --live          (or, from tools/: npm run test:e2e:live)
//
// Exit codes: 0 all OK, 1 at least one KO (or unexpected error),
//             2 Firebase Authentication not enabled on the project (--live).
'use strict';

const fs = require('fs');
const path = require('path');
const http = require('http');
const https = require('https');

const PROJECT_ID = 'rando-oise-a4efa';
const ROOT = path.resolve(__dirname, '..');
const args = process.argv.slice(2);
const LIVE = args.includes('--live');
// Every document / account created by a run carries this prefix.
const RUN_ID = `test-e2e-${Date.now().toString(36)}`;

if (args.includes('--help') || args.includes('-h')) {
  console.log('Usage : node tools/test_e2e.js [--live]');
  process.exit(0);
}

// ------------------------------------------------------------------ config

let authBase;
let fsBase;
let apiKey;
if (LIVE) {
  delete process.env.FIREBASE_AUTH_EMULATOR_HOST;
  delete process.env.FIRESTORE_EMULATOR_HOST;
  apiKey = readWebApiKey();
  authBase = 'https://identitytoolkit.googleapis.com/v1';
  fsBase = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
} else {
  process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
  process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
  // No real credentials are needed against the emulators: stop the Admin SDK
  // from probing the GCE metadata server (slow, and it logs a warning).
  process.env.METADATA_SERVER_DETECTION = process.env.METADATA_SERVER_DETECTION || 'none';
  apiKey = 'any';
  authBase = `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1`;
  fsBase = `http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
}

// firebase-admin reads the emulator variables when it is initialised: require
// it only once they are settled.
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

function readWebApiKey() {
  const f = path.join(ROOT, 'apps', 'rando_admin', 'lib', 'firebase_options.dart');
  const src = fs.readFileSync(f, 'utf8');
  const block = src.match(/static const FirebaseOptions web = FirebaseOptions\(([\s\S]*?)\);/);
  const m = (block ? block[1] : src).match(/apiKey:\s*'([^']+)'/);
  if (!m) throw new Error(`apiKey (web) introuvable dans ${f}`);
  return m[1];
}

function findServiceKey() {
  const dir = path.join(ROOT, 'secret');
  const files = fs.existsSync(dir) ? fs.readdirSync(dir).filter((f) => f.endsWith('.json')) : [];
  if (files.length !== 1) {
    throw new Error(`Un seul fichier *.json (clé de service) est attendu dans ${dir} : ${files.length} trouvé(s).`);
  }
  return path.join(dir, files[0]);
}

// -------------------------------------------------------------------- http

function httpJson(method, url, { token, body } = {}) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const lib = u.protocol === 'https:' ? https : http;
    const data = body === undefined ? null : JSON.stringify(body);
    const headers = { Accept: 'application/json' };
    if (data !== null) {
      headers['Content-Type'] = 'application/json';
      headers['Content-Length'] = Buffer.byteLength(data);
    }
    if (token) headers.Authorization = `Bearer ${token}`;
    const req = lib.request(u, { method, headers }, (res) => {
      let raw = '';
      res.setEncoding('utf8');
      res.on('data', (c) => { raw += c; });
      res.on('end', () => {
        let json = null;
        try { json = raw ? JSON.parse(raw) : null; } catch (_) { json = { raw }; }
        resolve({ status: res.statusCode, json });
      });
    });
    req.setTimeout(30000, () => req.destroy(new Error(`délai dépassé : ${method} ${url}`)));
    req.on('error', reject);
    if (data !== null) req.write(data);
    req.end();
  });
}

function errMsg(r) {
  const e = r && r.json && r.json.error;
  const m = e ? (e.message || e.status || JSON.stringify(e)) : (r && r.json ? JSON.stringify(r.json) : '');
  return String(m).replace(/\s+/g, ' ').trim();
}

// ---------------------------------------------------------- firestore REST

class GeoPoint {
  constructor(latitude, longitude) { this.latitude = latitude; this.longitude = longitude; }
}

function enc(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(enc) } };
  if (v instanceof GeoPoint) return { geoPointValue: { latitude: v.latitude, longitude: v.longitude } };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (typeof v === 'object') return { mapValue: { fields: encFields(v) } };
  throw new Error(`type non géré : ${typeof v}`);
}
function encFields(obj) {
  const out = {};
  for (const [k, v] of Object.entries(obj)) out[k] = enc(v);
  return out;
}
function dec(v) {
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('nullValue' in v) return null;
  if ('timestampValue' in v) return new Date(v.timestampValue);
  if ('geoPointValue' in v) return new GeoPoint(v.geoPointValue.latitude, v.geoPointValue.longitude);
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(dec);
  if ('mapValue' in v) return decFields(v.mapValue.fields || {});
  if ('referenceValue' in v) return v.referenceValue;
  return v;
}
function decFields(fields) {
  const out = {};
  for (const [k, v] of Object.entries(fields || {})) out[k] = dec(v);
  return out;
}

const docName = (p) => `projects/${PROJECT_ID}/databases/(default)/documents/${p}`;
const serverTime = (field) => ({ fieldPath: field, setToServerValue: 'REQUEST_TIME' });

// Equivalent of the SDK's ref.set(data) with FieldValue.serverTimestamp() on
// some fields; exists:false guarantees the rules see a "create".
function createWrite(docPath, fields, timestampFields = []) {
  const w = { update: { name: docName(docPath), fields: encFields(fields) }, currentDocument: { exists: false } };
  if (timestampFields.length) w.updateTransforms = timestampFields.map(serverTime);
  return w;
}

// Equivalent of ref.update({...}): only the masked fields change.
function updateWrite(docPath, fields, transforms = []) {
  const w = {
    update: { name: docName(docPath), fields: encFields(fields) },
    updateMask: { fieldPaths: Object.keys(fields) },
    currentDocument: { exists: true },
  };
  if (transforms.length) w.updateTransforms = transforms;
  return w;
}

// Exact REST equivalent of RandoRepository.voteSignalement:
//   update({'votes': FieldValue.increment(1), 'voters': FieldValue.arrayUnion([uid])})
function voteTransformWrite(docPath, uid) {
  return {
    update: { name: docName(docPath), fields: {} },
    updateMask: { fieldPaths: [] },
    updateTransforms: [
      { fieldPath: 'votes', increment: { integerValue: '1' } },
      { fieldPath: 'voters', appendMissingElements: { values: [{ stringValue: uid }] } },
    ],
    currentDocument: { exists: true },
  };
}

const commit = (token, writes) => httpJson('POST', `${fsBase}:commit`, { token, body: { writes } });
const deleteDoc = (token, docPath) => httpJson('DELETE', `${fsBase}/${docPath}`, { token });

async function getDoc(token, docPath) {
  const r = await httpJson('GET', `${fsBase}/${docPath}`, { token });
  return { status: r.status, data: r.status === 200 ? decFields(r.json.fields) : null, json: r.json };
}

// Same query as RandoRepository.watchSignalements(itineraireId: ...).
async function queryByItineraire(token, collection, itineraireId) {
  const r = await httpJson('POST', `${fsBase}:runQuery`, {
    token,
    body: {
      structuredQuery: {
        from: [{ collectionId: collection }],
        where: { fieldFilter: { field: { fieldPath: 'itineraireId' }, op: 'EQUAL', value: { stringValue: itineraireId } } },
      },
    },
  });
  const ids = Array.isArray(r.json)
    ? r.json.filter((e) => e.document).map((e) => e.document.name.split('/').pop())
    : [];
  return { status: r.status, ids, json: r.json };
}

// -------------------------------------------------------------------- auth

class AuthNotEnabled extends Error {}
const NOT_ENABLED = ['CONFIGURATION_NOT_FOUND', 'ADMIN_ONLY_OPERATION', 'OPERATION_NOT_ALLOWED',
  'PASSWORD_LOGIN_DISABLED', 'PROJECT_NOT_FOUND', 'auth/configuration-not-found'];
function authFailure(where, r) {
  const m = errMsg(r);
  if (NOT_ENABLED.some((k) => m.includes(k))) return new AuthNotEnabled(`${where} : ${m}`);
  return new Error(`${where} : HTTP ${r.status} ${m}`);
}

async function signUpAnonymous() {
  const r = await httpJson('POST', `${authBase}/accounts:signUp?key=${apiKey}`, { body: { returnSecureToken: true } });
  if (r.status !== 200) throw authFailure('connexion anonyme (accounts:signUp)', r);
  return { uid: r.json.localId, token: r.json.idToken };
}

async function signInPassword(email, password) {
  const r = await httpJson('POST', `${authBase}/accounts:signInWithPassword?key=${apiKey}`, {
    body: { email, password, returnSecureToken: true },
  });
  if (r.status !== 200) throw authFailure('connexion e-mail/mot de passe', r);
  return { uid: r.json.localId, token: r.json.idToken, email };
}

const lookupAccount = (token) => httpJson('POST', `${authBase}/accounts:lookup?key=${apiKey}`, { body: { idToken: token } });

// Creates (or resets) the admin account like tools/create_admin.js does.
async function createAdminAuthUser(email, password) {
  const auth = getAuth();
  try {
    try {
      const u = await auth.getUserByEmail(email);
      await auth.updateUser(u.uid, { password });
      return u.uid;
    } catch (e) {
      if (e.code !== 'auth/user-not-found') throw e;
      const u = await auth.createUser({ email, password, emailVerified: true });
      return u.uid;
    }
  } catch (e) {
    if (NOT_ENABLED.some((k) => String(e.code || e.message).includes(k))) {
      throw new AuthNotEnabled(`création du compte admin : ${e.code || e.message}`);
    }
    throw e;
  }
}

// ---------------------------------------------------------------- checks

const results = [];
function check(scn, ok, msg) {
  results.push({ scn, ok, msg });
  console.log(`[${scn}] ${ok ? 'OK' : 'KO'}  ${msg}`);
  return ok;
}
function expectAllowed(scn, label, r) {
  return check(scn, r.status === 200,
    `${label} → ${r.status === 200 ? 'accepté' : `HTTP ${r.status} ${errMsg(r)}`}`);
}
function expectDenied(scn, label, r) {
  let why;
  if (r.status === 403) why = 'refusé (PERMISSION_DENIED)';
  else if (r.status === 200) why = 'ACCEPTÉ alors que les règles devraient refuser';
  else why = `HTTP ${r.status} ${errMsg(r)} (attendu : 403)`;
  return check(scn, r.status === 403, `${label} → ${why}`);
}
const sameList = (a, b) => Array.isArray(a) && a.length === b.length && a.every((x, i) => x === b[i]);
const short = (uid) => (uid ? `${String(uid).slice(0, 6)}…` : String(uid));

// ------------------------------------------------------------- test data

const ITI_ID = `${RUN_ID}-itineraire`;

function signalementData(uid, overrides = {}) {
  return {
    itineraireId: ITI_ID,
    itineraireNom: 'Itinéraire de test (e2e)',
    sourceId: `${RUN_ID}-source`,
    categorie: 'obstacle',
    description: 'Arbre tombé en travers du chemin (test automatique)',
    position: new GeoPoint(49.4175, 2.8260),
    statut: 'signale',
    auteurId: uid,
    votes: 1,
    voters: [uid],
    ...overrides,
  };
}

function elementData(uid, overrides = {}) {
  return {
    itineraireId: ITI_ID,
    itineraireNom: 'Itinéraire de test (e2e)',
    sourceId: `${RUN_ID}-source`,
    categorie: 'panorama',
    titre: 'Point de vue de test',
    description: 'Créé par tools/test_e2e.js',
    position: new GeoPoint(49.4201, 2.8302),
    statut: 'en_attente',
    auteurId: uid,
    ...overrides,
  };
}

// -------------------------------------------------------------- scenarios

const ctx = { docs: new Set(), uids: new Set(), voteForm: null };

function track(docPath) { ctx.docs.add(docPath); return docPath; }

async function scenario1() {
  ctx.A = await signUpAnonymous();
  ctx.uids.add(ctx.A.uid);
  ctx.sigPath = track(`signalements/${RUN_ID}-sig`);
  const r = await commit(ctx.A.token, [createWrite(ctx.sigPath, signalementData(ctx.A.uid), ['createdAt', 'updatedAt'])]);
  if (!expectAllowed(1, 'A (anonyme) crée un signalement de forme valide', r)) return;
  const g = await getDoc(ctx.A.token, ctx.sigPath);
  check(1, g.status === 200, `A relit son signalement → HTTP ${g.status}`);
  if (!g.data) return;
  check(1, g.data.votes === 1 && sameList(g.data.voters, [ctx.A.uid]),
    `votes == 1 et voters == [A] (lu : votes=${g.data.votes}, voters=[${(g.data.voters || []).map(short).join(', ')}])`);
  check(1, g.data.createdAt instanceof Date && g.data.updatedAt instanceof Date,
    'createdAt / updatedAt renseignés par serverTimestamp');
}

async function scenario2() {
  const { A } = ctx;
  if (!A) return check(2, false, 'prérequis manquant (scénario 1)');
  const cases = [
    ['auteurId différent de son uid', { auteurId: 'quelqu-un-d-autre' }],
    ["statut initial autre que 'signale'", { statut: 'valide' }],
    ['votes != 1', { votes: 2 }],
    ['voters ne vaut pas [uid]', { voters: [A.uid, 'ami'] }],
    ['un champ hors liste (email) ajouté au document', { email: 'quelqu-un@example.org' }],
  ];
  let i = 0;
  for (const [label, overrides] of cases) {
    const p = track(`signalements/${RUN_ID}-bad${++i}`);
    const r = await commit(A.token, [createWrite(p, signalementData(A.uid, overrides), ['createdAt', 'updatedAt'])]);
    expectDenied(2, `création avec ${label}`, r);
  }
  const p = track(`signalements/${RUN_ID}-anon`);
  const r = await commit(null, [createWrite(p, signalementData(A.uid), ['createdAt', 'updatedAt'])]);
  expectDenied(2, 'création sans être connecté (pas de jeton)', r);
}

async function scenario3() {
  const { A, sigPath } = ctx;
  if (!A || !sigPath) return check(3, false, 'prérequis manquant (scénario 1)');
  ctx.B = await signUpAnonymous();
  ctx.uids.add(ctx.B.uid);
  const { B } = ctx;
  const sigId = sigPath.split('/').pop();

  const q = await queryByItineraire(B.token, 'signalements', ITI_ID);
  check(3, q.status === 200 && q.ids.includes(sigId),
    `B liste les signalements de l'itinéraire (lecture publique) et voit celui de A → HTTP ${q.status}, ${q.ids.length} document(s)`);

  // Transform form first: this is exactly what the app sends.
  let r = await commit(B.token, [voteTransformWrite(sigPath, B.uid)]);
  if (r.status === 200) {
    ctx.voteForm = 'transform (increment(1) + arrayUnion, identique à RandoRepository.voteSignalement)';
    check(3, true, "+1 de B avec la forme transform increment(1)+arrayUnion (celle de l'app) → accepté");
  } else {
    check(3, false, `+1 de B avec la forme transform (celle de l'app) → HTTP ${r.status} ${errMsg(r)}`);
    const cur = await getDoc(B.token, sigPath);
    const votes = (cur.data ? cur.data.votes : 1) + 1;
    const voters = [...((cur.data && cur.data.voters) || [A.uid]), B.uid];
    r = await commit(B.token, [updateWrite(sigPath, { votes, voters })]);
    ctx.voteForm = r.status === 200
      ? "explicite seulement (votes=2, voters=[A,B]) : l'app devrait être adaptée"
      : 'aucune';
    expectAllowed(3, 'repli : +1 de B en forme explicite (votes: 2, voters: [A, B], updateMask votes,voters)', r);
  }
  const g = await getDoc(B.token, sigPath);
  const d = g.data || {};
  check(3, d.votes === 2 && sameList(d.voters, [A.uid, B.uid]),
    `après le +1 : votes == 2 et voters == [A, B] (lu : votes=${d.votes}, voters=[${(d.voters || []).map(short).join(', ')}])`);
  check(3, d.statut === 'signale' && d.auteurId === A.uid && typeof d.description === 'string',
    'les autres champs (statut, auteurId, description) sont intacts après le +1');
}

async function scenario4() {
  const { A, B, sigPath } = ctx;
  if (!A || !B || !sigPath) return check(4, false, 'prérequis manquant (scénarios 1 et 3)');
  expectDenied(4, 'B fait +1 une seconde fois', await commit(B.token, [voteTransformWrite(sigPath, B.uid)]));
  expectDenied(4, 'A fait +1 sur son propre signalement (déjà dans voters)', await commit(A.token, [voteTransformWrite(sigPath, A.uid)]));
  expectDenied(4, 'B modifie la description', await commit(B.token, [updateWrite(sigPath, { description: 'modifié par B' })]));
  expectDenied(4, "B passe le statut à 'valide'", await commit(B.token, [updateWrite(sigPath, { statut: 'valide' })]));
  const mixed = {
    ...voteTransformWrite(sigPath, B.uid),
    update: { name: docName(sigPath), fields: encFields({ description: 'x' }) },
    updateMask: { fieldPaths: ['description'] },
  };
  expectDenied(4, 'B fait +1 et change la description dans la même écriture', await commit(B.token, [mixed]));
  expectDenied(4, 'B supprime le signalement', await deleteDoc(B.token, sigPath));
}

async function scenario5() {
  const { B, sigPath } = ctx;
  if (!B || !sigPath) return check(5, false, 'prérequis manquant (scénarios 1 et 3)');
  const email = LIVE ? `${RUN_ID}@rando-oise.app` : 'admin@rando-oise.app';
  const password = LIVE ? `Test-${Math.random().toString(36).slice(2)}!` : 'admin#';
  const adminUid = await createAdminAuthUser(email, password);
  ctx.uids.add(adminUid);
  ctx.admin = await signInPassword(email, password);
  check(5, ctx.admin.uid === adminUid, `connexion e-mail/mot de passe de l'admin (${email})`);
  const { admin } = ctx;

  // Same write as RandoRepository.setSignalementStatut(valide).
  const statutWrite = (p) => updateWrite(p, { statut: 'valide', validePar: admin.uid }, [serverTime('updatedAt'), serverTime('valideAt')]);

  // Without the admins/{uid} document the e-mail account is a plain user.
  expectDenied(5, "compte e-mail SANS document admins/{uid} : passage à 'valide'", await commit(admin.token, [statutWrite(sigPath)]));

  await getFirestore().collection('admins').doc(admin.uid)
    .set({ email, role: 'admin', createdAt: FieldValue.serverTimestamp() }, { merge: true });
  track(`admins/${admin.uid}`);
  check(5, (await getDoc(admin.token, `admins/${admin.uid}`)).status === 200, "l'admin lit son propre document admins/{uid}");
  expectDenied(5, "B lit admins/{uid de l'admin} (liste des admins non publique)", await getDoc(B.token, `admins/${admin.uid}`));

  expectAllowed(5, "admin : statut → 'valide' (+ validePar, valideAt, updatedAt)", await commit(admin.token, [statutWrite(sigPath)]));
  const g = await getDoc(B.token, sigPath);
  check(5, !!g.data && g.data.statut === 'valide' && g.data.validePar === admin.uid,
    `B relit : statut == 'valide' (lu : ${g.data && g.data.statut})`);
  expectAllowed(5, 'admin : suppression du signalement', await deleteDoc(admin.token, sigPath));
  const after = await getDoc(B.token, sigPath);
  check(5, after.status === 404, `B relit le signalement supprimé → HTTP ${after.status} (attendu : 404)`);
}

async function scenario6() {
  const { A, B, admin } = ctx;
  if (!A || !B || !admin) return check(6, false, 'prérequis manquant (scénarios 1, 3 et 5)');
  const elPath = track(`elements/${RUN_ID}-el`);
  expectAllowed(6, "A crée un élément remarquable avec statut 'en_attente'",
    await commit(A.token, [createWrite(elPath, elementData(A.uid), ['createdAt'])]));
  expectDenied(6, "A crée un élément directement 'valide'",
    await commit(A.token, [createWrite(track(`elements/${RUN_ID}-el-bad`), elementData(A.uid, { statut: 'valide' }), ['createdAt'])]));
  expectDenied(6, 'A crée un élément avec un champ hors liste (displayName)',
    await commit(A.token, [createWrite(track(`elements/${RUN_ID}-el-bad2`), elementData(A.uid, { displayName: 'Thomas' }), ['createdAt'])]));
  expectDenied(6, "B passe l'élément à 'valide'", await commit(B.token, [updateWrite(elPath, { statut: 'valide' })]));
  expectDenied(6, 'A (auteur) modifie le titre de son élément', await commit(A.token, [updateWrite(elPath, { titre: 'Nouveau titre' })]));
  expectAllowed(6, "admin : statut → 'valide' (+ validePar, valideAt)",
    await commit(admin.token, [updateWrite(elPath, { statut: 'valide', validePar: admin.uid }, [serverTime('valideAt')])]));
  const g = await getDoc(B.token, elPath);
  check(6, !!g.data && g.data.statut === 'valide', `B relit l'élément validé (lu : statut=${g.data && g.data.statut})`);
  expectDenied(6, "B supprime l'élément", await deleteDoc(B.token, elPath));
  expectAllowed(6, "admin : suppression de l'élément", await deleteDoc(admin.token, elPath));
  check(6, (await getDoc(B.token, elPath)).status === 404, "B relit l'élément supprimé → 404");
}

async function scenario7() {
  const { A, B } = ctx;
  if (!A || !B) return check(7, false, 'prérequis manquant (scénarios 1 et 3)');
  const p = track(`signalements/${RUN_ID}-sig2`);
  const r = await commit(A.token, [createWrite(p, signalementData(A.uid), ['createdAt', 'updatedAt'])]);
  if (!expectAllowed(7, "A crée un second signalement (jeu de données pour le contrôle d'anonymat)", r)) return;
  const g = await getDoc(B.token, p);
  const data = g.data || {};
  const forbidden = ['email', 'name', 'nom', 'displayName'].filter((k) => k in data);
  check(7, g.status === 200 && forbidden.length === 0,
    `le document lu par B ne contient ni email, name, nom ni displayName (champs : ${Object.keys(data).sort().join(', ')})`);
  check(7, data.auteurId === A.uid && !/@/.test(data.auteurId),
    `auteurId est l'uid opaque de l'auteur (${short(data.auteurId)}), pas un e-mail`);
  const lk = await lookupAccount(A.token);
  const u = lk.json && lk.json.users && lk.json.users[0];
  const providers = (u && u.providerUserInfo) || [];
  check(7, lk.status === 200 && !!u && !u.email && providers.length === 0,
    `le compte anonyme A n'a ni e-mail ni fournisseur d'identité (accounts:lookup → email=${JSON.stringify(u && u.email)}, providers=${providers.length})`);
  const rec = await getAuth().getUser(A.uid);
  check(7, !rec.email && !rec.displayName && !rec.phoneNumber && rec.providerData.length === 0,
    'côté Admin SDK : le compte anonyme ne porte ni e-mail, ni nom, ni téléphone');
}

// ------------------------------------------------------------------- main

async function cleanup() {
  const db = getFirestore();
  let docs = 0;
  let users = 0;
  for (const p of ctx.docs) {
    try { await db.doc(p).delete(); docs++; } catch (e) { console.warn(`  nettoyage : ${p} : ${e.message}`); }
  }
  for (const uid of ctx.uids) {
    try { await getAuth().deleteUser(uid); users++; } catch (e) { console.warn(`  nettoyage : compte ${uid} : ${e.message}`); }
  }
  console.log(`Nettoyage : ${docs} document(s) et ${users} compte(s) supprimés.`);
}

async function main() {
  if (LIVE) {
    initializeApp({ credential: cert(require(findServiceKey())), projectId: PROJECT_ID });
    console.log(`Mode : projet réel ${PROJECT_ID} (documents préfixés "test-", supprimés en fin de test)`);
  } else {
    initializeApp({ projectId: PROJECT_ID });
    console.log(`Mode : émulateurs (Auth ${process.env.FIREBASE_AUTH_EMULATOR_HOST}, Firestore ${process.env.FIRESTORE_EMULATOR_HOST})`);
  }
  console.log(`Identifiant du run : ${RUN_ID}\n`);

  const scenarios = [
    [1, "Création d'un signalement par un anonyme", scenario1],
    [2, 'Créations invalides refusées', scenario2],
    [3, 'Lecture publique et +1', scenario3],
    [4, 'Limites du +1 et des modifications', scenario4],
    [5, 'Admin : validation et suppression', scenario5],
    [6, 'Éléments remarquables', scenario6],
    [7, 'Anonymat', scenario7],
  ];
  let fatal = null;
  try {
    for (const [n, title, fn] of scenarios) {
      console.log(`--- Scénario ${n} : ${title}`);
      try {
        await fn();
      } catch (e) {
        if (e instanceof AuthNotEnabled) throw e;
        check(n, false, `erreur inattendue : ${e.message}`);
        if (e.code === 'ECONNREFUSED') throw e;
      }
    }
  } catch (e) {
    fatal = e;
  } finally {
    console.log('');
    try { await cleanup(); } catch (e) { console.warn(`Nettoyage incomplet : ${e.message}`); }
  }

  if (fatal instanceof AuthNotEnabled) {
    console.error(`\n${fatal.message}`);
    console.error("Firebase Authentication n'est pas activée : Console Firebase → Authentication → Commencer → activer Anonyme et E-mail/mot de passe");
    process.exit(2);
  }
  if (fatal && fatal.code === 'ECONNREFUSED') {
    console.error(`\nÉmulateurs injoignables (${fatal.message}). Lancez les tests avec :`);
    console.error('  firebase emulators:exec --only auth,firestore --project rando-oise-a4efa "node tools/test_e2e.js"');
    process.exit(1);
  }

  const byScn = new Map();
  for (const r of results) {
    const s = byScn.get(r.scn) || { ok: 0, ko: 0 };
    s[r.ok ? 'ok' : 'ko']++;
    byScn.set(r.scn, s);
  }
  console.log('Résumé');
  for (const [n, title] of scenarios) {
    const s = byScn.get(n) || { ok: 0, ko: 0 };
    const state = s.ko ? 'KO' : (s.ok ? 'OK' : '--');
    console.log(`  ${state}  Scénario ${n} : ${title} (${s.ok}/${s.ok + s.ko})`);
  }
  if (ctx.voteForm) console.log(`  Forme du +1 acceptée par les règles : ${ctx.voteForm}`);
  const ko = results.filter((r) => !r.ok).length;
  console.log(`Résultat : ${results.length - ko} OK, ${ko} KO${fatal ? ` (erreur : ${fatal.message})` : ''}`);
  process.exit(ko || fatal ? 1 : 0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
