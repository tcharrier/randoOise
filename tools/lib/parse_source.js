// Node port of packages/rando_core/lib/src/import/source_importer.dart.
// Parses a source zip/json ("itinéraires de randonnée" national schema) into
// Firestore-ready documents. Keep both implementations in sync.
'use strict';

const AdmZip = require('adm-zip');
const proj4 = require('proj4');
const { GeoPoint } = require('firebase-admin/firestore');

const LAMBERT93 =
  '+proj=lcc +lat_1=49 +lat_2=44 +lat_0=46.5 +lon_0=3 +x_0=700000 +y_0=6600000 ' +
  '+ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs';
const toWgs84 = proj4(LAMBERT93, 'EPSG:4326');

function slugify(input) {
  const from = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿœæ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  let s = String(input).toLowerCase();
  for (let i = 0; i < from.length; i++) s = s.split(from[i]).join(to[i]);
  s = s.replace(/\.(zip|json|geojson)$/, '').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
  return s || 'source';
}

function prettyName(s) {
  let out = String(s).replace(/_/g, ' ').trim();
  out = out.replace(/^itinerairerandonnee\s*/i, '').replace(/\.(zip|json|geojson)$/i, '');
  return out || s;
}

const str = (v) => {
  if (v === null || v === undefined) return null;
  const s = String(v).trim();
  return s === '' || s === 'null' ? null : s;
};
const num = (v) => {
  if (v === null || v === undefined || v === '') return null;
  if (typeof v === 'number') return v;
  const n = parseFloat(String(v).replace(',', '.'));
  return Number.isFinite(n) ? n : null;
};
const hours = (v) => {
  const n = num(v);
  if (n !== null) return n;
  const m = /(\d+)\s*h\s*(\d*)/i.exec(String(v || ''));
  if (!m) return null;
  return parseInt(m[1], 10) + (parseInt(m[2] || '0', 10) || 0) / 60;
};
const bool = (v) => v === true || ['true', '1', 'oui'].includes(String(v).toLowerCase());
const uniqueList = (s) => {
  if (!s) return [];
  const seen = new Set();
  const out = [];
  for (const part of String(s).split(/[,;|]/)) {
    const t = part.trim();
    if (!t || seen.has(t)) continue;
    seen.add(t);
    out.push(t);
  }
  return out;
};
const latLngFromString = (s) => {
  if (!s) return null;
  const parts = String(s).split(/[,\s]+/).filter(Boolean).map(parseFloat);
  if (parts.length < 2 || parts.some((x) => !Number.isFinite(x))) return null;
  const [a, b] = parts;
  if (Math.abs(a) <= 90 && Math.abs(b) <= 180) return { lat: a, lng: b };
  if (Math.abs(b) <= 90 && Math.abs(a) <= 180) return { lat: b, lng: a };
  return null;
};
const medias = (v) => {
  const one = (m) => {
    if (!m || typeof m !== 'object') return null;
    const item = { url: m.url ?? null, titre: m.titre ?? null, auteur: m.auteur ?? null, licence: m.licence ?? null, type: m.type ?? m.type_media ?? null };
    return item.url || item.titre ? item : null;
  };
  if (Array.isArray(v)) return v.map(one).filter(Boolean);
  const o = one(v);
  return o ? [o] : [];
};

function extractItems(decoded) {
  if (Array.isArray(decoded)) return decoded;
  if (decoded && typeof decoded === 'object') {
    if (Array.isArray(decoded.features)) return decoded.features;
    if (Array.isArray(decoded.itineraires)) return decoded.itineraires;
    return Object.keys(decoded)
      .sort((a, b) => (parseInt(a, 10) || 0) - (parseInt(b, 10) || 0))
      .map((k) => decoded[k]);
  }
  throw new Error('Format JSON non reconnu.');
}

function geometryOf(p) {
  for (const c of [p.json_geometry, p.geometry, p.geometrie]) {
    if (c && typeof c === 'object' && c.coordinates) return c;
    if (typeof c === 'string' && c.trim().startsWith('{')) {
      try {
        const m = JSON.parse(c);
        if (m && m.coordinates) return m;
      } catch (_) {}
    }
  }
  return null;
}

function firstCoord(c) {
  if (Array.isArray(c) && c.length) {
    if (typeof c[0] === 'number') return c.slice(0, 2);
    return firstCoord(c[0]);
  }
  return null;
}

function isLambert(p, geom) {
  const name = geom.crs && geom.crs.properties && geom.crs.properties.name;
  if (name && String(name).includes('2154')) return true;
  if (name && String(name).includes('4326')) return false;
  const wkt = String(p.json_ogc_wkt_crs || '');
  if (wkt.includes('Lambert-93') || wkt.includes('2154')) return true;
  if (typeof p.geometry === 'string' && p.geometry.includes('2154')) return true;
  const f = firstCoord(geom.coordinates);
  return !!(f && (Math.abs(f[0]) > 360 || Math.abs(f[1]) > 360));
}

function segments(geom, lambert) {
  const conv = (c) => {
    if (lambert) {
      const [lng, lat] = toWgs84.forward([c[0], c[1]]);
      return { lat, lng };
    }
    return { lat: c[1], lng: c[0] };
  };
  const line = (l) => l.filter((c) => Array.isArray(c) && c.length >= 2).map(conv);
  const type = String(geom.type || '').toLowerCase();
  const coords = geom.coordinates;
  switch (type) {
    case 'linestring': return [line(coords)];
    case 'multilinestring':
    case 'polygon': return coords.filter(Array.isArray).map(line);
    case 'point': return [[conv(coords)]];
    default: return [];
  }
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
  // Second pass: segments are not always listed in order, so greedily chain
  // polylines whose endpoints touch.
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

const R = 6371000;
function haversine(a, b) {
  const rad = (d) => (d * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat), dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(h)));
}

