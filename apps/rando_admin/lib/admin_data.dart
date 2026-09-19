import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rando_core/rando_core.dart';

/// Central store shared by all admin screens: subscribes once to the
/// Firestore streams and exposes plain lists + small helpers.
class AdminData extends ChangeNotifier {
  AdminData(this.repo) {
    _sourcesSub = repo.watchSources().listen((v) {
      sources = v;
      notifyListeners();
    });
    _itinerairesSub = repo.watchItineraires().listen((v) {
      itineraires = v;
      notifyListeners();
    });
    _signalementsSub = repo.watchSignalements().listen((v) {
      signalements = v;
      notifyListeners();
    });
    _elementsSub = repo.watchElements().listen((v) {
      elements = v;
      notifyListeners();
    });
  }

  final RandoRepository repo;

  List<RandoSource> sources = [];
  List<Itineraire> itineraires = [];
  List<Signalement> signalements = [];
  List<ElementRemarquable> elements = [];

  late final StreamSubscription<List<RandoSource>> _sourcesSub;
  late final StreamSubscription<List<Itineraire>> _itinerairesSub;
  late final StreamSubscription<List<Signalement>> _signalementsSub;
  late final StreamSubscription<List<ElementRemarquable>> _elementsSub;

  Itineraire? itineraireById(String id) {
    for (final it in itineraires) {
      if (it.id == id) return it;
    }
    return null;
  }

  RandoSource? sourceById(String id) {
    for (final s in sources) {
      if (s.id == id) return s;
    }
    return null;
  }

  int signalementCount(String itineraireId) =>
      signalements.where((s) => s.itineraireId == itineraireId).length;

  int validatedElementCount(String itineraireId) => elements
      .where((e) => e.itineraireId == itineraireId && e.isValide)
      .length;

  int get signaleCount =>
      signalements.where((s) => s.statut == SignalementStatut.signale).length;

  int get elementsEnAttenteCount =>
      elements.where((e) => e.statut == ElementStatut.enAttente).length;

  @override
  void dispose() {
    _sourcesSub.cancel();
    _itinerairesSub.cancel();
    _signalementsSub.cancel();
    _elementsSub.cancel();
    super.dispose();
  }
}
