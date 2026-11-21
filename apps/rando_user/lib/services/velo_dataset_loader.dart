import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:rando_core/rando_core.dart';

/// Loads the ARC cycling network bundled with the app (assets/velo).
/// The dataset lives on the phone: it is available offline from the first
/// launch and never depends on Firestore.
///
/// The routes are the 21 numbered itineraries of the official plan
/// (`plan_arc.json`); the other lanes of the dataset are secondary.
class VeloDatasetLoader {
  VeloDatasetLoader._();

  static Future<({RandoSource source, List<Itineraire> itineraires})> load() async {
    final jsonl = await rootBundle.loadString('assets/velo/itineraries_min.jsonl');
    final wkb = await rootBundle.load('assets/velo/geoms.wkb');
    Map<String, dynamic>? meta;
    try {
      meta = jsonDecode(await rootBundle.loadString('assets/velo/meta.json')) as Map<String, dynamic>;
    } catch (_) {}
    Map<String, dynamic>? plan;
    try {
      plan = jsonDecode(await rootBundle.loadString('assets/velo/plan_arc.json')) as Map<String, dynamic>;
    } catch (_) {}
    final r = VeloDataset.parse(jsonl, wkb, meta: meta, planJson: plan);
    return (source: r.source, itineraires: r.itineraires);
  }
}