function bounds(points) {
  let minLat = Infinity, minLng = Infinity, maxLat = -Infinity, maxLng = -Infinity;
  for (const p of points) {
    minLat = Math.min(minLat, p.lat); maxLat = Math.max(maxLat, p.lat);
    minLng = Math.min(minLng, p.lng); maxLng = Math.max(maxLng, p.lng);
  }
  return { minLat, minLng, maxLat, maxLng };
}

const encodeTracks = (tracks) => tracks.map((l) => l.map((p) => `${p.lat.toFixed(6)},${p.lng.toFixed(6)}`).join(';'));

function parseJson(json, fileName) {
  const items = extractItems(JSON.parse(json));
  const warnings = [];
  const itineraires = [];
  let producteur = null, featureType = null;

  items.forEach((raw, i) => {
    if (!raw || typeof raw !== 'object') return;
    const p = raw.properties && typeof raw.properties === 'object'
      ? { ...raw.properties, json_geometry: raw.properties.json_geometry ?? raw.geometry }
      : { ...raw };
    producteur = producteur ?? str(p.producteur);
    featureType = featureType ?? str(p.json_featuretype);
    const geom = geometryOf(p);
    if (!geom) { warnings.push(`Élément ${i} ignoré : pas de géométrie exploitable.`); return; }
    const tracks = mergeSegments(segments(geom, isLambert(p, geom)));
    if (!tracks.length) { warnings.push(`Élément ${i} ignoré : géométrie vide.`); return; }
    const all = tracks.flat();
    const start = tracks[0][0];
    const parking = latLngFromString(str(p.parking_geometrie));
    let length = 0;
    for (const l of tracks) for (let k = 1; k < l.length; k++) length += haversine(l[k - 1], l[k]);
    itineraires.push({
      id: str(p.uuid) ?? str(p.id_local) ?? str(p.id) ?? slugify(`${fileName || 'src'}-${i}`),
      doc: {
        nom: str(p.nom_itineraire) ?? str(p.nom) ?? `Itinéraire ${i + 1}`,
        tracks: encodeTracks(tracks),
        start: new GeoPoint(start.lat, start.lng),
        bounds: bounds(all),
        pratique: str(p.pratique),
        typeItineraire: str(p.type_itineraire),
        communes: uniqueList(str(p.communes_nom)),
        depart: str(p.depart),
        arrivee: str(p.arrivee),
        dureeH: hours(p.duree),
        balisage: str(p.balisage),
        longueurM: num(p.longueur) ?? Math.round(length),
        difficulte: str(p.difficulte),
        altMax: num(p.altitude_max),
        altMin: num(p.altitude_min),
        denivelePositif: num(p.denivele_positif),
        deniveleNegatif: num(p.denivele_negatif),
        instructions: str(p.instructions),
        presentation: str(p.presentation),
        presentationCourte: str(p.presentation_courte),
        themes: uniqueList(str(p.themes)),
        recommandations: str(p.recommandations),
        accessibilite: str(p.accessibilite),
        accesRoutier: str(p.acces_routier),
        transportsCommun: str(p.transports_commun),
        parkingInfo: str(p.parking_info),
        parking: parking ? new GeoPoint(parking.lat, parking.lng) : null,
        dateCreation: str(p.date_creation),
        dateModification: str(p.date_modification),
        medias: medias(p.medias),
        typeSol: str(p.type_sol),
        pdipr: bool(p.pdipr_inscription),
        url: str(p.url),
        pointCount: all.length,
      },
    });
  });

  const label = producteur ?? featureType ?? fileName ?? 'Source';
  const sourceId = slugify(label);
  const sourceName = prettyName(label);
  for (const it of itineraires) {
    it.doc.sourceId = sourceId;
    it.doc.sourceName = sourceName;
    it.doc.nomLower = it.doc.nom.toLowerCase();
  }
  const allBounds = itineraires.length
    ? itineraires.map((i) => i.doc.bounds).reduce((a, b) => ({
        minLat: Math.min(a.minLat, b.minLat), minLng: Math.min(a.minLng, b.minLng),
        maxLat: Math.max(a.maxLat, b.maxLat), maxLng: Math.max(a.maxLng, b.maxLng) }))
    : null;
  return {
    source: {
      id: sourceId,
      doc: {
        name: sourceName,
        producteur: producteur ?? '',
        featureType: featureType ?? '',
        itineraireCount: itineraires.length,
        enabled: true,
        bounds: allBounds,
        fileName: fileName ?? null,
      },
    },
    itineraires,
    warnings,
  };
}

function parseFile(filePath) {
  const fs = require('fs');
  const path = require('path');
  const name = path.basename(filePath);
  const buf = fs.readFileSync(filePath);
  const isZip = buf.length > 4 && buf[0] === 0x50 && buf[1] === 0x4b;
  if (!isZip) return parseJson(buf.toString('utf8'), name);
  const zip = new AdmZip(buf);
  const entries = zip.getEntries().filter((e) => !e.isDirectory && /\.(geo)?json$/i.test(e.entryName));
  if (!entries.length) throw new Error('Aucun fichier .json dans le zip.');
  let merged = null;
  for (const e of entries) {
    const r = parseJson(e.getData().toString('utf8'), name);
    if (!merged) merged = r;
    else {
      merged.itineraires.push(...r.itineraires);
      merged.warnings.push(...r.warnings);
      merged.source.doc.itineraireCount = merged.itineraires.length;
    }
  }
  return merged;
}

module.exports = { parseFile, parseJson, slugify };
