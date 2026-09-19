import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../admin_data.dart';
import '../widgets/empty_state.dart';
import '../widgets/itineraire_detail.dart';

enum _SortBy { nom, distance, duree }

/// List of every route with search, source filter and a detail panel
/// (side panel on wide screens, full page on narrow ones).
class ItinerairesScreen extends StatefulWidget {
  const ItinerairesScreen({super.key, required this.onShowOnMap});

  final void Function(LatLng point, {String? title}) onShowOnMap;

  @override
  State<ItinerairesScreen> createState() => _ItinerairesScreenState();
}

class _ItinerairesScreenState extends State<ItinerairesScreen> {
  String _query = '';
  String? _sourceFilter;
  String? _selectedId;
  _SortBy _sortBy = _SortBy.nom;

  List<Itineraire> _filterAndSort(List<Itineraire> all) {
    final q = _query.trim().toLowerCase();
    var list = all.where((it) {
      if (_sourceFilter != null && it.sourceId != _sourceFilter) return false;
      if (q.isEmpty) return true;
      return it.nom.toLowerCase().contains(q) ||
          it.communesLabel.toLowerCase().contains(q);
    }).toList();
    switch (_sortBy) {
      case _SortBy.nom:
        list.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
        break;
      case _SortBy.distance:
        list.sort((a, b) => a.lengthM.compareTo(b.lengthM));
        break;
      case _SortBy.duree:
        list.sort((a, b) => (a.dureeH ?? 0).compareTo(b.dureeH ?? 0));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AdminData>();
    final filtered = _filterAndSort(data.itineraires);

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      final listPanel = _ListPanel(
        query: _query,
        onQueryChanged: (v) => setState(() => _query = v),
        sources: data.sources,
        sourceFilter: _sourceFilter,
        onSourceFilterChanged: (v) => setState(() => _sourceFilter = v),
        sortBy: _sortBy,
        onSortChanged: (v) => setState(() => _sortBy = v),
        items: filtered,
        data: data,
        selectedId: wide ? _selectedId : null,
        onTap: (it) {
          if (wide) {
            setState(() => _selectedId = it.id);
          } else {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: Text(it.nom)),
                body: ItineraireDetail(
                  itineraire: it,
                  signalements: data.signalements
                      .where((s) => s.itineraireId == it.id)
                      .toList(),
                  elements:
                      data.elements.where((e) => e.itineraireId == it.id).toList(),
                ),
              ),
            ));
          }
        },
      );

      if (!wide) return listPanel;

      final selected = _selectedId == null ? null : data.itineraireById(_selectedId!);
      return Row(
        children: [
          SizedBox(width: 420, child: listPanel),
          const VerticalDivider(width: 1),
          Expanded(
            child: selected == null
                ? const EmptyState(
                    message: 'Sélectionnez un itinéraire pour voir le détail.',
                    icon: Icons.route)
                : ItineraireDetail(
                    itineraire: selected,
                    signalements: data.signalements
                        .where((s) => s.itineraireId == selected.id)
                        .toList(),
                    elements: data.elements
                        .where((e) => e.itineraireId == selected.id)
                        .toList(),
                    onClose: () => setState(() => _selectedId = null),
                  ),
          ),
        ],
      );
    });
  }
}

class _ListPanel extends StatelessWidget {
  const _ListPanel({
    required this.query,
    required this.onQueryChanged,
    required this.sources,
    required this.sourceFilter,
    required this.onSourceFilterChanged,
    required this.sortBy,
    required this.onSortChanged,
    required this.items,
    required this.data,
    required this.selectedId,
    required this.onTap,
  });

  final String query;
  final ValueChanged<String> onQueryChanged;
  final List<RandoSource> sources;
  final String? sourceFilter;
  final ValueChanged<String?> onSourceFilterChanged;
  final _SortBy sortBy;
  final ValueChanged<_SortBy> onSortChanged;
  final List<Itineraire> items;
  final AdminData data;
  final String? selectedId;
  final ValueChanged<Itineraire> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: onQueryChanged,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un itinéraire ou une commune…',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<_SortBy>(
                tooltip: 'Trier',
                icon: const Icon(Icons.sort),
                initialValue: sortBy,
                onSelected: onSortChanged,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: _SortBy.nom, child: Text('Trier par nom')),
                  PopupMenuItem(
                      value: _SortBy.distance, child: Text('Trier par distance')),
                  PopupMenuItem(
                      value: _SortBy.duree, child: Text('Trier par durée')),
                ],
              ),
            ],
          ),
        ),
        if (sources.length > 1)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: const Text('Toutes les sources'),
                    selected: sourceFilter == null,
                    onSelected: (_) => onSourceFilterChanged(null),
                  ),
                ),
                for (final s in sources)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(s.name),
                      selected: sourceFilter == s.id,
                      onSelected: (_) => onSourceFilterChanged(s.id),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: items.isEmpty
              ? const EmptyState(
                  message: 'Aucun itinéraire ne correspond à votre recherche.',
                  icon: Icons.route)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final it = items[i];
                    return _ItineraireRow(
                      itineraire: it,
                      selected: it.id == selectedId,
                      signalementCount: data.signalementCount(it.id),
                      elementCount: data.validatedElementCount(it.id),
                      onTap: () => onTap(it),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ItineraireRow extends StatelessWidget {
  const _ItineraireRow({
    required this.itineraire,
    required this.selected,
    required this.signalementCount,
    required this.elementCount,
    required this.onTap,
  });

  final Itineraire itineraire;
  final bool selected;
  final int signalementCount;
  final int elementCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final it = itineraire;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? RandoColors.forestLight : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(it.nom,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text('${it.sourceName} · ${it.communesLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: RandoColors.inkMuted, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  DifficultyChip(it.difficulte, dense: true),
                  StatusChip(
                      label: formatDistance(it.lengthM),
                      color: RandoColors.forest,
                      icon: Icons.straighten,
                      dense: true),
                  StatusChip(
                      label: formatDurationH(it.dureeH),
                      color: RandoColors.water,
                      icon: Icons.schedule,
                      dense: true),
                  if (it.denivelePositif != null)
                    StatusChip(
                        label: 'D+ ${it.denivelePositif!.round()} m',
                        color: RandoColors.ochre,
                        icon: Icons.trending_up,
                        dense: true),
                  if (signalementCount > 0)
                    StatusChip(
                        label: '$signalementCount signalement(s)',
                        color: RandoColors.danger,
                        icon: Icons.report_outlined,
                        dense: true),
                  if (elementCount > 0)
                    StatusChip(
                        label: '$elementCount élément(s)',
                        color: RandoColors.forest,
                        icon: Icons.star_outline,
                        dense: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
