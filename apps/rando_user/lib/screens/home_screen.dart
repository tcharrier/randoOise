import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'favoris_tab.dart';
import 'itineraires_tab.dart';
import 'signalements_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final favCount = context.select<AppState, int>((s) => s.favorites.length);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          ItinerairesTab(),
          FavorisTab(),
          SignalementsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Itinéraires',
          ),
          NavigationDestination(
            icon: Badge.count(
              count: favCount,
              isLabelVisible: favCount > 0,
              child: const Icon(Icons.favorite_border),
            ),
            selectedIcon: Badge.count(
              count: favCount,
              isLabelVisible: favCount > 0,
              child: const Icon(Icons.favorite),
            ),
            label: 'Favoris',
          ),
          const NavigationDestination(
            icon: Icon(Icons.report_outlined),
            selectedIcon: Icon(Icons.report),
            label: 'Signalements',
          ),
        ],
      ),
    );
  }
}
