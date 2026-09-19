import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rando_core/rando_core.dart';

void main() {
  test('Lambert-93 conversion lands in the Oise', () {
    final p = Lambert93.toWgs84(700609.988497499, 6920256.083543866);
    expect(p.latitude, closeTo(49.386, 0.01));
    expect(p.longitude, closeTo(3.008, 0.01));
  });

  test('track codec round-trips', () {
    final tracks = [
      [Lambert93.toWgs84(700609.98, 6920256.08), Lambert93.toWgs84(700600.59, 6920255.81)]
    ];
    final decoded = TrackCodec.decode(TrackCodec.encode(tracks));
    expect(decoded.length, 1);
    expect(decoded.first.length, 2);
    expect(decoded.first.first.latitude, closeTo(tracks.first.first.latitude, 1e-5));
  });

  test('slugify', () {
    expect(slugify("CC_des_Lisières_de_l'Oise"), 'cc-des-lisieres-de-l-oise');
  });

  test('imports the sample zip from /data', () {
    final dir = Directory('../../data');
    if (!dir.existsSync()) return;
    final zip = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.zip'))
        .toList();
    if (zip.isEmpty) return;
    final result = SourceImporter.fromBytes(zip.first.readAsBytesSync(),
        fileName: zip.first.uri.pathSegments.last);
    expect(result.itineraires, isNotEmpty);
    expect(result.warnings, isEmpty);
    expect(result.source.id, 'cc-des-lisieres-de-l-oise');
    for (final it in result.itineraires) {
      expect(it.tracks, isNotEmpty);
      expect(it.bounds.contains(it.start), isTrue);
      // All routes are in the Oise (roughly lat 49.1-49.8, lng 1.6-3.2).
      expect(it.start.latitude, inInclusiveRange(49.0, 49.9));
      expect(it.start.longitude, inInclusiveRange(1.5, 3.3));
      expect(it.lengthM, greaterThan(500));
      // Segments were merged into few continuous polylines.
      expect(it.tracks.length, lessThan(10));
    }
  });
}
