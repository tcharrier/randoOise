import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';
import '../services/tile_cache.dart';
import '../util/format.dart';
import '../widgets/itineraire_card.dart';
import '../widgets/route_map.dart';
import '../widgets/ui.dart';
import 'circuits_screen.dart';
import 'itineraire_detail_screen.dart';
import 'sheets.dart';
import 'signalement_form_screen.dart';

/// Full-screen map of all routes with a draggable sheet of nearby circuits.
class CarteScreen extends StatefulWidget {
  const CarteScreen({super.key});

  @override
  State<CarteScreen> createState() => _CarteScreenState();
}

class _CarteScreenState extends State<CarteScreen> {
  final _map = MapController();
  final _sheet = DraggableScrollableController();
  String? _selectedId;
  bool _fitted = false;
  static const _sheetInitial = 0.3;

  @override
  void dispose() {
    _map.dispose();
    _sheet.dispose();
    super.dispose();
  }

  void _open(Itineraire it) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ItineraireDetailScreen(itineraireId: it.id),
    ),
  );

  void _select(Itineraire it) {
    setState(() => _selectedId = it.id);
    _map.fitCamera(
      CameraFit.bounds(
        bounds: toLatLngBounds(it.bounds.pad(150)),
        padding: const EdgeInsets.fromLTRB(40, 120, 40, 220),
      ),
    );
  }

  void _fitAll(List<Itineraire> list) {
    if (list.isEmpty) return;
    final b = list.map((e) => e.bounds).reduce((a, c) => a.extend(c));
    _map.fitCamera(
      CameraFit.bounds(
        bounds: toLatLngBounds(b),
        padding: const EdgeInsets.fromLTRB(40, 120, 40, 220),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final list = state.sortedItineraires;
    final selected = _selectedId == null
        ? null
        : state.itineraireById(_selectedId!);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final scale = MediaQuery.textScalerOf(context);
    final sheetBottom = bottomInset;
    final sheetHeight =
        (MediaQuery.sizeOf(context).height - sheetBottom) * _sheetInitial;

    // Routes arrive asynchronously: fit the camera once they are known.
    if (!_fitted && list.isNotEmpty) {
      _fitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitAll(list);
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          RouteMap(
            controller: _map,
            itineraires: list,
            highlighted: selected,
            showLabels: true,
            labelBuilder: (it) => '${it.nom} · ${formatDistance(it.lengthM)}',
            signalements: state.showSignalementsOnMap
                ? state.signalements
                : const [],
            elements: state.showElementsOnMap
                ? state.validatedElements
                : const [],
            origin: state.originMode == OriginMode.manual
                ? state.manualOrigin
                : null,
            onRouteTap: (it) => _selectedId == it.id ? _open(it) : _select(it),
            onSignalementTap: (s) => showSignalementSheet(context, s),
            onElementTap: (e) => showElementSheet(context, e),
            onMapTap: (_) => setState(() => _selectedId = null),
            onMapLongPress: (p) {
              state.setManualOrigin(p);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Origine définie : les circuits sont triés depuis ce point.',
                  ),
                ),
              );
            },
          ),

          // Title card
          Positioned(
            left: 16,
            top: 0,
            right: 84,
            child: SafeArea(
              bottom: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 10),
                    child: RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      label: 'Retour',
                      elevated: true,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Flexible(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 14,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Carte', style: theme.textTheme.headlineMedium),
                          Text(
                            '${plural(list.length, 'circuit')} · ${state.originLabel.toLowerCase()}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // "+" report button
          Positioned(
            right: 16,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: RoundIconButton(
                  icon: Icons.add_rounded,
                  label: 'Signaler un problème',
                  filled: true,
                  elevated: true,
                  size: 56,
                  onPressed: list.isEmpty
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                SignalementFormScreen(itineraire: selected),
                          ),
                        ),
                ),
              ),
            ),
          ),

          // Right controls
          Positioned(
            right: 16,
            bottom: sheetBottom + sheetHeight + 16,
            child: Column(
              children: [
                RoundIconButton(
                  icon: Icons.near_me_rounded,
                  label: 'Centrer sur ma position',
                  elevated: true,
                  onPressed: () async {
                    await state.refreshGps();
                    final p = state.gpsPosition;
                    if (p != null) {
                      _map.move(p, 13);
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Position GPS indisponible.'),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 10),
                _LayersButton(state: state),
                const SizedBox(height: 10),
                RoundIconButton(
                  icon: Icons.fit_screen_rounded,
                  label: 'Voir tous les circuits',
                  elevated: true,
                  onPressed: () {
                    setState(() => _selectedId = null);
                    _fitAll(list);
                  },
                ),
              ],
            ),
          ),

          // Bottom sheet
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(bottom: sheetBottom),
              child: DraggableScrollableSheet(
                controller: _sheet,
                initialChildSize: _sheetInitial,
                minChildSize: 0.16,
                maxChildSize: 0.85,
                snap: true,
                snapSizes: const [_sheetInitial, 0.85],
                builder: (context, scroll) => Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                            color: scheme.outline,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      SectionHeader(
                        selected == null
                            ? (state.origin == null
                                  ? 'Circuits'
                                  : 'Près de toi')
                            : 'Circuit sélectionné',
                        actionLabel: 'Liste',
                        onAction: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CircuitsScreen(),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
                      ),
                      if (selected != null) ...[
                        ItineraireCard(
                          itineraire: selected,
                          onTap: () => _open(selected),
                        ),
                        const SizedBox(height: 12),
                      ] else if (list.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Aucun circuit chargé pour le moment.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        )
                      else
                        SizedBox(
                          height: scale.scale(160),
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            clipBehavior: Clip.none,
                            itemCount: list.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 12),
                            itemBuilder: (_, i) => ItineraireTile(
                              itineraire: list[i],
                              width: 188,
                              onTap: () => _select(list[i]),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        'Tous les circuits',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      for (final it in list) ...[
                        ItineraireCard(itineraire: it, onTap: () => _open(it)),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LayersButton extends StatelessWidget {
  const _LayersButton({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Couches de la carte',
      offset: const Offset(-60, 0),
      onSelected: (v) {
        switch (v) {
          case 'sig':
            state.toggleShowSignalements();
          case 'elem':
            state.toggleShowElements();
          default:
            state.offline.setStyle(MapStyle.byId(v));
        }
      },
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: 'sig',
          checked: state.showSignalementsOnMap,
          child: const Text('Signalements'),
        ),
        CheckedPopupMenuItem(
          value: 'elem',
          checked: state.showElementsOnMap,
          child: const Text('Éléments remarquables'),
        ),
        const PopupMenuDivider(),
        for (final s in MapStyle.all)
          CheckedPopupMenuItem(
            value: s.id,
            checked: state.offline.style.id == s.id,
            child: Text(s.label),
          ),
      ],
      child: const RoundIconButton(
        icon: Icons.layers_rounded,
        label: 'Couches de la carte',
        elevated: true,
      ),
    );
  }
}
