import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../admin_data.dart';
import '../utils/date_format.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';

/// Manages data sources: import a new .zip/.json file, enable/disable or
/// delete an existing one.
class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key});

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  bool _importing = false;
  double? _progress;

  Future<void> _pickAndImport(
      BuildContext context, RandoRepository repo, List<RandoSource> existing) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'json', 'geojson'],
    );
    if (files.isEmpty) return;
    final file = files.single;
    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Impossible de lire le fichier : $e')));
      }
      return;
    }

    ImportResult imported;
    try {
      imported = SourceImporter.fromBytes(bytes, fileName: file.name);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur lors de la lecture du fichier : $e')));
      }
      return;
    }
    if (imported.itineraires.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucun itinéraire exploitable dans ce fichier.')));
      }
      return;
    }
    if (!context.mounted) return;

    final replaces = existing.any((s) => s.id == imported.source.id);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(imported.source.name),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Identifiant : ${imported.source.id}'),
                Text('${imported.itineraires.length} itinéraire(s) trouvé(s).'),
                if (replaces)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Une source portant cet identifiant existe déjà : elle sera '
                      'remplacée (les itinéraires qui ne sont plus présents seront supprimés).',
                      style: TextStyle(color: RandoColors.ochre),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text('Itinéraires :', style: TextStyle(fontWeight: FontWeight.w700)),
                for (final it in imported.itineraires)
                  Text('• ${it.nom} — ${formatDistance(it.lengthM)}'),
                if (imported.warnings.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Avertissements (${imported.warnings.length}) :',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: RandoColors.danger)),
                  for (final w in imported.warnings)
                    Text('• $w', style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Importer')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    setState(() {
      _importing = true;
      _progress = 0;
    });
    try {
      await repo.importSource(imported, onProgress: (done, total) {
        if (mounted) setState(() => _progress = total == 0 ? 1 : done / total);
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Source « ${imported.source.name} » importée (${imported.itineraires.length} itinéraire(s)).')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Échec de l\'import : $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _deleteSource(
      BuildContext context, RandoRepository repo, RandoSource source) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Supprimer la source « ${source.name} » ?',
      message:
          'Les ${source.itineraireCount} itinéraire(s) ainsi que tous les signalements '
          'et éléments remarquables associés seront définitivement supprimés.',
      confirmLabel: 'Supprimer',
      danger: true,
    );
    if (ok) {
      await repo.deleteSource(source.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Source supprimée.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AdminData>();
    final repo = context.read<RandoRepository>();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Sources',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              FilledButton.icon(
                onPressed:
                    _importing ? null : () => _pickAndImport(context, repo, data.sources),
                icon: const Icon(Icons.upload_file),
                label: const Text('Importer une source (.zip / .json)'),
              ),
            ],
          ),
          if (_importing)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(value: _progress),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: data.sources.isEmpty
                ? const EmptyState(
                    message: 'Aucune source importée pour le moment.',
                    icon: Icons.folder_open)
                : ListView.builder(
                    itemCount: data.sources.length,
                    itemBuilder: (context, i) {
                      final s = data.sources[i];
                      return _SourceRow(
                        source: s,
                        repo: repo,
                        onDelete: () => _deleteSource(context, repo, s),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source, required this.repo, required this.onDelete});

  final RandoSource source;
  final RandoRepository repo;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = source;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.folder_open,
                color: s.enabled ? RandoColors.forest : RandoColors.inkMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    '${s.producteur.isEmpty ? '—' : s.producteur} · '
                    '${s.itineraireCount} itinéraire(s) · importée le ${formatDate(s.importedAt)}',
                    style: const TextStyle(color: RandoColors.inkMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text('Actif'),
            Switch(
              value: s.enabled,
              onChanged: (v) => repo.setSourceEnabled(s.id, v),
            ),
            IconButton(
              tooltip: 'Supprimer',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: RandoColors.danger),
            ),
          ],
        ),
      ),
    );
  }
}
