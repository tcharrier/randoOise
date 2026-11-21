import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rando_core/rando_core.dart';
import 'package:rando_user/app_state.dart';
import 'package:rando_user/services/map_style.dart';
import 'package:rando_user/services/offline_service.dart';

void main() {
  test('MapStyle.styleJson is a valid raster style with glyphs', () {
    for (final s in MapStyle.all) {
      final j = jsonDecode(s.styleJson()) as Map<String, dynamic>;
      expect(j['version'], 8);
      expect(j['glyphs'], isA<String>());
      final src = (j['sources'] as Map)[s.id] as Map;
      expect(src['type'], 'raster');
      expect(src['tiles'], [s.tileUrl]);
      expect(s.offlineStyleUrl, 'asset://flutter_assets/${s.assetPath}');
    }
  });

  test('OfflineSaveResult messages', () {
    expect(const OfflineSaveResult().message, contains('Carte enregistrée :'));
    expect(const OfflineSaveResult(usedInlineStyle: true).message, contains('style intégré'));
    expect(const OfflineSaveResult(error: 'x').ok, isFalse);
  });

  test('GeoBounds.pad grows the area used for offline download', () {
    const b = GeoBounds(minLat: 49.0, minLng: 2.0, maxLat: 49.1, maxLng: 2.1);
    final p = b.pad(400);
    expect(p.minLat, lessThan(b.minLat));
    expect(p.maxLng, greaterThan(b.maxLng));
  });

  test('AppState.authMessageFor distinguishes disabled auth from network', () {
    expect(AppState.authMessageFor('configuration-not-found'), contains('pas encore activé'));
    expect(AppState.authMessageFor('operation-not-allowed'), contains('pas encore activé'));
    // Android wraps the backend reason into an internal-error message.
    expect(
      AppState.authMessageFor('internal-error', 'An internal error has occurred. [ CONFIGURATION_NOT_FOUND ]'),
      contains('pas encore activé'),
    );
    expect(AppState.authMessageFor('network-request-failed'), contains('connexion internet'));
    expect(AppState.authMessageFor(null), contains('connexion internet'));
    expect(AppState.authMessageFor('too-many-requests'), contains('too-many-requests'));
  });
}
