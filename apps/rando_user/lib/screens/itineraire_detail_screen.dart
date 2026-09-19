import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../services/offline_service.dart';
import '../widgets/element_tile.dart';
import '../widgets/route_map.dart';
import '../widgets/signalement_tile.dart';
import 'element_form_screen.dart';
import 'sheets.dart';
import 'signalement_form_screen.dart';
import 'tracking_screen.dart';

class ItineraireDetailScreen extends StatelessWidget {
  const ItineraireDetailScreen({super.key, required this.itineraireId});

  final String itineraireId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final it = state.itineraireById(itineraireId);
    if (it == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Itinéraire introuvable.')),
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fav = state.isFavorite(it.id);
    final signalements = state.signalementsFor(it.id);
    final elements = state.elementsFor(it.id);

    void openTracking() => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TrackingScreen(itineraireId: it.id)),
        );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 260,
            actions: [
              IconButton(
                tooltip: fav ? 'Retirer des favoris' : 'Ajouter aux favoris',
                onPressed: () => state.toggleFavorite(it.id),
                icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                    color: fav ? RandoColors.danger : null),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: GestureDetector(
                onTap: openTracking,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RouteMap(
                      itineraires: [it],
                      highlighted: it,
                      signalements: state.showSignalementsOnMap ? signalements : const [],
                      elements: state.showElementsOnMap ? elements.where((e) => e.isValide).toList() : const [],
                      interactive: false,
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Chip(
                        avatar: const Icon(Icons.open_in_full, size: 16),
                        label: const Text('Agrandir'),
                        backgroundColor: scheme.surface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            sliver: SliverList.list(children: [
              Text(it.nom, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(it.communesLabel.isEmpty ? it.sourceName : it.communesLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 14),
              _StatsRow(it: it),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  DifficultyChip(it.difficulte),
                  if (it.typeItineraire != null)
                    StatusChip(label: it.typeItineraire!, color: RandoColors.inkMuted, icon: Icons.loop),
                  if (it.pratique != null)
                    StatusChip(label: it.pratique!, color: RandoColors.inkMuted, icon: Icons.directions_walk),
                  if (it.balisage != null)
                    StatusChip(label: 'Balisage ${it.balisage}', color: RandoColors.ochre, icon: Icons.signpost_outlined),
                  if (it.pdipr)
                    const StatusChip(label: 'Inscrit au PDIPR', color: RandoColors.forest, icon: Icons.verified_outlined),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: openTracking,
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('Démarrer le suivi GPS'),
              ),
              const SizedBox(height: 8),
              _OfflineButton(it: it),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SignalementFormScreen(itineraire: it),
                      )),
                      icon: const Icon(Icons.add_alert_outlined),
                      label: const Text('Signaler'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ElementFormScreen(itineraire: it),
                      )),
                      icon: const Icon(Icons.star_outline),
                      label: const Text('Élément'),
                    ),
                  ),
                ],
              ),
              if ((it.presentation ?? it.presentationCourte) != null) ...[
                _SectionTitle('Présentation'),
                _Paragraphs(it.presentation ?? it.presentationCourte!),
              ],
              if (it.instructions != null) ...[
                _SectionTitle('Pas à pas'),
                _Paragraphs(it.instructions!),
              ],
              _SectionTitle('Infos pratiques'),
              Card(
                child: Column(
                  children: [
                    if (it.depart != null) _InfoRow(Icons.play_circle_outline, 'Départ', it.depart!),
                    if (it.arrivee != null) _InfoRow(Icons.flag_outlined, 'Arrivée', it.arrivee!),
                    if (it.parkingInfo != null) _InfoRow(Icons.local_parking, 'Parking', it.parkingInfo!),
                    if (it.transportsCommun != null) _InfoRow(Icons.directions_bus_outlined, 'Transports', it.transportsCommun!),
                    if (it.accesRoutier != null) _InfoRow(Icons.directions_car_outlined, 'Accès routier', it.accesRoutier!),
                    if (it.accessibilite != null) _InfoRow(Icons.accessible, 'Accessibilité', it.accessibilite!),
                    if (it.recommandations != null) _InfoRow(Icons.tips_and_updates_outlined, 'Recommandations', it.recommandations!),
                    if (it.typeSol != null) _InfoRow(Icons.layers_outlined, 'Type de sol', it.typeSol!),
                    if (it.themes.isNotEmpty) _InfoRow(Icons.label_outline, 'Thèmes', it.themes.join(', ')),
                    if (it.altMin != null && it.altMax != null)
                      _InfoRow(Icons.height, 'Altitude', '${it.altMin!.round()} m – ${it.altMax!.round()} m'),
                    if (it.dateModification != null || it.dateCreation != null)
                      _InfoRow(Icons.update, 'Mise à jour', it.dateModification ?? it.dateCreation!),
                    _InfoRow(Icons.source_outlined, 'Source', it.sourceName),
                    if (it.url != null)
                      ListTile(
                        leading: const Icon(Icons.link),
                        title: const Text('Fiche en ligne'),
                        subtitle: Text(it.url!, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => launchUrl(Uri.parse(it.url!), mode: LaunchMode.externalApplication),
                      ),
                  ],
                ),
              ),
              _SectionTitle('Signalements (${signalements.length})'),
              if (signalements.isEmpty)
                Text('Aucun signalement sur ce circuit.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              for (final s in signalements) ...[
                SignalementTile(
                  signalement: s,
                  showItineraire: false,
                  onTap: () => showSignalementSheet(context, s),
                ),
                const SizedBox(height: 8),
              ],
              _SectionTitle('Éléments remarquables (${elements.where((e) => e.isValide).length})'),
              if (elements.isEmpty)
                Text('Aucun élément remarquable validé pour l’instant. Proposez-en un !',
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              for (final e in elements) ...[
                ElementTile(element: e, onTap: () => showElementSheet(context, e)),
                const SizedBox(height: 8),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.it});
  final Itineraire it;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String)>[
      (Icons.straighten, 'Distance', formatDistance(it.lengthM)),
      (Icons.schedule, 'Durée', formatDurationH(it.dureeH)),
      if (it.denivelePositif != null) (Icons.trending_up, 'Dénivelé +', '${it.denivelePositif!.round()} m'),
      if (it.deniveleNegatif != null) (Icons.trending_down, 'Dénivelé −', '${it.deniveleNegatif!.round()} m'),
    ];
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            for (final (icon, label, value) in items)
              Expanded(
                child: Column(
                  children: [
                    Icon(icon, color: theme.colorScheme.primary),
                    const SizedBox(height: 4),
                    Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OfflineButton extends StatelessWidget {
  const _OfflineButton({required this.it});
  final Itineraire it;

  @override
  Widget build(BuildContext context) {
    final offline = context.watch<AppState>().offline;
    return AnimatedBuilder(
      animation: offline,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        if (offline.isDownloading(it.id)) {
          final p = offline.progress[it.id] ?? 0;
          return OutlinedButton(
            onPressed: () => offline.cancel(it.id),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(value: p, strokeWidth: 2.5),
                ),
                const SizedBox(width: 10),
                Text('Téléchargement de la carte… ${(p * 100).round()} %  (annuler)'),
              ],
            ),
          );
        }
        if (offline.isDownloaded(it.id)) {
          return OutlinedButton.icon(
            onPressed: () => _download(context, offline),
            icon: Icon(Icons.offline_pin, color: scheme.primary),
            label: const Text('Disponible hors ligne · mettre à jour'),
          );
        }
        return OutlinedButton.icon(
          onPressed: () => _download(context, offline),
          icon: const Icon(Icons.download_for_offline_outlined),
          label: Text('Télécharger la carte hors ligne (${offline.tileCount(it)} tuiles)'),
        );
      },
    );
  }

  Future<void> _download(BuildContext context, OfflineService offline) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await offline.download(it);
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Carte enregistrée : ce circuit est utilisable sans réseau.'
          : 'Téléchargement incomplet. Réessayez avec une meilleure connexion.'),
    ));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Text(text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      );
}

class _Paragraphs extends StatelessWidget {
  const _Paragraphs(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    // Split numbered steps ("1 - ...", "2 - ...") onto their own lines.
    final normalised = text.replaceAllMapped(
        RegExp(r'\s+(?=\d{1,2}\s*[-–.)]\s)'), (_) => '\n\n');
    final parts = normalised.split(RegExp(r'\n\s*\n')).map((e) => e.trim()).where((e) => e.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in parts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(p, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4)),
          ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        leading: Icon(icon),
        title: Text(label, style: Theme.of(context).textTheme.labelMedium),
        subtitle: Text(value, style: Theme.of(context).textTheme.bodyMedium),
      );
}
