import 'package:flutter/material.dart';
import 'package:rando_core/rando_core.dart';

import '../utils/date_format.dart';
import 'route_map_view.dart';

/// Full read-only detail of a route: map, key figures and every text field
/// coming from the national schema, plus its reports / points of interest.
class ItineraireDetail extends StatelessWidget {
  const ItineraireDetail({
    super.key,
    required this.itineraire,
    required this.signalements,
    required this.elements,
    this.onClose,
  });

  final Itineraire itineraire;
  final List<Signalement> signalements;
  final List<ElementRemarquable> elements;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final it = itineraire;
    final textTheme = Theme.of(context).textTheme;
    final validatedElements =
        elements.where((e) => e.statut == ElementStatut.valide).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(it.nom,
                  style: textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            if (onClose != null)
              IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
          ],
        ),
        Text('Source : ${it.sourceName}',
            style: textTheme.bodyMedium
                ?.copyWith(color: RandoColors.inkMuted)),
        const SizedBox(height: 14),
        RouteMapView(
          itineraire: it,
          signalements: signalements,
          elements: validatedElements,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DifficultyChip(it.difficulte),
            StatusChip(
                label: formatDistance(it.lengthM),
                color: RandoColors.forest,
                icon: Icons.straighten),
            StatusChip(
                label: formatDurationH(it.dureeH),
                color: RandoColors.water,
                icon: Icons.schedule),
            if (it.denivelePositif != null)
              StatusChip(
                  label: 'D+ ${it.denivelePositif!.round()} m',
                  color: RandoColors.ochre,
                  icon: Icons.trending_up),
            if (it.deniveleNegatif != null)
              StatusChip(
                  label: 'D- ${it.deniveleNegatif!.round()} m',
                  color: RandoColors.ochre,
                  icon: Icons.trending_down),
            if (it.pdipr)
              const StatusChip(
                  label: 'Inscrit au PDIPR',
                  color: RandoColors.forest,
                  icon: Icons.verified_outlined),
          ],
        ),
        if (it.communes.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'Communes',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in it.communes)
                  Chip(label: Text(c), visualDensity: VisualDensity.compact),
              ],
            ),
          ),
        ],
        if (it.themes.isNotEmpty)
          _Section(
            title: 'Thèmes',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in it.themes)
                  Chip(label: Text(t), visualDensity: VisualDensity.compact),
              ],
            ),
          ),
        _Section(
          title: 'Caractéristiques',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('Pratique', it.pratique),
              _kv('Type d\'itinéraire', it.typeItineraire),
              _kv('Balisage', it.balisage),
              _kv('Type de sol', it.typeSol),
              _kv('Altitude min / max', it.altMin == null && it.altMax == null
                  ? null
                  : '${it.altMin?.round() ?? '–'} m / ${it.altMax?.round() ?? '–'} m'),
              _kv('Départ', it.depart),
              _kv('Arrivée', it.arrivee),
            ],
          ),
        ),
        _Section(
          title: 'Présentation',
          child: _text(it.presentationCourte, fallback: it.presentation),
        ),
        if (it.presentationCourte != null && it.presentation != null)
          _Section(title: 'Présentation détaillée', child: _text(it.presentation)),
        _Section(title: 'Instructions', child: _text(it.instructions)),
        _Section(title: 'Recommandations', child: _text(it.recommandations)),
        _Section(title: 'Accessibilité', child: _text(it.accessibilite)),
        _Section(title: 'Accès routier', child: _text(it.accesRoutier)),
        _Section(title: 'Transports en commun', child: _text(it.transportsCommun)),
        _Section(title: 'Stationnement', child: _text(it.parkingInfo)),
        _Section(
          title: 'Dates',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('Créé le', it.dateCreation),
              _kv('Modifié le', it.dateModification),
            ],
          ),
        ),
        if (it.url != null) _Section(title: 'Lien', child: _text(it.url)),
        _Section(
          title: 'Signalements (${signalements.length})',
          child: signalements.isEmpty
              ? const Text('Aucun signalement sur cet itinéraire.')
              : Column(
                  children: [
                    for (final s in signalements)
                      _SignalementLine(signalement: s),
                  ],
                ),
        ),
        _Section(
          title: 'Éléments remarquables validés (${validatedElements.length})',
          child: validatedElements.isEmpty
              ? const Text('Aucun élément validé sur cet itinéraire.')
              : Column(
                  children: [
                    for (final e in validatedElements) _ElementLine(element: e),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _kv(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: RandoColors.ink, fontSize: 14),
          children: [
            TextSpan(
                text: '$label : ',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _text(String? value, {String? fallback}) {
    final v = (value == null || value.isEmpty) ? fallback : value;
    if (v == null || v.isEmpty) {
      return const Text('Non renseigné', style: TextStyle(color: RandoColors.inkMuted));
    }
    return Text(v, style: const TextStyle(height: 1.4));
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _SignalementLine extends StatelessWidget {
  const _SignalementLine({required this.signalement});
  final Signalement signalement;

  @override
  Widget build(BuildContext context) {
    final s = signalement;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(s.categorie.icon, size: 18, color: RandoColors.inkMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.categorie.label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(s.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(formatDateTime(s.createdAt),
                    style: const TextStyle(fontSize: 12, color: RandoColors.inkMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(label: s.statut.label, color: s.statut.color, dense: true),
        ],
      ),
    );
  }
}

class _ElementLine extends StatelessWidget {
  const _ElementLine({required this.element});
  final ElementRemarquable element;

  @override
  Widget build(BuildContext context) {
    final e = element;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(e.categorie.icon, size: 18, color: RandoColors.inkMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.titre, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(e.description, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
