import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';
import '../widgets/itineraire_card.dart';
import '../widgets/route_map.dart';
import 'itineraire_detail_screen.dart';
import 'settings_screen.dart';
import 'sheets.dart';

class ItinerairesTab extends StatefulWidget {
  const ItinerairesTab({super.key});

  @override
  State<ItinerairesTab> createState() => _ItinerairesTabState();
}

class _ItinerairesTabState extends State<ItinerairesTab> {
  bool _mapMode = false;
  final _mapController = MapController();
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _openDetail(Itineraire it) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ItineraireDetailScreen(itineraireId: it.id),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final list = state.visibleItineraires;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rando Oise'),
        actions: [
          IconButton(
            tooltip: 'Réglages',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: state.setSearch,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un circuit, une commune…',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    suffixIcon: state.search.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchCtrl.clear();
                              state.setSearch('');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: const [
                        ButtonSegment(value: false, icon: Icon(Icons.list), label: Text('Liste')),
                        ButtonSegment(value: true, icon: Icon(Icons.map_outlined), label: Text('Carte')),
                      ],
                      selected: {_mapMode},
                      onSelectionChanged: (s) => setState(() => _mapMode = s.first),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _OriginChip(state: state)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (state.sources.length > 1)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('Toutes les sources'),
                      selected: state.sourceFilter == null,
                      onSelected: (_) => state.setSourceFilter(null),
                    ),
                  ),
                  for (final s in state.sources.where((s) => s.enabled))
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(s.name),
                        selected: state.sourceFilter == s.id,
                        onSelected: (_) => state.setSourceFilter(s.id),
                      ),
                    ),
                ],
              ),
            ),
          if (state.itinerairesFromCache && state.itinerairesLoaded)
            _InfoBanner(
              icon: Icons.cloud_off,
              text: 'Hors ligne : données enregistrées sur l’appareil.',
              color: scheme.onSurfaceVariant,
            ),
          if (state.loadError != null && !state.itinerairesLoaded)
            _InfoBanner(
              icon: Icons.error_outline,
              text: 'Impossible de charger les itinéraires : ${state.loadError}',
              color: scheme.error,
            ),
          Expanded(
            child: !state.itinerairesLoaded
                ? const Center(child: CircularProgressIndicator())
                : (_mapMode ? _buildMap(state, list) : _buildList(state, list)),
          ),
        ],
      ),
    );
  }

  Widget _buildList(AppState state, List<Itineraire> list) {
    if (list.isEmpty) {
      return _Empty(
        icon: Icons.hiking,
        title: state.itineraires.isEmpty
            ? 'Aucun itinéraire disponible'
            : 'Aucun résultat',
        subtitle: state.itineraires.isEmpty
            ? 'Connectez-vous à internet une première fois pour télécharger les circuits.'
            : 'Modifiez votre recherche ou le filtre de source.',
      );
    }
    return RefreshIndicator(
      onRefresh: state.refreshGps,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => ItineraireCard(
          itineraire: list[i],
          onTap: () => _openDetail(list[i]),
        ),
      ),
    );
  }

  Widget _buildMap(AppState state, List<Itineraire> list) {
    return Stack(
      children: [
        RouteMap(
          controller: _mapController,
          itineraires: list,
          signalements: state.showSignalementsOnMap ? state.signalements : const [],
          elements: state.showElementsOnMap ? state.validatedElements : const [],
          origin: state.origin,
          onRouteTap: _openDetail,
          onSignalementTap: (s) => showSignalementSheet(context, s),
          onElementTap: (e) => showElementSheet(context, e),
          onMapLongPress: (p) {
            state.setManualOrigin(p);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Origine définie : les circuits sont triés depuis ce point.'),
            ));
          },
        ),
        Positioned(
          right: 12,
          top: 12,
          child: Column(
            children: [
              _MapButton(
                icon: Icons.my_location,
                tooltip: 'Ma position',
                onPressed: () async {
                  await state.refreshGps();
                  final p = state.gpsPosition;
                  if (p != null) _mapController.move(p, 13);
                },
              ),
              const SizedBox(height: 8),
              _MapButton(
                icon: state.showSignalementsOnMap ? Icons.report : Icons.report_off_outlined,
                tooltip: 'Afficher les signalements',
                active: state.showSignalementsOnMap,
                onPressed: state.toggleShowSignalements,
              ),
              const SizedBox(height: 8),
              _MapButton(
                icon: state.showElementsOnMap ? Icons.star : Icons.star_border,
                tooltip: 'Afficher les éléments remarquables',
                active: state.showElementsOnMap,
                onPressed: state.toggleShowElements,
              ),
            ],
          ),
        ),
        Positioned(
          left: 12,
          right: 64,
          bottom: 12,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                '${list.length} circuit${list.length > 1 ? 's' : ''} · appui long sur la carte pour choisir une origine',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OriginChip extends StatelessWidget {
  const _OriginChip({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final label = switch (state.originMode) {
      OriginMode.gps => state.gpsPosition == null ? 'Position inconnue' : 'Depuis ma position',
      OriginMode.manual => state.manualOrigin == null ? 'Choisir sur la carte' : 'Depuis le point choisi',
      OriginMode.none => 'Tri par nom',
    };
    return PopupMenuButton<OriginMode>(
      tooltip: 'Origine du tri',
      onSelected: state.setOriginMode,
      itemBuilder: (_) => const [
        PopupMenuItem(value: OriginMode.gps, child: ListTile(leading: Icon(Icons.my_location), title: Text('Depuis ma position'))),
        PopupMenuItem(value: OriginMode.manual, child: ListTile(leading: Icon(Icons.flag_outlined), title: Text('Depuis un point sur la carte'))),
        PopupMenuItem(value: OriginMode.none, child: ListTile(leading: Icon(Icons.sort_by_alpha), title: Text('Tri par nom'))),
      ],
      child: InputChip(
        avatar: Icon(
          switch (state.originMode) {
            OriginMode.gps => Icons.my_location,
            OriginMode.manual => Icons.flag_outlined,
            OriginMode.none => Icons.sort_by_alpha,
          },
          size: 18,
        ),
        label: Text(label, overflow: TextOverflow.ellipsis),
        onPressed: null,
        isEnabled: true,
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.onPressed, this.tooltip, this.active = false});
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: active ? scheme.primaryContainer : scheme.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: active ? scheme.onPrimaryContainer : scheme.onSurface),
        onPressed: onPressed,
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
            ),
          ],
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
