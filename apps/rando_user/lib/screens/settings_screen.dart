import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/tile_cache.dart';
import '../util/format.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final offline = state.offline;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: AnimatedBuilder(
        animation: offline,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text('Fond de carte', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
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
                      title: Text(s.label),
                      subtitle: Text(s.attribution),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Hors ligne', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.offline_pin_outlined),
                    title: const Text('Circuits téléchargés'),
                    subtitle: Text('${offline.downloadedCount} circuit${offline.downloadedCount > 1 ? 's' : ''} avec carte hors ligne'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.storage_outlined),
                    title: const Text('Cache des tuiles'),
                    subtitle: Text(_cacheBytes == null ? 'Calcul…' : formatBytes(_cacheBytes!)),
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
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      'Les itinéraires, signalements et éléments remarquables consultés sont conservés sur l’appareil. '
                      'Les signalements créés sans réseau sont envoyés automatiquement dès que la connexion revient.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('À propos', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.hiking),
                    title: const Text('Rando Oise'),
                    subtitle: Text('Sources : ${state.sources.map((s) => s.name).join(', ')}'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.perm_identity),
                    title: const Text('Identifiant de l’appareil'),
                    subtitle: Text(state.uid == null ? 'Non connecté (connexion requise une fois)' : state.uid!.substring(0, 8)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
