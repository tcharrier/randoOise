import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';
import '../widgets/position_picker.dart';

class SignalementFormScreen extends StatefulWidget {
  const SignalementFormScreen({super.key, this.itineraire, this.initialPosition});

  final Itineraire? itineraire;
  final LatLng? initialPosition;

  @override
  State<SignalementFormScreen> createState() => _SignalementFormScreenState();
}

class _SignalementFormScreenState extends State<SignalementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  Itineraire? _itineraire;
  SignalementCategorie _categorie = SignalementCategorie.obstacle;
  LatLng? _position;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _itineraire = widget.itineraire;
    _position = widget.initialPosition;
    if (_position == null) _initPosition();
  }

  Future<void> _initPosition() async {
    final state = context.read<AppState>();
    final p = state.gpsPosition ?? await state.location.currentPosition();
    if (!mounted || p == null) return;
    setState(() {
      _position ??= p;
      // Preselect the closest route when none was given.
      if (_itineraire == null && state.itineraires.isNotEmpty) {
        final sorted = [...state.itineraires]
          ..sort((a, b) => distanceToTracksM(p, a.tracks).compareTo(distanceToTracksM(p, b.tracks)));
        _itineraire = sorted.first;
      }
    });
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_itineraire == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choisissez un itinéraire.')));
      return;
    }
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Placez le point sur la carte.')));
      return;
    }
    setState(() => _sending = true);
    final state = context.read<AppState>();
    final ok = await state.createSignalement(
      itineraire: _itineraire!,
      categorie: _categorie,
      description: _description.text.trim(),
      position: _position!,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Une première connexion internet est nécessaire pour activer les signalements.'),
      ));
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Signalement enregistré. Il sera transmis dès qu’une connexion est disponible.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Signaler un problème')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              'Votre signalement est visible par les autres randonneurs et transmis à l’ARC pour traitement.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _itineraire?.id,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Itinéraire', prefixIcon: Icon(Icons.route_outlined)),
              items: [
                for (final it in state.itineraires)
                  DropdownMenuItem(value: it.id, child: Text(it.nom, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _itineraire = v == null ? null : state.itineraireById(v)),
              validator: (v) => v == null ? 'Choisissez un itinéraire' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SignalementCategorie>(
              initialValue: _categorie,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Type de problème', prefixIcon: Icon(Icons.category_outlined)),
              items: [
                for (final c in SignalementCategorie.values)
                  DropdownMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        Icon(c.icon, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(c.label, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _categorie = v ?? _categorie),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Décrivez le problème (arbre en travers, panneau cassé…)',
                alignLabelWithHint: true,
              ),
              validator: (v) => (v == null || v.trim().length < 5) ? 'Décrivez le problème en quelques mots' : null,
            ),
            const SizedBox(height: 8),
            Text('Position du problème', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            PositionPicker(
              itineraire: _itineraire,
              value: _position,
              onChanged: (p) => setState(() => _position = p),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _sending ? null : _submit,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_outlined),
              label: const Text('Envoyer le signalement'),
            ),
          ],
        ),
      ),
    );
  }
}
