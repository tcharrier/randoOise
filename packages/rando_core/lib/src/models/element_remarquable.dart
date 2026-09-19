import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Moderation state of a point of interest proposed by a hiker.
enum ElementStatut {
  enAttente('en_attente', 'En attente', Color(0xFFB7791F)),
  valide('valide', 'Validé', Color(0xFF2F855A)),
  refuse('refuse', 'Refusé', Color(0xFF718096));

  const ElementStatut(this.code, this.label, this.color);
  final String code;
  final String label;
  final Color color;

  static ElementStatut fromCode(String? code) => ElementStatut.values
      .firstWhere((s) => s.code == code, orElse: () => ElementStatut.enAttente);
}

enum ElementCategorie {
  patrimoine('patrimoine', 'Patrimoine (lavoir, puits, église…)', Icons.account_balance_outlined),
  panorama('panorama', 'Point de vue', Icons.landscape_outlined),
  nature('nature', 'Faune / flore remarquable', Icons.eco_outlined),
  arbre('arbre', 'Arbre remarquable', Icons.park_outlined),
  eau('eau', "Point d'eau, rivière, étang", Icons.water_outlined),
  repos('repos', 'Aire de repos / pique-nique', Icons.table_restaurant_outlined),
  autre('autre', 'Autre', Icons.star_outline);

  const ElementCategorie(this.code, this.label, this.icon);
  final String code;
  final String label;
  final IconData icon;

  static ElementCategorie fromCode(String? code) => ElementCategorie.values
      .firstWhere((c) => c.code == code, orElse: () => ElementCategorie.autre);
}

/// "Élément remarquable": a point of interest proposed by a hiker and
/// validated by the admin before being shown to everyone.
class ElementRemarquable {
  const ElementRemarquable({
    required this.id,
    required this.itineraireId,
    required this.itineraireNom,
    required this.sourceId,
    required this.categorie,
    required this.titre,
    required this.description,
    required this.position,
    required this.statut,
    required this.auteurId,
    this.createdAt,
    this.validePar,
    this.valideAt,
  });

  final String id;
  final String itineraireId;
  final String itineraireNom;
  final String sourceId;
  final ElementCategorie categorie;
  final String titre;
  final String description;
  final LatLng position;
  final ElementStatut statut;
  final String auteurId;
  final DateTime? createdAt;
  final String? validePar;
  final DateTime? valideAt;

  bool get isValide => statut == ElementStatut.valide;
  bool isAuthor(String? uid) => uid != null && auteurId == uid;

  Map<String, dynamic> toCreateMap() => {
        'itineraireId': itineraireId,
        'itineraireNom': itineraireNom,
        'sourceId': sourceId,
        'categorie': categorie.code,
        'titre': titre,
        'description': description,
        'position': GeoPoint(position.latitude, position.longitude),
        'statut': ElementStatut.enAttente.code,
        'auteurId': auteurId,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory ElementRemarquable.fromMap(String id, Map<String, dynamic> m) {
    final gp = m['position'] as GeoPoint?;
    return ElementRemarquable(
      id: id,
      itineraireId: (m['itineraireId'] ?? '') as String,
      itineraireNom: (m['itineraireNom'] ?? '') as String,
      sourceId: (m['sourceId'] ?? '') as String,
      categorie: ElementCategorie.fromCode(m['categorie'] as String?),
      titre: (m['titre'] ?? '') as String,
      description: (m['description'] ?? '') as String,
      position: gp == null ? const LatLng(0, 0) : LatLng(gp.latitude, gp.longitude),
      statut: ElementStatut.fromCode(m['statut'] as String?),
      auteurId: (m['auteurId'] ?? '') as String,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      validePar: m['validePar'] as String?,
      valideAt: (m['valideAt'] as Timestamp?)?.toDate(),
    );
  }
}
