#!/usr/bin/env node
// Mirrors the embedded ARC cycling dataset into Firestore (source "arc-velo",
// activite "velo") so the admin app can display cycling routes and the
// reports attached to them. The mobile app itself reads the dataset from its
// bundled assets and never depends on this copy.
//
// With plan_arc.json next to the dataset (the official "Plan des itinéraires
// cyclables de l'ARC"), the dataset rows are regrouped into the numbered
// itineraries of the plan (ids arc-velo-<n>, plan name and colour) and every
// other row is flagged "secondaire". Same logic as
// packages/rando_core/lib/src/data/velo_dataset.dart.
//
//   node tools/import_cyclo.js [dossier] [--key sa.json] [--dry-run]
//   (dossier par défaut : apps/rando_user/assets/velo)
'use strict';

const fs = require('fs');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue, GeoPoint } = require('firebase-admin/firestore');

const SPEED_KMH = 18;
const SOURCE_ID = 'arc-velo';
const SOURCE_NAME = 'Pistes cyclables ARC';
// ARGB, same value as VeloDataset.secondaryCouleur.
const SECONDARY_COLOUR = 0xFF000000 + 0x9A9A9A;

function findKey(explicit) {
  if (explicit) return path.resolve(explicit);
  const dir = path.resolve(__dirname, '..', 'secret');
  const files = fs.existsSync(dir) ? fs.readdirSync(dir).filter((f) => f.endsWith('.json')) : [];
  if (files.length !== 1) throw new Error(`Passez --key <fichier.json> (${files.length} clé(s) dans ${dir}).`);
  return path.join(dir, files[0]);
}

// ---- WKB (LineString / MultiLineString, optional Z) --------------------------
function parseWkb(buf, offset, length) {
  if (length < 5) return null;
  const le = buf.readUInt8(offset) === 1;
  const type = le ? buf.readUInt32LE(offset + 1) : buf.readUInt32BE(offset + 1);
  const hasZ = type >= 1000;
  const base = hasZ ? type % 1000 : type;
  let pos = offset + 5;
  const lines = [];
  const readLine = (endianLE) => {
    const n = endianLE ? buf.readUInt32LE(pos) : buf.readUInt32BE(pos);
    pos += 4;
    const line = [];
    for (let i = 0; i < n; i++) {
      const x = endianLE ? buf.readDoubleLE(pos) : buf.readDoubleBE(pos);
      const y = endianLE ? buf.readDoubleLE(pos + 8) : buf.readDoubleBE(pos + 8);
      line.push({ lat: y, lng: x });
      pos += hasZ ? 24 : 16;
    }
    if (line.length) lines.push(line);
  };
  if (base === 2) readLine(le);
  else if (base === 5) {
    const n = le ? buf.readUInt32LE(pos) : buf.readUInt32BE(pos);
    pos += 4;
    for (let i = 0; i < n; i++) {
      const innerLE = buf.readUInt8(pos) === 1;
      pos += 5;
      readLine(innerLE);
    }
  } else return null;
  return lines;
}

function mergeSegments(segs) {
  const eps = 1e-7;
  const same = (a, b) => Math.abs(a.lat - b.lat) < eps && Math.abs(a.lng - b.lng) < eps;
  const out = [];
  for (const seg of segs) {
    if (!seg.length) continue;
    if (out.length) {
      const cur = out[out.length - 1];
      if (same(cur[cur.length - 1], seg[0])) { cur.push(...seg.slice(1)); continue; }
      if (same(cur[cur.length - 1], seg[seg.length - 1])) { cur.push(...seg.slice(0, -1).reverse()); continue; }
    }
    out.push([...seg]);
  }
  let joined = true;
  while (joined && out.length > 1) {
    joined = false;
    outer: for (let i = 0; i < out.length; i++) {
      for (let j = 0; j < out.length; j++) {
        if (i === j) continue;
        const a = out[i], b = out[j];
        const aF = a[0], aL = a[a.length - 1], bF = b[0], bL = b[b.length - 1];
        if (same(aL, bF)) a.push(...b.slice(1));
        else if (same(aL, bL)) a.push(...b.slice(0, -1).reverse());
        else if (same(aF, bL)) a.unshift(...b.slice(0, -1));
        else if (same(aF, bF)) a.unshift(...b.slice(1).reverse());
        else continue;
        out.splice(j, 1);
        joined = true;
        break outer;
      }
    }
  }
  return out;
}

