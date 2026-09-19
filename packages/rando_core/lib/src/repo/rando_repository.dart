import 'package:cloud_firestore/cloud_firestore.dart';

import '../import/source_importer.dart';
import '../models/element_remarquable.dart';
import '../models/itineraire.dart';
import '../models/signalement.dart';
import '../models/source.dart';

/// Firestore access shared by the user app and the admin app.
///
/// Collections:
///  - sources/{sourceId}
///  - itineraires/{itineraireId}
///  - signalements/{id}
///  - elements/{id}
///  - admins/{uid}
class RandoRepository {
  RandoRepository(this.db);

  final FirebaseFirestore db;

  CollectionReference<Map<String, dynamic>> get sources => db.collection('sources');
  CollectionReference<Map<String, dynamic>> get itineraires => db.collection('itineraires');
  CollectionReference<Map<String, dynamic>> get signalements => db.collection('signalements');
  CollectionReference<Map<String, dynamic>> get elements => db.collection('elements');
  CollectionReference<Map<String, dynamic>> get admins => db.collection('admins');

  // ---------------------------------------------------------------- sources

  Stream<List<RandoSource>> watchSources() => sources.snapshots().map((s) =>
      s.docs.map((d) => RandoSource.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => a.name.compareTo(b.name)));

  Future<void> setSourceEnabled(String sourceId, bool enabled) =>
      sources.doc(sourceId).update({'enabled': enabled});

  /// Writes the source and all its routes. Existing routes of the same source
  /// that are not part of the import are deleted (full replace).
  Future<void> importSource(ImportResult result,
      {void Function(int done, int total)? onProgress}) async {
    final existing = await itineraires
        .where('sourceId', isEqualTo: result.source.id)
        .get();
    final newIds = result.itineraires.map((e) => e.id).toSet();
    final toDelete = existing.docs.where((d) => !newIds.contains(d.id)).toList();

    final ops = <void Function(WriteBatch)>[];
    ops.add((b) => b.set(sources.doc(result.source.id), result.source.toMap()));
    for (final it in result.itineraires) {
      ops.add((b) => b.set(itineraires.doc(it.id), it.toMap()));
    }
    for (final d in toDelete) {
      ops.add((b) => b.delete(d.reference));
    }
    await _runBatched(ops, onProgress: onProgress);
  }

  /// Deletes a source, its routes and their reports / points of interest.
  Future<void> deleteSource(String sourceId) async {
    final ops = <void Function(WriteBatch)>[];
    for (final col in [itineraires, signalements, elements]) {
      final snap = await col.where('sourceId', isEqualTo: sourceId).get();
      for (final d in snap.docs) {
        ops.add((b) => b.delete(d.reference));
      }
    }
    ops.add((b) => b.delete(sources.doc(sourceId)));
    await _runBatched(ops);
  }

  Future<void> _runBatched(List<void Function(WriteBatch)> ops,
      {void Function(int done, int total)? onProgress}) async {
    const chunk = 400;
    for (var i = 0; i < ops.length; i += chunk) {
      final batch = db.batch();
      for (final op in ops.skip(i).take(chunk)) {
        op(batch);
      }
      await batch.commit();
      onProgress?.call((i + chunk).clamp(0, ops.length), ops.length);
    }
  }

  // ------------------------------------------------------------ itineraires

  Stream<List<Itineraire>> watchItineraires() => itineraires.snapshots().map(
      (s) => s.docs.map((d) => Itineraire.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase())));

  Future<List<Itineraire>> fetchItineraires({Source? source}) async {
    final snap = await itineraires.get(
        source == null ? null : GetOptions(source: source));
    return snap.docs.map((d) => Itineraire.fromMap(d.id, d.data())).toList();
  }

  Future<Itineraire?> getItineraire(String id) async {
    final d = await itineraires.doc(id).get();
    if (!d.exists) return null;
    return Itineraire.fromMap(d.id, d.data()!);
  }

  // ----------------------------------------------------------- signalements

  Stream<List<Signalement>> watchSignalements({String? itineraireId}) {
    Query<Map<String, dynamic>> q = signalements;
    if (itineraireId != null) q = q.where('itineraireId', isEqualTo: itineraireId);
    return q.snapshots().map((s) =>
        s.docs.map((d) => Signalement.fromMap(d.id, d.data())).toList()
          ..sort(_byCreatedDesc));
  }

  Future<String> createSignalement(Signalement s) async {
    final ref = signalements.doc();
    // Not awaited on purpose: when offline the write is queued and the
    // Future only completes once the server acknowledges it.
    ref.set(s.toCreateMap());
    return ref.id;
  }

  /// "+1" on a report. The security rules only accept this exact shape.
  Future<void> voteSignalement(String id, String uid) => signalements.doc(id).update({
        'votes': FieldValue.increment(1),
        'voters': FieldValue.arrayUnion([uid]),
      });

  Future<void> setSignalementStatut(String id, SignalementStatut statut,
      {required String adminUid, String? commentaire}) {
    final data = <String, dynamic>{
      'statut': statut.code,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (commentaire != null) data['commentaireAdmin'] = commentaire;
    if (statut == SignalementStatut.valide) {
      data['validePar'] = adminUid;
      data['valideAt'] = FieldValue.serverTimestamp();
    }
    return signalements.doc(id).update(data);
  }

  Future<void> deleteSignalement(String id) => signalements.doc(id).delete();

  // --------------------------------------------------------------- elements

  Stream<List<ElementRemarquable>> watchElements({String? itineraireId}) {
    Query<Map<String, dynamic>> q = elements;
    if (itineraireId != null) q = q.where('itineraireId', isEqualTo: itineraireId);
    return q.snapshots().map((s) =>
        s.docs.map((d) => ElementRemarquable.fromMap(d.id, d.data())).toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(0))
              .compareTo(a.createdAt ?? DateTime(0))));
  }

  Future<String> createElement(ElementRemarquable e) async {
    final ref = elements.doc();
    ref.set(e.toCreateMap());
    return ref.id;
  }

  Future<void> setElementStatut(String id, ElementStatut statut,
      {required String adminUid}) {
    final data = <String, dynamic>{'statut': statut.code};
    if (statut == ElementStatut.valide) {
      data['validePar'] = adminUid;
      data['valideAt'] = FieldValue.serverTimestamp();
    }
    return elements.doc(id).update(data);
  }

  Future<void> deleteElement(String id) => elements.doc(id).delete();

  // ----------------------------------------------------------------- admins

  Future<bool> isAdmin(String uid) async {
    try {
      final d = await admins.doc(uid).get();
      return d.exists;
    } catch (_) {
      return false;
    }
  }

  static int _byCreatedDesc(Signalement a, Signalement b) =>
      (b.createdAt ?? DateTime(2100)).compareTo(a.createdAt ?? DateTime(2100));
}
