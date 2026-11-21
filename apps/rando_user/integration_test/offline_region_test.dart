// Runs on a real device / emulator:
//   flutter test integration_test/offline_region_test.dart -d <device>
// Verifies that the map tiles of a route can be saved for offline use with
// MapLibre offline regions (the mechanism behind « Enregistrer la carte hors
// ligne ») and that the bundled cycling routes are readable on the device.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:rando_user/services/map_style.dart';
import 'package:rando_user/services/offline_service.dart';
import 'package:rando_user/services/velo_dataset_loader.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bundled cycling routes load on the device', (tester) async {
    final velo = await VeloDatasetLoader.load();
    expect(velo.itineraires.where((e) => !e.secondaire).length, greaterThanOrEqualTo(20));
    expect(velo.itineraires.every((e) => e.tracks.isNotEmpty), isTrue);
  });

  testWidgets('saves and removes an offline map region for a route', (tester) async {
    // Creating a map view initialises the native MapLibre SDK.
    var styleLoaded = false;
    await tester.pumpWidget(MaterialApp(
      home: SizedBox(
        width: 320,
        height: 320,
        child: MapLibreMap(
          styleString: MapStyle.osm.styleJson(),
          initialCameraPosition: const CameraPosition(target: LatLng(49.4178, 2.8264), zoom: 12),
          onStyleLoadedCallback: () => styleLoaded = true,
        ),
      ),
    ));
    for (var i = 0; i < 100 && !styleLoaded; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    final offline = await OfflineService.create();
    final velo = await VeloDatasetLoader.load();
    // Small route to keep the download short.
    final it = velo.itineraires.where((e) => !e.secondaire).reduce((a, b) => a.lengthM < b.lengthM ? a : b);

    final res = await offline.save(it);
    // ignore: avoid_print
    print('offline save → ${res.message} (style intégré : ${res.usedInlineStyle})');
    expect(res.error, isNull, reason: 'téléchargement hors ligne en échec : ${res.error}');
    expect(offline.isSaved(it.id), isTrue);

    final regions = await getListOfRegions();
    expect(regions.any((r) => r.metadata['routeId'] == it.id), isTrue, reason: 'région absente de la base MapLibre');

    await offline.forget(it.id);
    expect(offline.isSaved(it.id), isFalse);
    final after = await getListOfRegions();
    expect(after.any((r) => r.metadata['routeId'] == it.id), isFalse);
  });
}
