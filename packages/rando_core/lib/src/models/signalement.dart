import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Lifecycle of a report: signalé → en cours → validé (by the ARC admin).
enum SignalementStatut {
  signale('signale', 'Signalé', Color(0xFFB7791F)),
  enCours('en_cours', 'En cours', Color(0xFF2B6CB0)),
  valide('valide', 'Validé', Color(0xFF2F855A));

  const SignalementStatut(this.code, this.label, this.color);
  final String code;
  final String label;
  final Color color;

  static SignalementStatut fromCode(String? code) => SignalementStatut.values
      .firstWhere((s) => s.code == code, orElse: () => SignalementStatut.signale);
}

/// Categories offered in the report form (drop-down).
enum SignalementCategorie {
  obstacle('obstacle', 'Obstacle sur le chemin', Icons.block),
  balisage('balisage', 'Balisage manquant ou dégradé', Icons.signpost_outlined),
  danger('danger', 'Zone dangereuse', Icons.warning_amber_rounded),
  chemin('chemin', 'Chemin impraticable (boue, inondation)', Icons.water_drop_outlined),
  proprete('proprete', 'Dépôt sauvage / propreté', Icons.delete_outline),
  equipement('equipement', 'Équipement endommagé (panneau, banc, barrière)', Icons.build_outlined),
  autre('autre', 'Autre', Icons.more_horiz);

  const SignalementCategorie(this.code, this.label, this.icon);
  final String code;
  final String label;
  final IconData icon;

  static SignalementCategorie fromCode(String? code) =>
      SignalementCategorie.values.firstWhere((c) => c.code == code,
          orElse: () => SignalementCategorie.autre);
}

class Signalement {
  const Signalement({
    required this.id,
    required this.itineraireId,
    required this.itineraireNom,
    required this.sourceId,
    required this.categorie,
    required this.description,
    required this.position,
    required this.statut,
    required this.auteurId,
    required this.votes,
    required this.voters,
    this.createdAt,
    this.updatedAt,
    this.validePar,
    this.valideAt,
    this.commentaireAdmin,
  });

  final String id;
  final String itineraireId;
  final String itineraireNom;
  final String sourceId;
  final SignalementCategorie categorie;
  final String description;
  final LatLng position;
  final SignalementStatut statut;
  final String auteurId;
  final int votes;
  final List<String> voters;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? validePar;
  final DateTime? valideAt;
  final String? commentaireAdmin;

  bool hasVoted(String? uid) => uid != null && voters.contains(uid);
  bool isAuthor(String? uid) => uid != null && auteurId == uid;

  Map<String, dynamic> toCreateMap() => {
        'itineraireId': itineraireId,
        'itineraireNom': itineraireNom,
        'sourceId': sourceId,
        'categorie': categorie.code,
        'description': description,
        'position': GeoPoint(position.latitude, position.longitude),
        'statut': SignalementStatut.signale.code,
        'auteurId': auteurId,
        'votes': 1,
        'voters': [auteurId],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory Signalement.fromMap(String id, Map<String, dynamic> m) {
    final gp = m['position'] as GeoPoint?;
    return Signalement(
      id: id,
      itineraireId: (m['itineraireId'] ?? '') as String,
      itineraireNom: (m['itineraireNom'] ?? '') as String,
      sourceId: (m['sourceId'] ?? '') as String,
      categorie: SignalementCategorie.fromCode(m['categorie'] as String?),
      description: (m['description'] ?? '') as String,
      position: gp == null ? const LatLng(0, 0) : LatLng(gp.latitude, gp.longitude),
      statut: SignalementStatut.fromCode(m['statut'] as String?),
      auteurId: (m['auteurId'] ?? '') as String,
      votes: (m['votes'] as num?)?.toInt() ?? 0,
      voters: ((m['voters'] as List?) ?? const []).map((e) => e.toString()).toList(),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
      validePar: m['validePar'] as String?,
      valideAt: (m['valideAt'] as Timestamp?)?.toDate(),
      commentaireAdmin: m['commentaireAdmin'] as String?,
    );
  }
}
