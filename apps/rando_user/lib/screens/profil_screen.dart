import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';
import '../services/map_style.dart';
import '../services/offline_service.dart';
import '../util/format.dart';
import '../widgets/ui.dart';
import 'favoris_screen.dart';
import 'mes_elements_screen.dart';
import 'signalements_screen.dart';
import 'sorties_screen.dart';

class ProfilScreen extends StatelessWidget {
  const ProfilScreen({super.key});

  Future<void> _editName(BuildContext context, AppState state) async {
    final ctrl = TextEditingController(text: state.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ton prénom'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Prénom (reste sur l’appareil)'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (name != null) await state.setDisplayName(name);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final offline = state.offline;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = state.displayName.isEmpty ? 'Randonneur' : state.displayName;

    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([offline, state.sorties]),
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              PageHeader(
                title: 'Profil',
                subtitle: 'Tes préférences restent sur cet appareil.',
                leading: RoundIconButton(icon: Icons.arrow_back_rounded, label: 'Retour', onPressed: () => Navigator.of(context).pop()),
              ),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                  leading: InitialsAvatar(name: name, size: 56),
                  title: Text(name, style: theme.textTheme.titleLarge),
                  subtitle: Text(
                    '${plural(state.favoriteItineraires.length, 'favori')} · ${plural(state.sorties.count, 'sortie')}',
                  ),
                  trailing: RoundIconButton(
                    icon: Icons.edit_outlined,
                    label: 'Modifier le prénom',
                    size: 44,
                    onPressed: () => _editName(context, state),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InfoRowCard(
                icon: Icons.favorite_rounded,
                color: RandoColors.red,
                title: 'Mes favoris',
                subtitle: plural(state.favoriteItineraires.length, 'circuit'),
                chevron: true,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FavorisScreen())),
              ),
              const SizedBox(height: 10),
              InfoRowCard(
                icon: Icons.history_rounded,
                color: RandoColors.velo,
                title: 'Mes sorties',
                subtitle: state.sorties.count == 0
                    ? 'Aucune sortie enregistrée'
                    : '${plural(state.sorties.count, 'sortie')} · ${formatDistance(state.sorties.totalKm * 1000)}',
                chevron: true,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SortiesScreen())),
              ),
              const SizedBox(height: 10),
              InfoRowCard(
                icon: Icons.add_alert_rounded,
                color: RandoColors.ochre,
                title: 'Mes signalements',
                subtitle: state.mySignalements.isEmpty ? 'Aucun signalement envoyé' : plural(state.mySignalements.length, 'signalement'),
                chevron: true,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignalementsScreen(onlyMine: true))),
              ),
              const SizedBox(height: 10),
              InfoRowCard(
                icon: Icons.place_rounded,
                color: RandoColors.blue,
                title: 'Mes éléments remarquables',
                subtitle: state.myElements.isEmpty ? 'Aucune proposition' : plural(state.myElements.length, 'proposition'),
                chevron: true,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MesElementsScreen())),
              ),

              const SectionHeader('Apparence'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Thème', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 10),
                      SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.phone_android_rounded), label: Text('Auto')),
                          ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Clair')),
                          ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Sombre')),
                        ],
                        selected: {state.themeMode},
                        onSelectionChanged: (s) => state.setThemeMode(s.first),
                      ),
                    ],
                  ),
                ),
              ),

              const SectionHeader('Carte'),
              Card(
                child: Column(
                  children: [
                    for (final s in MapStyle.all)
                      RadioListTile<String>(
                        value: s.id,
                        // ignore: deprecated_member_use
                        groupValue: offline.style.id,
                        // ignore: deprecated_member_use
                        onChanged: (v) => offline.setStyle(MapStyle.byId(v)),
                        title: Text(s.label, style: theme.textTheme.titleMedium),
                        subtitle: Text(s.attribution),
                        activeColor: scheme.primary,
                      ),
                  ],
                ),
              ),

              const SectionHeader('Hors ligne'),
              InfoRowCard(
                icon: Icons.directions_bike_rounded,
                color: RandoColors.velo,
                title: 'Pistes cyclables',
                subtitle: '${plural(state.countFor(Activite.velo), 'piste')} intégrées à l’app, toujours disponibles sans réseau',
              ),
              const SizedBox(height: 10),
              InfoRowCard(
                icon: Icons.offline_pin_rounded,
                color: RandoColors.green,
                title: 'Cartes enregistrées',
                subtitle: !OfflineService.supported
                    ? 'Disponible dans l’application mobile'
                    : offline.savedCount == 0
                        ? 'Depuis la fiche d’un circuit, enregistre sa carte pour partir sans réseau.'
                        : '${plural(offline.savedCount, 'circuit')} avec carte hors ligne',
                trailing: offline.savedCount == 0
                    ? null
                    : TextButton(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Supprimer les cartes hors ligne ?'),
                              content: const Text('Les tuiles enregistrées pour tous les circuits seront retirées de l’appareil.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
                              ],
                            ),
                          );
                          if (ok == true) await offline.clearAll();
                        },
                        child: const Text('Vider'),
                      ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Les randonnées, signalements et éléments remarquables consultés sont conservés sur l’appareil. '
                  'Les signalements créés sans réseau sont envoyés automatiquement dès que la connexion revient.',
                  style: theme.textTheme.bodySmall,
                ),
              ),

              const SectionHeader('À propos'),
              InfoRowCard(
                icon: Icons.hiking_rounded,
                color: RandoColors.green,
                title: 'Rando Oise',
                subtitle: 'Sources : ${state.sources.map((s) => s.name).join(', ')}',
              ),
              const SizedBox(height: 10),
              InfoRowCard(
                icon: Icons.cloud_outlined,
                color: RandoColors.blue,
                title: 'Météo',
                subtitle: 'Prévisions Open-Meteo pour Compiègne, mises en cache sur l’appareil.',
              ),
              const SizedBox(height: 10),
              InfoRowCard(
                icon: Icons.perm_identity_rounded,
                color: RandoColors.ochre,
                title: 'Identifiant de l’appareil',
                subtitle: state.uid == null
                    ? (state.authError ?? 'Non connecté (une connexion internet est nécessaire une fois)')
                    : 'Anonyme · ${state.uid!.substring(0, 8)}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
