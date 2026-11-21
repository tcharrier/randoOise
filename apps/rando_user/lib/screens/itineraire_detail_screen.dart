import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../services/offline_service.dart';
import '../widgets/element_tile.dart';
import '../widgets/itineraire_card.dart';
import '../widgets/route_map.dart';
import '../widgets/signalement_tile.dart';
import '../widgets/ui.dart';
import 'element_form_screen.dart';
import 'navigation_screen.dart';
import 'sheets.dart';
import 'signalement_form_screen.dart';
import 'sorties_screen.dart';

class ItineraireDetailScreen extends StatelessWidget {
  const ItineraireDetailScreen({super.key, required this.itineraireId});

  final String itineraireId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final it = state.itineraireById(itineraireId);
    if (it == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Itinéraire introuvable.')));
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fav = state.isFavorite(it.id);
    final signalements = state.signalementsFor(it.id);
    final elements = state.elementsFor(it.id);
    final validated = elements.where((e) => e.isValide).length;
    final distance = state.distanceFromOrigin(it);
    final velo = it.isVelo;

    void openNavigation() => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => NavigationScreen(itineraireId: it.id)),
        );

    final subtitle = [
      if (velo) it.trajetLabel ?? it.sourceName else if (it.communesLabel.isNotEmpty) it.communesLabel else it.sourceName,
      if (distance != null) 'à ${formatDistance(distance)}',
    ].whereType<String>().join(' · ');

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Row(
              children: [
                RoundIconButton(icon: Icons.arrow_back_rounded, label: 'Retour', onPressed: () => Navigator.of(context).pop()),
                const Spacer(),
                RoundIconButton(
                  icon: fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  label: fav ? 'Retirer des favoris' : 'Ajouter aux favoris',
                  active: fav,
                  onPressed: () => state.toggleFavorite(it.id),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(it.titre, style: theme.textTheme.displaySmall),
            const SizedBox(height: 6),
            Text(subtitle, style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),

            // Map card
            Semantics(
              button: true,
              label: 'Ouvrir la carte et suivre l’itinéraire',
              child: GestureDetector(
                onTap: openNavigation,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(RandoRadius.card),
                  child: SizedBox(
                    height: 260,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RouteMap(
                          itineraires: [it],
                          highlightedId: it.id,
                          markers: [
                            if (state.showSignalementsOnMap) for (final s in signalements) signalementMarker(s),
                            if (state.showElementsOnMap) for (final e in elements.where((e) => e.isValide)) elementMarker(e),
                          ],
                          interactive: false,
                          fitPadding: const EdgeInsets.all(30),
                        ),
                        Positioned(
                          left: 12,
                          top: 12,
                          child: MapLabel('${formatDistance(it.lengthM)} · ${formatDurationH(it.dureeH)}', icon: it.activite.icon),
                        ),
                        const Positioned(right: 12, bottom: 12, child: MapLabel('Agrandir', icon: Icons.open_in_full_rounded)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _StatsRow(it: it),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActiviteChip(it.activite, dense: false),
                RouteStatusChip(it, dense: false),
                if (it.typeItineraire != null) StatusChip(label: it.typeItineraire!, color: RandoColors.inkSoft, icon: Icons.loop_rounded),
                if (velo && it.niveau != null)
                  StatusChip(label: it.niveau == 'intercommunal' ? 'Intercommunal' : 'Communal', color: RandoColors.velo, icon: Icons.location_city_rounded),
                if (!velo && it.pratique != null) StatusChip(label: it.pratique!, color: RandoColors.inkSoft, icon: Icons.directions_walk_rounded),
                if (it.balisage != null) StatusChip(label: 'Balisage ${it.balisage}', color: RandoColors.ochre, icon: Icons.signpost_outlined),
                if (it.pdipr) const StatusChip(label: 'Inscrit au PDIPR', color: RandoColors.green, icon: Icons.verified_outlined),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: openNavigation,
              style: velo ? FilledButton.styleFrom(backgroundColor: RandoColors.velo, foregroundColor: Colors.white) : null,
              child: Row(
                children: [
                  const Icon(Icons.navigation_rounded, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(velo ? 'Suivre la piste' : 'Suivre l’itinéraire')),
                  Text(formatDistance(it.lengthM), style: theme.textTheme.labelLarge?.copyWith(color: Colors.white70)),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _OfflineButton(it: it),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SignalementFormScreen(itineraire: it),
                    )),
                    icon: const Icon(Icons.add_alert_rounded),
                    label: const Text('Signaler'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ElementFormScreen(itineraire: it),
                    )),
                    icon: const Icon(Icons.star_rounded),
                    label: const Text('Élément'),
                  ),
                ),
              ],
            ),

            if ((it.presentation ?? it.presentationCourte) != null) ...[
              const SectionHeader('Présentation'),
              _Paragraphs(it.presentation ?? it.presentationCourte!),
            ],
            if (it.instructions != null) ...[
              const SectionHeader('Pas à pas'),
              _Steps(it.instructions!),
            ],

            const SectionHeader('Infos pratiques'),
            ..._practical(it),

            AnimatedBuilder(
              animation: state.sorties,
              builder: (context, _) {
                final mine = state.sorties.forItineraire(it.id);
                if (mine.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader('Tes sorties ici · ${mine.length}'),
                    for (final s in mine.take(3)) ...[
                      SortieTile(sortie: s),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),

            SectionHeader('Signalements · ${signalements.length}'),
            if (signalements.isEmpty)
              Text('Aucun signalement sur ce circuit.', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            for (final s in signalements) ...[
              SignalementTile(signalement: s, showItineraire: false, onTap: () => showSignalementSheet(context, s)),
              const SizedBox(height: 10),
            ],

            SectionHeader('Éléments remarquables · $validated'),
            if (elements.isEmpty)
              Text('Aucun élément remarquable validé pour l’instant. Propose le tien !',
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            for (final e in elements) ...[
              ElementTile(element: e, onTap: () => showElementSheet(context, e)),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _practical(Itineraire it) {
    final velo = it.isVelo;
    final rows = <(IconData, Color, String, String)>[
      if (it.depart != null) (Icons.play_circle_outline_rounded, RandoColors.green, 'Départ', it.depart!),
      if (it.arrivee != null && it.arrivee != it.depart) (Icons.flag_rounded, RandoColors.green, 'Arrivée', it.arrivee!),
      if (velo && it.statutReseau != null) (Icons.traffic_rounded, it.statutReseau!.color, 'État de la piste', it.statutReseau!.label),
      if (velo)
        (Icons.speed_rounded, RandoColors.velo, 'Durée estimée', '${formatDurationH(it.dureeH)} à ${VeloDataset.speedKmh.round()} km/h de moyenne'),
      if (it.parkingInfo != null) (Icons.local_parking_rounded, RandoColors.blue, 'Parking', it.parkingInfo!),
      if (it.transportsCommun != null) (Icons.directions_bus_rounded, RandoColors.blue, 'Transports en commun', it.transportsCommun!),
      if (it.accesRoutier != null) (Icons.directions_car_rounded, RandoColors.blue, 'Accès routier', it.accesRoutier!),
      if (it.accessibilite != null) (Icons.accessible_rounded, RandoColors.ochre, 'Accessibilité', it.accessibilite!),
      if (it.recommandations != null) (Icons.tips_and_updates_rounded, RandoColors.ochre, 'Recommandations', it.recommandations!),
      if (it.typeSol != null) (Icons.layers_rounded, RandoColors.ochre, 'Type de sol', it.typeSol!),
      if (it.themes.isNotEmpty) (Icons.label_rounded, RandoColors.inkSoft, 'Thèmes', it.themes.join(', ')),
      if (it.altMin != null && it.altMax != null && it.altMax! > 0)
        (Icons.height_rounded, RandoColors.inkSoft, 'Altitude', '${it.altMin!.round()} m – ${it.altMax!.round()} m'),
      if (it.dateModification != null || it.dateCreation != null)
        (Icons.update_rounded, RandoColors.inkSoft, 'Mise à jour', it.dateModification ?? it.dateCreation!),
      (Icons.source_rounded, RandoColors.inkSoft, 'Source', it.embedded ? '${it.sourceName} · intégré à l’app' : it.sourceName),
    ];
    return [
      for (final (icon, color, title, value) in rows) ...[
        InfoRowCard(icon: icon, color: color, title: title, subtitle: value),
        const SizedBox(height: 10),
      ],
      if (it.url != null)
        InfoRowCard(
          icon: Icons.link_rounded,
          color: RandoColors.blue,
          title: 'Données en ligne',
          subtitle: it.url,
          chevron: true,
          onTap: () => launchUrl(Uri.parse(it.url!), mode: LaunchMode.externalApplication),
        ),
    ];
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.it});
  final Itineraire it;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String)>[
      (Icons.straighten_rounded, 'Distance', formatDistance(it.lengthM)),
      (Icons.schedule_rounded, it.isVelo ? 'À 18 km/h' : 'Durée', formatDurationH(it.dureeH)),
      if (it.denivelePositif != null) (Icons.trending_up_rounded, 'Dénivelé +', '${it.denivelePositif!.round()} m'),
      if (it.deniveleNegatif != null) (Icons.trending_down_rounded, 'Dénivelé −', '${it.deniveleNegatif!.round()} m'),
      if (it.isVelo && it.denivelePositif == null) (Icons.route_rounded, 'Tronçons', '${it.tracks.length}'),
    ];
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        child: Row(
          children: [
            for (final (icon, label, value) in items)
              Expanded(
                child: Column(
                  children: [
                    Icon(icon, color: it.isVelo ? RandoColors.velo : theme.colorScheme.primary),
                    const SizedBox(height: 6),
                    Text(value, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
                    Text(label, style: theme.textTheme.labelSmall, textAlign: TextAlign.center),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Enregistrer hors ligne" toggle: downloads the map area of the route
/// with MapLibre offline regions. Embedded cycling routes already carry
/// their track; the map tiles can still be saved.
class _OfflineButton extends StatelessWidget {
  const _OfflineButton({required this.it});
  final Itineraire it;

  @override
  Widget build(BuildContext context) {
    final offline = context.watch<AppState>().offline;
    return AnimatedBuilder(
      animation: offline,
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        if (!OfflineService.supported) {
          return Text('Le hors-ligne est disponible dans l’application mobile.', style: theme.textTheme.bodySmall);
        }
        Widget button;
        if (offline.isDownloading(it.id)) {
          final p = offline.progress[it.id] ?? 0;
          button = OutlinedButton(
            onPressed: null,
            child: Row(
              children: [
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(value: p == 0 ? null : p, strokeWidth: 2.5)),
                const SizedBox(width: 12),
                Expanded(child: Text('Téléchargement de la carte… ${(p * 100).round()} %')),
              ],
            ),
          );
        } else if (offline.isSaved(it.id)) {
          button = OutlinedButton.icon(
            onPressed: () => _forget(context, offline),
            icon: Icon(Icons.offline_pin_rounded, color: scheme.primary),
            label: const Text('Enregistré hors ligne · retirer'),
          );
        } else {
          button = OutlinedButton.icon(
            onPressed: () => _save(context, offline),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Enregistrer la carte hors ligne'),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            button,
            if (it.embedded)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text('Le tracé de cette piste est intégré à l’app : il reste disponible sans réseau.',
                    style: theme.textTheme.bodySmall),
              ),
          ],
        );
      },
    );
  }

  Future<void> _save(BuildContext context, OfflineService offline) async {
    final messenger = ScaffoldMessenger.of(context);
    final res = await offline.save(it);
    messenger.showSnackBar(SnackBar(
      content: Text(res.message),
    ));
  }

  Future<void> _forget(BuildContext context, OfflineService offline) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer la carte hors ligne ?'),
        content: Text('Les tuiles de carte de « ${it.titre} » seront supprimées de l’appareil.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Retirer')),
        ],
      ),
    );
    if (ok == true) await offline.forget(it.id);
  }
}

class _Paragraphs extends StatelessWidget {
  const _Paragraphs(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final parts = text.split(RegExp(r'\n\s*\n')).map((e) => e.trim()).where((e) => e.isNotEmpty);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in parts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(p, style: Theme.of(context).textTheme.bodyLarge),
              ),
          ],
        ),
      ),
    );
  }
}

/// Numbered steps ("1 - ...", "2 - ...") shown as a vertical timeline.
class _Steps extends StatelessWidget {
  const _Steps(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final normalised = text.replaceAllMapped(RegExp(r'\s+(?=\d{1,2}\s*[-–.)]\s)'), (_) => '\n');
    final lines = normalised.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final steps = <(String?, String)>[];
    for (final l in lines) {
      final m = RegExp(r'^(\d{1,2})\s*[-–.)]\s*(.*)$').firstMatch(l);
      steps.add(m == null ? (null, l) : (m.group(1), m.group(2)!));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 18, 10),
        child: Column(
          children: [
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: steps[i].$1 == null ? scheme.surfaceContainer : scheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        steps[i].$1 ?? '•',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: steps[i].$1 == null ? scheme.onSurface : scheme.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(steps[i].$2, style: theme.textTheme.bodyLarge)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
