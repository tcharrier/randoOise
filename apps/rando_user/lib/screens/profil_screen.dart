import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';
import '../services/tile_cache.dart';
import '../util/format.dart';
import '../widgets/ui.dart';
import 'favoris_screen.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  int? _cacheBytes;

  @override
  void initState() {
    super.initState();
    _refreshSize();
  }

  Future<void> _refreshSize() async {
    final size = await context.read<AppState>().offline.tiles.sizeBytes();
    if (mounted) setState(() => _cacheBytes = size);
  }

  Future<void> _editName(AppState state) async {
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
          animation: offline,
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
                  subtitle: Text(state.favoriteItineraires.isEmpty
                      ? 'Aucun favori pour le moment'
                      : plural(state.favoriteItineraires.length, 'circuit favori', 'circuits favoris')),
                  trailing: RoundIconButton(
                    icon: Icons.edit_outlined,
                    label: 'Modifier le prénom',
                    size: 44,
                    onPressed: () => _editName(state),
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
                icon: Icons.offline_pin_rounded,
                color: RandoColors.green,
                title: 'Circuits téléchargés',
                subtitle: offline.downloadedCount == 0
                    ? 'Depuis la fiche d’un circuit, télécharge sa carte pour partir sans réseau.'
                    : '${plural(offline.downloadedCount, 'circuit')} avec carte hors ligne',
              ),
              const SizedBox(height: 10),
              InfoRowCard(
                icon: Icons.storage_rounded,
                color: RandoColors.blue,
                title: 'Cache des cartes',
                subtitle: _cacheBytes == null ? 'Calcul…' : formatBytes(_cacheBytes!),
                trailing: TextButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Vider le cache ?'),
                        content: const Text('Les cartes téléchargées devront être re-téléchargées pour une utilisation hors ligne.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Vider')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await offline.clearAll();
                      _refreshSize();
                    }
                  },
                  child: const Text('Vider'),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Les circuits, signalements et éléments remarquables consultés sont conservés sur l’appareil. '
                  'Les signalements créés sans réseau sont envoyés automatiquement dès que la connexion revient.',
                  style: theme.textTheme.bodySmall,
                ),
              ),

              const SectionHeader('À propos'),
              InfoRowCard(
                icon: Icons.hiking_rounded,
                color: RandoColors.green,
                title: 'Rando Oise',
                subtitle: state.sources.isEmpty
                    ? 'Sources de randonnées : aucune'
                    : 'Sources : ${state.sources.map((s) => s.name).join(', ')}',
              ),
              const SizedBox(height: 10),
              InfoRowCard(
                icon: Icons.perm_identity_rounded,
                color: RandoColors.ochre,
                title: 'Identifiant de l’appareil',
                subtitle: state.uid == null
                    ? 'Non connecté (une connexion internet est nécessaire une fois)'
                    : 'Anonyme · ${state.uid!.substring(0, 8)}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
