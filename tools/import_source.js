#!/usr/bin/env node
// Imports a hiking source (zip or json) into Firestore using the admin SDK.
//
//   node tools/import_source.js "data/itinerairerandonnee_CC_des_Lisières_de_l'Oise.zip"
//   node tools/import_source.js path/to/file.json --key secret/xxx.json --dry-run
//
// The service-account key defaults to the single *.json file found in ./secret.
'use strict';

const fs = require('fs');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { parseFile } = require('./lib/parse_source');

function findKey(explicit) {
  if (explicit) return path.resolve(explicit);
  const dir = path.resolve(__dirname, '..', 'secret');
  const files = fs.existsSync(dir) ? fs.readdirSync(dir).filter((f) => f.endsWith('.json')) : [];
  if (files.length !== 1) {
    throw new Error(`Clé de service introuvable : passez --key <fichier.json> (${files.length} fichier(s) dans ${dir}).`);
  }
  return path.join(dir, files[0]);
}

async function main() {
  const args = process.argv.slice(2);
  const file = args.find((a) => !a.startsWith('--'));
  const keyIdx = args.indexOf('--key');
  const dryRun = args.includes('--dry-run');
  if (!file) {
    console.error('Usage: node tools/import_source.js <fichier.zip|json> [--key sa.json] [--dry-run]');
    process.exit(1);
  }

  const result = parseFile(path.resolve(file));
  console.log(`Source  : ${result.source.doc.name} (${result.source.id})`);
  console.log(`Routes  : ${result.itineraires.length}`);
  for (const it of result.itineraires) {
    const d = it.doc;
    console.log(`  - ${d.nom} | ${(d.longueurM / 1000).toFixed(1)} km | ${d.difficulte ?? '?'} | ${d.pointCount} pts, ${d.tracks.length} tronçon(s) | départ ${d.start.latitude.toFixed(5)},${d.start.longitude.toFixed(5)}`);
  }
  for (const w of result.warnings) console.warn(`  ! ${w}`);
  if (dryRun) return;

  const key = findKey(keyIdx >= 0 ? args[keyIdx + 1] : null);
  initializeApp({ credential: cert(require(key)) });
  const db = getFirestore();
  const now = FieldValue.serverTimestamp();

  const existing = await db.collection('itineraires').where('sourceId', '==', result.source.id).get();
  const newIds = new Set(result.itineraires.map((i) => i.id));
  const stale = existing.docs.filter((d) => !newIds.has(d.id));

  let batch = db.batch();
  let count = 0;
  const flush = async () => { await batch.commit(); batch = db.batch(); count = 0; };
  const add = async (fn) => { fn(batch); if (++count >= 400) await flush(); };

  await add((b) => b.set(db.collection('sources').doc(result.source.id), { ...result.source.doc, importedAt: now }));
  for (const it of result.itineraires) {
    await add((b) => b.set(db.collection('itineraires').doc(it.id), { ...it.doc, updatedAt: now }));
  }
  for (const d of stale) await add((b) => b.delete(d.ref));
  if (count) await flush();

  console.log(`OK : ${result.itineraires.length} itinéraire(s) écrits, ${stale.length} supprimé(s).`);
}

main().catch((e) => { console.error(e); process.exit(1); });