// ---- Overlap removal (both sides of a lane, same lane under two numbers) -----
const M_PER_DEG = 111320;
function distPtSeg(p, a, b) {
  const dx = b.x - a.x, dy = b.y - a.y;
  const len2 = dx * dx + dy * dy;
  let t = len2 > 0 ? ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2 : 0;
  t = Math.max(0, Math.min(1, t));
  return Math.hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy));
}
// Drops a line when >= minCoverage of its length lies within toleranceM of the
// lines kept before it (order matters: the main row comes first).
function dedupeLines(lines, toleranceM = 15, minCoverage = 0.8) {
  const kept = [], segs = [];
  let cosLat = null;
  for (const line of lines) {
    if (line.length < 2) continue;
    if (cosLat === null) cosLat = Math.cos((line[0].lat * Math.PI) / 180);
    const xy = (p) => ({ x: p.lng * M_PER_DEG * cosLat, y: p.lat * M_PER_DEG });
    if (segs.length) {
      let total = 0, near = 0;
      for (let i = 1; i < line.length; i++) {
        const a = xy(line[i - 1]), b = xy(line[i]);
        const n = Math.max(1, Math.ceil(Math.hypot(b.x - a.x, b.y - a.y) / 20));
        for (let k = 0; k <= n; k++) {
          if (k === n && i < line.length - 1) break; // shared with the next segment
          const p = { x: a.x + ((b.x - a.x) * k) / n, y: a.y + ((b.y - a.y) * k) / n };
          total++;
          if (segs.some((s) => distPtSeg(p, s[0], s[1]) < toleranceM)) near++;
        }
      }
      if (total > 0 && near / total >= minCoverage) continue;
    }
    kept.push(line);
    for (let i = 1; i < line.length; i++) segs.push([xy(line[i - 1]), xy(line[i])]);
  }
  return kept;
}

const R = 6371000;
function haversine(a, b) {
  const rad = (d) => (d * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat), dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(h)));
}
const bounds = (pts) => pts.reduce((b, p) => ({
  minLat: Math.min(b.minLat, p.lat), minLng: Math.min(b.minLng, p.lng),
  maxLat: Math.max(b.maxLat, p.lat), maxLng: Math.max(b.maxLng, p.lng) }),
  { minLat: Infinity, minLng: Infinity, maxLat: -Infinity, maxLng: -Infinity });
const encodeTracks = (tracks) => tracks.map((l) => l.map((p) => `${p.lat.toFixed(6)},${p.lng.toFixed(6)}`).join(';'));
const str = (v) => (v === null || v === undefined || String(v).trim() === '' ? null : String(v).trim());
const geomLength = (tracks) => { let s = 0; for (const l of tracks) for (let k = 1; k < l.length; k++) s += haversine(l[k - 1], l[k]); return s; };

