import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rando_core/rando_core.dart';

/// Plan itineraries whose dataset geometry is known to differ from the length
/// printed on the plan by more than 25 % (fraction of the plan length):
/// 11 – the dataset only has Le Meux → Rivecourt, the plan continues west;
/// 14 – "Piste 14" also holds the links to Jaux and to Compiègne;
/// 16 – "Piste 16" shares the Margny → gare section with 8;
/// 17 – "Piste 17" also holds the Mercières → Abbaye section.
const Map<int, double> _geomTolerance = {11: 0.6, 14: 0.7, 16: 0.5, 17: 0.6};

void main() {
  final dir = Directory('../../apps/rando_user/assets/velo');
  String jsonl() => File('${dir.path}/itineraries_min.jsonl').readAsStringSync();
  ByteData wkb() => ByteData.sublistView(Uint8List.fromList(File('${dir.path}/geoms.wkb').readAsBytesSync()));
  Map<String, dynamic> json(String name) => jsonDecode(File('${dir.path}/$name').readAsStringSync()) as Map<String, dynamic>;

  test('parses the embedded ARC cycling dataset (without the plan)', () {
    if (!dir.existsSync()) return;
    final r = VeloDataset.parse(jsonl(), wkb(), meta: json('meta.json'));

    expect(r.warnings, isEmpty);
    expect(r.itineraires.length, 45);
    expect(r.source.id, 'arc-velo');
    expect(r.source.activite, Activite.velo);
    expect(r.source.itineraireCount, 45);
    for (final it in r.itineraires) {
      expect(it.activite, Activite.velo);
      expect(it.embedded, isTrue);
      expect(it.secondaire, isFalse);
      expect(it.couleur, isNull);
      expect(it.tracks, isNotEmpty);
      // Around Compiègne.
      expect(it.start.latitude, inInclusiveRange(49.2, 49.6));
      expect(it.start.longitude, inInclusiveRange(2.6, 3.1));
      expect(it.lengthM, greaterThan(10));
      expect(it.dureeH, greaterThan(0));
      // Declared length and geometry should roughly agree (within 15 %).
      final geomLen = tracksLengthM(it.tracks);
      expect((geomLen - it.lengthM).abs() / it.lengthM, lessThan(0.15), reason: it.nom);
    }
    final piste4 = r.itineraires.firstWhere((e) => e.numero == 'Piste 4');
    expect(piste4.titre, 'Piste 4 · Compiègne');
    expect(piste4.trajetLabel, 'Compiègne → Pierrefonds');
    expect(piste4.statutReseau, StatutReseau.enService);
  });

  test('reads the plan entries', () {
    if (!dir.existsSync()) return;
    final entries = PlanArcEntry.listFromJson(json('plan_arc.json'));
    expect(entries.length, 21);
    expect(entries.map((e) => e.numero), List.generate(21, (i) => i + 1));
    expect(entries.map((e) => e.id).toSet().length, 21);
    final ids = entries.expand((e) => e.datasetIds).toList();
    expect(ids.toSet().length, ids.length, reason: 'a dataset row belongs to one itinerary');
    for (final e in entries) {
      expect(e.couleur >> 24, 0xFF, reason: 'opaque ARGB colour for ${e.numero}');
      expect(e.longueurKm, greaterThan(0));
    }
    final e3 = entries[2];
    expect(e3.nom, 'Compiègne ◄► Pierrefonds par Saint-Jean-aux-Bois');
    expect(e3.etapes, ['Compiègne', 'Saint-Jean-aux-Bois', 'Pierrefonds']);
    expect(e3.depart, 'Compiègne');
    expect(e3.arrivee, 'Pierrefonds');
    expect(entries[0].etapes, ["La Trans'Oise"]);
    expect(entries[14].etapes, ['Mercières', 'Parc tertiaire']);
    expect(entries[20].etapes, ['Venette', 'Margny', 'Clairoix']);
    expect(PlanArcEntry.parseCouleur('#1CC4F4'), 0xFF1CC4F4);
    expect(PlanArcEntry.parseCouleur('9c9c9c'), 0xFF9C9C9C);
    expect(PlanArcEntry.parseCouleur(0xFF123456), 0xFF123456);
    expect(PlanArcEntry.parseCouleur('zz'), isNull);
  });

  test('aligns the dataset with the official plan', () {
    if (!dir.existsSync()) return;
    final plan = json('plan_arc.json');
    final entries = PlanArcEntry.listFromJson(plan);
    final r = VeloDataset.parse(jsonl(), wkb(), meta: json('meta.json'), planJson: plan);

    expect(r.warnings, isEmpty);
    final withGeometry = entries.where((e) => e.datasetIds.isNotEmpty).toList();
    final consumed = withGeometry.expand((e) => e.datasetIds).toSet();
    final listed = r.itineraires.where((e) => !e.secondaire).toList();
    final secondaries = r.itineraires.where((e) => e.secondaire).toList();

    expect(listed.length, withGeometry.length);
    expect(r.source.itineraireCount, listed.length);
    expect(secondaries.length, 45 - consumed.length);
    expect(r.itineraires.length, listed.length + secondaries.length);
    // Listed first, in plan order.
    expect(r.itineraires.take(listed.length).map((e) => e.id), withGeometry.map((e) => e.id));

    for (final e in withGeometry) {
      final it = r.itineraires.singleWhere((i) => i.id == 'arc-velo-${e.numero}');
      expect(it.numero, '${e.numero}');
      expect(it.nom, e.nom);
      expect(it.titre, '${e.numero} · ${e.nom}');
      expect(it.couleur, e.couleur);
      expect(it.secondaire, isFalse);
      expect(it.embedded, isTrue);
      expect(it.activite, Activite.velo);
      expect(it.sourceId, 'arc-velo');
      expect(it.lengthM, closeTo(e.longueurKm * 1000, 0.01));
      expect(it.dureeH, closeTo(e.longueurKm / VeloDataset.speedKmh, 1e-9));
      expect(it.communes, e.etapes);
      expect(it.depart, e.etapes.first);
      expect(it.arrivee, e.etapes.last);
      expect(it.statutReseau, StatutReseau.enService);
      expect(it.tracks, isNotEmpty);
      expect(it.start.latitude, inInclusiveRange(49.2, 49.6));
      expect(it.start.longitude, inInclusiveRange(2.6, 3.1));
      expect(it.bounds.contains(it.start), isTrue);
      // The drawn geometry should agree with the length printed on the plan.
      final geomKm = tracksLengthM(it.tracks) / 1000;
      final tolerance = _geomTolerance[e.numero] ?? 0.25;
      expect((geomKm - e.longueurKm).abs() / e.longueurKm, lessThan(tolerance),
          reason: '${it.titre}: géométrie ${geomKm.toStringAsFixed(2)} km vs plan ${e.longueurKm} km');
    }
    for (final e in entries.where((e) => e.datasetIds.isEmpty)) {
      expect(r.itineraires.where((i) => i.id == e.id), isEmpty, reason: 'plan ${e.numero} has no geometry');
    }

    final p12 = r.itineraires.singleWhere((e) => e.id == 'arc-velo-12');
    expect(p12.titre, '12 · Saintines ◄► Néry ◄► Béthisy-St-Martin ◄► Béthisy-St-Pierre');
    expect(p12.trajetLabel, 'Saintines → Béthisy-St-Pierre');
    expect(p12.couleur, 0xFF8CCC44);
    final p4 = r.itineraires.singleWhere((e) => e.id == 'arc-velo-4');
    expect(p4.titre, '4 · Compiègne ◄► Pierrefonds par Vieux-Moulin');
    expect(p4.trajetLabel, 'Compiègne → Pierrefonds');
    expect(p4.communes, ['Compiègne', 'Vieux-Moulin', 'Pierrefonds']);
    expect(p4.lengthM, 12800);
    // Both sides of the lane are stored in the dataset: only one is drawn.
    final p7 = r.itineraires.singleWhere((e) => e.id == 'arc-velo-7');
    expect(tracksLengthM(p7.tracks) / 1000, closeTo(3.8, 0.5));

    for (final s in secondaries) {
      expect(consumed.contains(s.id), isFalse);
      expect(s.numero, isNull, reason: 'dataset numbers are never shown');
      expect(s.titre, s.nom);
      expect(s.couleur, VeloDataset.secondaryCouleur);
      expect(s.embedded, isTrue);
      expect(s.tracks, isNotEmpty);
    }
    // Every "Piste N" row of the dataset belongs to a plan itinerary.
    final datasetNumbers = const LineSplitter()
        .convert(jsonl())
        .where((l) => l.trim().isNotEmpty)
        .map((l) => jsonDecode(l) as Map<String, dynamic>)
        .where((j) => (j['number'] ?? '').toString().startsWith('Piste '))
        .map((j) => j['id'].toString());
    for (final id in datasetNumbers) {
      expect(consumed.contains(id), isTrue, reason: '$id is a numbered lane of the dataset');
    }
  });

  test('dedupeLines drops a line retracing a kept one', () {
    const a = [LatLng(49.40, 2.80), LatLng(49.41, 2.80), LatLng(49.42, 2.80)];
    // 5 m east of [a], reversed.
    const b = [LatLng(49.42, 2.80007), LatLng(49.41, 2.80007), LatLng(49.40, 2.80007)];
    // 300 m east of [a].
    const c = [LatLng(49.40, 2.804), LatLng(49.42, 2.804)];
    final kept = VeloDataset.dedupeLines([a, b, c]);
    expect(kept, [a, c]);
    expect(VeloDataset.dedupeLines([b, a]), [b]);
  });

  test('Firestore round trip keeps the activity and cycling fields', () {
    if (!dir.existsSync()) return;
    final r = VeloDataset.parse(jsonl(), wkb(), planJson: json('plan_arc.json'));
    final listed = r.itineraires.firstWhere((e) => !e.secondaire);
    final secondary = r.itineraires.firstWhere((e) => e.secondaire);
    for (final it in [listed, secondary]) {
      final map = it.toMap()..remove('updatedAt');
      final back = Itineraire.fromMap(it.id, map);
      expect(back.activite, Activite.velo);
      expect(back.numero, it.numero);
      expect(back.statutReseau, it.statutReseau);
      expect(back.niveau, it.niveau);
      expect(back.couleur, it.couleur);
      expect(back.secondaire, it.secondaire);
      expect(back.pointCount, it.pointCount);
      expect(back.titre, it.titre);
      expect(back.embedded, isFalse);
    }
    expect(listed.couleur, isNotNull);
    expect(secondary.couleur, VeloDataset.secondaryCouleur);
  });
}
