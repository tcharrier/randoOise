import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../widgets/itineraire_card.dart';
import '../widgets/ui.dart';
import 'itineraire_detail_screen.dart';

/// Searchable, sortable list of every route (hikes and cycling lanes).
class CircuitsScreen extends StatefulWidget {
  const CircuitsScreen({super.key, this.autofocusSearch = false});
  final bool autofocusSearch;

  @override
  State<CircuitsScreen> createState() => _CircuitsScreenState();
}

class _CircuitsScreenState extends State<CircuitsScreen> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    final st = context.read<AppState>();
    _search = TextEditingController(text: st.search);
    if (st.sourceFilter != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => st.setSourceFilter(null));
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final list = state.visibleItineraires;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(
              title: 'Circuits',
              subtitle: '${list.length} circuit${list.length > 1 ? 's' : ''} · ${state.originLabel}',
              leading: RoundIconButton(
                icon: Icons.arrow_back_rounded,
                label: 'Retour',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: TextField(
                controller: _search,
                autofocus: widget.autofocusSearch,
                onChanged: state.setSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Nom, commune, départ, arrivée…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: state.search.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Effacer',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _search.clear();
                            state.setSearch('');
                          },
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Align(alignment: Alignment.centerLeft, child: SourceFilterChips(state: state)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: PopupMenuButton<OriginMode>(
                  tooltip: 'Ordre de tri',
                  onSelected: state.setOriginMode,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: OriginMode.gps, child: Text('Depuis ma position')),
                    PopupMenuItem(value: OriginMode.manual, child: Text('Depuis un point choisi sur la carte')),
                    PopupMenuItem(value: OriginMode.none, child: Text('Par nom')),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.swap_vert_rounded, size: 18),
                    label: Text(state.originLabel),
                  ),
                ),
              ),
            ),
            Expanded(
              child: !state.itinerairesLoaded
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                      ? EmptyState(
                          icon: Icons.hiking_rounded,
                          title: state.itineraires.isEmpty ? 'Aucun circuit disponible' : 'Aucun résultat',
                          subtitle: state.itineraires.isEmpty
                              ? 'Connecte-toi à internet une première fois pour télécharger les circuits.'
                              : 'Modifie ta recherche ou les filtres.',
                        )
                      : RefreshIndicator(
                          onRefresh: state.refreshGps,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                            itemCount: list.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => ItineraireCard(
                              itineraire: list[i],
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ItineraireDetailScreen(itineraireId: list[i].id),
                              )),
                            ),
                          ),
                        ),
            ),
            if (state.itinerairesFromCache && state.itinerairesLoaded)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Hors ligne : données enregistrées sur l’appareil', style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}
