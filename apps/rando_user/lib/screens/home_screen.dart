import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';
import '../util/format.dart';
import '../widgets/itineraire_card.dart';
import '../widgets/route_map.dart';
import '../widgets/signalement_tile.dart';
import '../widgets/ui.dart';
import 'carte_screen.dart';
import 'circuits_screen.dart';
import 'favoris_screen.dart';
import 'itineraire_detail_screen.dart';
import 'profil_screen.dart';
import 'sheets.dart';
import 'signalement_form_screen.dart';
import 'signalements_screen.dart';

/// Single main page: greeting, suggested route, quick access tiles
/// (map, reports, profile), nearby routes, favorites, latest reports.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, Itineraire it) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ItineraireDetailScreen(itineraireId: it.id)),
      );

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final name = state.displayName.isEmpty ? 'Randonneur' : state.displayName;
    final suggested = state.suggested;
    final nearest = state.nearest(limit: 6).where((it) => it.id != suggested?.id).toList();
    final favs = state.favoriteItineraires;
    final recent = state.recentSignalements(limit: 3);
    final pending = state.signalements.where((s) => s.statut == SignalementStatut.signale).length;
    final scale = MediaQuery.textScalerOf(context);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: state.refreshGps,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              // Header
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Ouvrir le profil',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(40),
                      onTap: () => _push(context, const ProfilScreen()),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InitialsAvatar(name: name),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Bonjour', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                                Text(name, style: theme.textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  RoundIconButton(
                    icon: dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    label: dark ? 'Passer en mode clair' : 'Passer en mode sombre',
                    onPressed: () => state.toggleTheme(theme.brightness),
                  ),
                  const SizedBox(width: 8),
                  RoundIconButton(
                    icon: Icons.search_rounded,
                    label: 'Rechercher un circuit',
                    onPressed: () => _push(context, const CircuitsScreen(autofocusSearch: true)),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text('Prêt pour une balade ?', style: theme.textTheme.displayMedium),
              const SizedBox(height: 4),
              Text(formatLongDate(DateTime.now()), style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 18),

              // Hero
              if (!state.itinerairesLoaded)
                const _HeroSkeleton()
              else if (suggested == null)
                _EmptyHero(state: state)
              else
                _HeroCard(itineraire: suggested, onOpen: () => _open(context, suggested)),

              if (state.itinerairesFromCache && state.itinerairesLoaded)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text('Hors ligne : données enregistrées sur l’appareil', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),

              // Quick access: map (tall, left) + reports / profile (right)
              const SizedBox(height: 16),
              _QuickAccess(
                tileHeight: scale.scale(122),
                map: _MapTile(
                  itineraires: state.itineraires,
                  subtitle: plural(state.itineraires.length, 'circuit'),
                  onTap: () => _push(context, const CarteScreen()),
                ),
                reports: _QuickTile(
                  icon: Icons.campaign_rounded,
                  color: SignalementStatut.signale.color,
                  title: 'Signalements',
                  subtitle: pending == 0
                      ? (state.signalements.isEmpty ? 'Aucun problème signalé' : 'Tout est traité')
                      : '${plural(pending, 'problème')} en attente',
                  badge: pending,
                  onTap: () => _push(context, const SignalementsScreen()),
                ),
                profile: _QuickTile(
                  icon: Icons.person_rounded,
                  color: RandoColors.blue,
                  title: 'Profil',
                  subtitle: favs.isEmpty ? 'Favoris, thème, hors ligne' : plural(favs.length, 'favori'),
                  onTap: () => _push(context, const ProfilScreen()),
                ),
              ),

              // Nearby
              if (nearest.isNotEmpty) ...[
                SectionHeader(
                  state.origin == null ? 'Circuits à découvrir' : 'Circuits près de toi',
                  actionLabel: 'Voir tout',
                  onAction: () => _push(context, const CircuitsScreen()),
                ),
                SizedBox(
                  height: scale.scale(168),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: nearest.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => ItineraireTile(
                      itineraire: nearest[i],
                      width: 196,
                      onTap: () => _open(context, nearest[i]),
                    ),
                  ),
                ),
              ],

              // Favorites
              SectionHeader(
                'Tes favoris',
                actionLabel: favs.isEmpty ? null : 'Voir tout',
                onAction: () => _push(context, const FavorisScreen()),
              ),
              if (favs.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const IconBox(icon: Icons.favorite_border_rounded, color: RandoColors.red, size: 46),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Touche le cœur d’un circuit pour le retrouver ici, même sans réseau.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: scale.scale(168),
                  ),
                  itemCount: favs.length.clamp(0, 4),
                  itemBuilder: (_, i) => ItineraireTile(itineraire: favs[i], onTap: () => _open(context, favs[i])),
                ),

              // Recent reports
              SectionHeader(
                'Derniers signalements',
                actionLabel: recent.isEmpty ? null : 'Voir tout',
                onAction: () => _push(context, const SignalementsScreen()),
              ),
              if (recent.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const IconBox(icon: Icons.check_circle_outline_rounded, color: RandoColors.green, size: 46),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Aucun problème signalé pour le moment. Bonne balade !',
                            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (final s in recent) ...[
                  SignalementTile(signalement: s, compact: true, onTap: () => showSignalementSheet(context, s)),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: state.itineraires.isEmpty
                    ? null
                    : () => _push(context, const SignalementFormScreen()),
                icon: const Icon(Icons.add_alert_rounded),
                label: const Text('Signaler un problème'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// The "tes lieux" style block: one tall tile on the left, two on the right.
class _QuickAccess extends StatelessWidget {
  const _QuickAccess({required this.tileHeight, required this.map, required this.reports, required this.profile});
  final double tileHeight;
  final Widget map;
  final Widget reports;
  final Widget profile;

  @override
  Widget build(BuildContext context) {
    const gap = 12.0;
    return SizedBox(
      height: tileHeight * 2 + gap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: map),
          const SizedBox(width: gap),
          Expanded(
            child: Column(
              children: [
                Expanded(child: reports),
                const SizedBox(height: gap),
                Expanded(child: profile),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge = 0,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Badge.count(count: badge, isLabelVisible: badge > 0, child: IconBox(icon: icon, color: color, size: 40)),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(subtitle, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tall tile with a live preview of every route; opens the full map.
class _MapTile extends StatelessWidget {
  const _MapTile({required this.itineraires, required this.subtitle, required this.onTap});
  final List<Itineraire> itineraires;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: 'Ouvrir la carte des circuits',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (itineraires.isEmpty)
              Container(color: scheme.surfaceContainer)
            else
              IgnorePointer(
                child: RouteMap(
                  itineraires: itineraires,
                  interactive: false,
                  showStartMarkers: false,
                  attribution: false,
                  fitPadding: 14,
                ),
              ),
            // Readable footer on top of the map.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 26, 14, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [scheme.surface.withValues(alpha: 0), scheme.surface.withValues(alpha: 0.96)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Carte', style: theme.textTheme.titleLarge),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: IconBox(icon: Icons.map_rounded, color: RandoColors.green, size: 40, solid: true),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.itineraire, required this.onOpen});
  final Itineraire itineraire;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final it = itineraire;
    final distance = state.distanceFromOrigin(it);
    final fav = state.isFavorite(it.id);

    return Semantics(
      button: true,
      label: 'Circuit ${it.nom}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(28),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [const Color(0xFF16352A), const Color(0xFF0F2A1F)]
                    : [const Color(0xFFDDEFE3), const Color(0xFFC9E4D3)],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: TopoBackground(
                color: (dark ? RandoColors.nightGreen : RandoColors.green).withValues(alpha: 0.18),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              distance == null ? 'À découvrir' : 'Le plus proche de toi',
                              style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
                            ),
                          ),
                          RoundIconButton(
                            icon: fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            label: fav ? 'Retirer des favoris' : 'Ajouter aux favoris',
                            size: 44,
                            active: fav,
                            onPressed: () => state.toggleFavorite(it.id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(it.nom, style: theme.textTheme.displaySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (it.communesLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(it.communesLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                      const SizedBox(height: 14),
                      if (distance != null)
                        Text('à ${formatDistance(distance)}', style: theme.textTheme.displayMedium?.copyWith(color: scheme.primary)),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StatPill(icon: Icons.straighten_rounded, label: 'Distance', value: formatDistance(it.lengthM), onDark: dark),
                          StatPill(icon: Icons.schedule_rounded, label: 'Durée', value: formatDurationH(it.dureeH), onDark: dark),
                          StatPill(icon: difficultyIcon(it.difficulte), label: 'Niveau', value: DifficultyStyle.label(it.difficulte), onDark: dark),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: onOpen,
                        child: Row(
                          children: [
                            const Icon(Icons.navigation_rounded, size: 20),
                            const SizedBox(width: 10),
                            const Expanded(child: Text('Voir le circuit')),
                            Text(formatDistance(it.lengthM), style: theme.textTheme.labelLarge?.copyWith(color: Colors.white70)),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHero extends StatelessWidget {
  const _EmptyHero({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Aucun circuit disponible', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              state.loadError == null
                  ? 'Connecte-toi à internet une première fois pour télécharger les circuits.'
                  : 'Impossible de charger les circuits : ${state.loadError}',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) => Container(
        height: 300,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
}
