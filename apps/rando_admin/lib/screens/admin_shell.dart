import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../admin_data.dart';
import '../session.dart';
import '../widgets/map_focus.dart';
import 'elements_screen.dart';
import 'itineraires_screen.dart';
import 'map_screen.dart';
import 'signalements_screen.dart';
import 'sources_screen.dart';

/// Responsive shell: NavigationRail on wide screens, NavigationBar on
/// narrow ones. Hosts the five main sections in an [IndexedStack] so each
/// screen keeps its state (search, selection, map camera...) when switching
/// tabs.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  final MapFocusController _mapFocus = MapFocusController();
  late final List<Widget> _screens = [
    ItinerairesScreen(onShowOnMap: _goToMap),
    MapScreen(focusController: _mapFocus),
    SignalementsScreen(onShowOnMap: _goToMap),
    ElementsScreen(onShowOnMap: _goToMap),
    const SourcesScreen(),
  ];

  void _goToMap(LatLng point, {String? title}) {
    _mapFocus.focusOn(point, title: title);
    setState(() => _index = 1);
  }

  @override
  void dispose() {
    _mapFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<RandoRepository>();
    return ChangeNotifierProvider<AdminData>(
      create: (_) => AdminData(repo),
      child: Consumer<AdminData>(
        builder: (context, data, _) => LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final body = IndexedStack(index: _index, children: _screens);
            return Scaffold(
              body: SafeArea(
                child: wide
                    ? Row(
                        children: [
                          _NavRail(
                            extended: constraints.maxWidth >= 1200,
                            index: _index,
                            data: data,
                            onSelect: (i) => setState(() => _index = i),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: Column(
                              children: [
                                const _TopBar(),
                                Expanded(child: body),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          const _TopBar(),
                          Expanded(child: body),
                        ],
                      ),
              ),
              bottomNavigationBar: wide
                  ? null
                  : _NavBar(
                      index: _index,
                      data: data,
                      onSelect: (i) => setState(() => _index = i),
                    ),
            );
          },
        ),
      ),
    );
  }
}

const _titles = [
  'Itinéraires',
  'Carte',
  'Signalements',
  'Éléments remarquables',
  'Sources',
];
const _icons = [
  Icons.route,
  Icons.map_outlined,
  Icons.report_outlined,
  Icons.star_outline,
  Icons.folder_open,
];

Widget _icon(int i, AdminData data) {
  final count = switch (i) {
    2 => data.signaleCount,
    3 => data.elementsEnAttenteCount,
    _ => 0,
  };
  final icon = Icon(_icons[i]);
  if (count <= 0) return icon;
  return Badge(label: Text('$count'), child: icon);
}

class _NavRail extends StatelessWidget {
  const _NavRail(
      {required this.extended,
      required this.index,
      required this.data,
      required this.onSelect});

  final bool extended;
  final int index;
  final AdminData data;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      extended: extended,
      selectedIndex: index,
      onDestinationSelected: onSelect,
      labelType:
          extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
      leading: const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Icon(Icons.route, color: RandoColors.forest, size: 28),
      ),
      destinations: [
        for (var i = 0; i < _titles.length; i++)
          NavigationRailDestination(
            icon: _icon(i, data),
            label: Text(_titles[i]),
          ),
      ],
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.data, required this.onSelect});

  final int index;
  final AdminData data;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: onSelect,
      destinations: [
        for (var i = 0; i < _titles.length; i++)
          NavigationDestination(icon: _icon(i, data), label: _titles[i]),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AdminSession>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: RandoColors.line)),
      ),
      child: Row(
        children: [
          Text(
            'Rando Oise – Administration',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Icon(Icons.person_outline, size: 18, color: RandoColors.inkMuted),
          const SizedBox(width: 6),
          Text(session.user?.email ?? '',
              style: const TextStyle(color: RandoColors.inkMuted)),
          IconButton(
            tooltip: 'Se déconnecter',
            onPressed: session.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
    );
  }
}
