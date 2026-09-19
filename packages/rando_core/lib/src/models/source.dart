import 'package:cloud_firestore/cloud_firestore.dart';

import '../geo/geo.dart';

/// A data source of hiking routes (one imported zip/json file).
class RandoSource {
  const RandoSource({
    required this.id,
    required this.name,
    required this.producteur,
    required this.featureType,
    required this.itineraireCount,
    required this.enabled,
    this.importedAt,
    this.bounds,
    this.fileName,
  });

  final String id;
  final String name;
  final String producteur;
  final String featureType;
  final int itineraireCount;
  final bool enabled;
  final DateTime? importedAt;
  final GeoBounds? bounds;
  final String? fileName;

  Map<String, dynamic> toMap() => {
        'name': name,
        'producteur': producteur,
        'featureType': featureType,
        'itineraireCount': itineraireCount,
        'enabled': enabled,
        'importedAt':
            importedAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(importedAt!),
        'bounds': bounds?.toMap(),
        'fileName': fileName,
      };

  factory RandoSource.fromMap(String id, Map<String, dynamic> m) => RandoSource(
        id: id,
        name: (m['name'] ?? id) as String,
        producteur: (m['producteur'] ?? '') as String,
        featureType: (m['featureType'] ?? '') as String,
        itineraireCount: (m['itineraireCount'] as num?)?.toInt() ?? 0,
        enabled: (m['enabled'] as bool?) ?? true,
        importedAt: (m['importedAt'] as Timestamp?)?.toDate(),
        bounds: GeoBounds.fromMap((m['bounds'] as Map?)?.cast<String, dynamic>()),
        fileName: m['fileName'] as String?,
      );

  RandoSource copyWith({bool? enabled, int? itineraireCount}) => RandoSource(
        id: id,
        name: name,
        producteur: producteur,
        featureType: featureType,
        itineraireCount: itineraireCount ?? this.itineraireCount,
        enabled: enabled ?? this.enabled,
        importedAt: importedAt,
        bounds: bounds,
        fileName: fileName,
      );
}