// ---- Plan des itinéraires cyclables de l'ARC ---------------------------------
const SEPARATOR = /\s*(?:◄►|–)\s*/;
// "A ◄► B par C" → [A, C, B]; "A – B – C" → [A, B, C]; a single name → [name].
function etapes(nom) {
  const out = [];
  for (const raw of nom.split(SEPARATOR)) {
    const part = raw.trim();
    if (!part) continue;
    const via = part.indexOf(' par ');
    if (via > 0) { out.push(part.slice(via + 5).trim()); out.push(part.slice(0, via).trim()); }
    else out.push(part);
  }
  return out.length ? out : [nom];
}
// "#1CC4F4" → 0xFF1CC4F4 (ARGB, as stored by the Flutter model).
function parseCouleur(v) {
  if (v === null || v === undefined) return null;
  if (typeof v === 'number') return v;
  const hex = String(v).trim().replace(/^#/, '');
  const n = parseInt(hex, 16);
  if (Number.isNaN(n)) return null;
  return hex.length <= 6 ? 0xFF000000 + n : n;
}
function readPlan(dir) {
  const p = path.join(dir, 'plan_arc.json');
  if (!fs.existsSync(p)) return null;
  const j = JSON.parse(fs.readFileSync(p, 'utf8'));
  return (j.itineraires || [])
    .map((e) => ({
      numero: Number(e.numero), nom: String(e.nom || '').trim(), couleur: parseCouleur(e.couleur),
      longueurKm: Number(e.longueurKm) || 0, datasetIds: (e.datasetIds || []).map(String) }))
    .filter((e) => e.numero && e.nom && e.couleur !== null)
    .sort((a, b) => a.numero - b.numero);
}

// ---- Documents ---------------------------------------------------------------
function commonDoc(meta) {
  return {
    sourceId: SOURCE_ID,
    sourceName: SOURCE_NAME,
    activite: 'velo',
    pratique: 'vélo',
    balisage: null, difficulte: null,
    instructions: null, presentation: null, presentationCourte: null,
    themes: [], recommandations: null, accessibilite: null, accesRoutier: null,
    transportsCommun: null, parkingInfo: null, parking: null,
    dateCreation: meta.build?.built_at ? String(meta.build.built_at).slice(0, 10) : null,
    dateModification: null,
    medias: [], typeSol: null, pdipr: false,
    url: meta.dataset?.source_url || null,
  };
}

function rowDoc(row, meta, secondaire) {
  const j = row.json;
  const tracks = mergeSegments(row.lines);
  const all = tracks.flat();
  const from = str(j.from), to = str(j.to);
  let name = str(j.name) || '';
  if (!name || name.toLowerCase() === 'sans nom') name = from || 'Itinéraire cyclable';
  const lengthM = typeof j.length_m === 'number' ? j.length_m : Math.round(geomLength(tracks));
  const start = Array.isArray(j.start_wgs84) && j.start_wgs84.length >= 2
    ? { lat: j.start_wgs84[1], lng: j.start_wgs84[0] } : tracks[0][0];
  return {
    ...commonDoc(meta),
    nom: name,
    nomLower: name.toLowerCase(),
    tracks: encodeTracks(tracks),
    start: new GeoPoint(start.lat, start.lng),
    bounds: bounds(all),
    typeItineraire: from && to && from === to ? 'boucle' : 'linéaire',
    communes: [from, to && to !== from ? to : null].filter(Boolean),
    depart: from,
    arrivee: to,
    dureeH: lengthM / 1000 / SPEED_KMH,
    longueurM: lengthM,
    altMax: j.elevation_max_m || null,
    altMin: j.elevation_min_m || null,
    denivelePositif: j.elevation_gain_m > 0 ? j.elevation_gain_m : null,
    deniveleNegatif: j.elevation_loss_m > 0 ? j.elevation_loss_m : null,
    // Dataset numbers ("Piste 4", "106") are never shown next to the plan.
    numero: secondaire ? null : str(j.number),
    statutReseau: str(j.status),
    niveau: str(j.level),
    couleur: secondaire ? SECONDARY_COLOUR : null,
    secondaire,
    pointCount: all.length,
  };
}

function planDoc(entry, matched, meta) {
  const lines = matched.flatMap((r) => r.lines);
  const tracks = mergeSegments(dedupeLines(lines));
  const all = tracks.flat();
  const first = matched[0].json;
  const places = etapes(entry.nom);
  const loop = tracks.length === 1 && haversine(tracks[0][0], tracks[0][tracks[0].length - 1]) < 200;
  return {
    ...commonDoc(meta),
    nom: entry.nom,
    nomLower: entry.nom.toLowerCase(),
    tracks: encodeTracks(tracks),
    start: new GeoPoint(tracks[0][0].lat, tracks[0][0].lng),
    bounds: bounds(all),
    typeItineraire: loop ? 'boucle' : 'linéaire',
    communes: places,
    depart: places[0],
    arrivee: places[places.length - 1],
    dureeH: entry.longueurKm / SPEED_KMH,
    longueurM: entry.longueurKm * 1000,
    altMax: null, altMin: null, denivelePositif: null, deniveleNegatif: null,
    numero: String(entry.numero),
    statutReseau: str(first.status),
    niveau: str(first.level),
    couleur: entry.couleur,
    secondaire: false,
    pointCount: all.length,
  };
}

function parseDataset(dir) {
  const jsonl = fs.readFileSync(path.join(dir, 'itineraries_min.jsonl'), 'utf8');
  const wkb = fs.readFileSync(path.join(dir, 'geoms.wkb'));
  const metaPath = path.join(dir, 'meta.json');
  const meta = fs.existsSync(metaPath) ? JSON.parse(fs.readFileSync(metaPath, 'utf8')) : {};
  const rows = [];
  for (const line of jsonl.split('\n')) {
    if (!line.trim()) continue;
    const j = JSON.parse(line);
    const lines = parseWkb(wkb, j.geom_offset || 0, j.geom_len || 0);
    if (!lines || !lines.length) { console.warn(`! géométrie illisible ${j.id}`); continue; }
    rows.push({ id: j.id, json: j, lines });
  }
  const byId = new Map(rows.map((r) => [r.id, r]));
  const plan = readPlan(dir);
  const consumed = new Set();
  const itineraires = [];
  if (plan) {
    for (const entry of plan) {
      const matched = [];
      for (const id of entry.datasetIds) {
        const row = byId.get(id);
        if (!row) { console.warn(`! plan ${entry.numero} : tronçon ${id} absent du jeu de données`); continue; }
        if (consumed.has(id)) { console.warn(`! plan ${entry.numero} : tronçon ${id} déjà utilisé`); continue; }
        consumed.add(id);
        matched.push(row);
      }
      if (!matched.length) { console.warn(`! plan ${entry.numero} (${entry.nom}) : aucune géométrie dans le jeu de données`); continue; }
      itineraires.push({ id: `${SOURCE_ID}-${entry.numero}`, doc: planDoc(entry, matched, meta) });
    }
  }
  const listed = itineraires.length;
  for (const row of rows) {
    if (consumed.has(row.id)) continue;
    itineraires.push({ id: row.id, doc: rowDoc(row, meta, !!plan) });
  }
  const allBounds = itineraires.map((i) => i.doc.bounds).reduce((a, b) => ({
    minLat: Math.min(a.minLat, b.minLat), minLng: Math.min(a.minLng, b.minLng),
    maxLat: Math.max(a.maxLat, b.maxLat), maxLng: Math.max(a.maxLng, b.maxLng) }));
  return {
    source: {
      id: SOURCE_ID,
      doc: {
        name: SOURCE_NAME,
        producteur: 'Agglomération de la Région de Compiègne',
        featureType: meta.dataset?.layer_name || 'itinerairecyclable',
        itineraireCount: plan ? listed : itineraires.length,
        enabled: true,
        activite: 'velo',
        bounds: allBounds,
        fileName: 'itineraries_min.jsonl',
        plan: plan ? 'plan_arc.json' : null,
      },
    },
    itineraires,
  };
}

async function main() {
  const args = process.argv.slice(2);
  const dirArg = args.find((a) => !a.startsWith('--'));
  const keyIdx = args.indexOf('--key');
  const dryRun = args.includes('--dry-run');
  const dir = path.resolve(dirArg || path.join(__dirname, '..', 'apps', 'rando_user', 'assets', 'velo'));
  const result = parseDataset(dir);
  const listed = result.itineraires.filter((i) => !i.doc.secondaire);
  const secondaries = result.itineraires.filter((i) => i.doc.secondaire);
  console.log(`Source  : ${result.source.doc.name} (${result.source.id})`);
  console.log(`Routes  : ${listed.length} itinéraire(s) du plan, ${secondaries.length} tronçon(s) secondaire(s)`);
  for (const it of listed) {
    const d = it.doc;
    const geomKm = geomLength(d.tracks.map((t) => t.split(';').map((p) => { const [lat, lng] = p.split(',').map(Number); return { lat, lng }; }))) / 1000;
    const col = d.couleur === null ? '-' : '#' + (d.couleur & 0xffffff).toString(16).padStart(6, '0');
    console.log(`  ${it.id.padEnd(12)} ${d.numero ? d.numero + ' · ' : ''}${d.nom} | ${(d.longueurM / 1000).toFixed(1)} km (géométrie ${geomKm.toFixed(1)} km) | ${col} | ${d.tracks.length} tronçon(s) | ${d.pointCount} pts`);
  }
  if (secondaries.length) {
    console.log('Secondaires :');
    for (const it of secondaries) console.log(`  ${it.id.slice(0, 8)} ${it.doc.nom} | ${(it.doc.longueurM / 1000).toFixed(1)} km`);
  }
  if (dryRun) return;

  initializeApp({ credential: cert(require(findKey(keyIdx >= 0 ? args[keyIdx + 1] : null))) });
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
  for (const it of result.itineraires) await add((b) => b.set(db.collection('itineraires').doc(it.id), { ...it.doc, updatedAt: now }));
  for (const d of stale) await add((b) => b.delete(d.ref));
  if (count) await flush();
  console.log(`OK : ${result.itineraires.length} itinéraire(s) vélo écrits (${listed.length} du plan), ${stale.length} supprimé(s).`);
}

main().catch((e) => { console.error(e); process.exit(1); });
