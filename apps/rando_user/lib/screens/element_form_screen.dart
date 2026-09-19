import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../app_state.dart';
import '../widgets/position_picker.dart';

class ElementFormScreen extends StatefulWidget {
  const ElementFormScreen({super.key, required this.itineraire, this.initialPosition});

  final Itineraire itineraire;
  final LatLng? initialPosition;

  @override
  State<ElementFormScreen> createState() => _ElementFormScreenState();
}

class _ElementFormScreenState extends State<ElementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titre = TextEditingController();
  final _description = TextEditingController();
  ElementCategorie _categorie = ElementCategorie.patrimoine;
  LatLng? _position;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
    if (_position == null) _initPosition();
  }

  Future<void> _initPosition() async {
    final state = context.read<AppState>();
    final p = state.gpsPosition ?? await state.location.currentPosition();
    if (!mounted || p == null) return;
    setState(() => _position ??= p);
  }

  @override
  void dispose() {
    _titre.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Placez le point sur la carte.')));
      return;
    }
    setState(() => _sending = true);
    final ok = await context.read<AppState>().createElement(
          itineraire: widget.itineraire,
          categorie: _categorie,
          titre: _titre.text.trim(),
          description: _description.text.trim(),
          position: _position!,
        );
    if (!mounted) return;
    setState(() => _sending = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Une première connexion internet est nécessaire pour activer les propositions.'),
      ));
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Merci ! Votre proposition sera visible par tous après validation par l’ARC.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Proposer un élément remarquable')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              'Un lavoir, un point de vue, un arbre remarquable… Partagez ce qui vaut le détour sur « ${widget.itineraire.nom} ».',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ElementCategorie>(
              initialValue: _categorie,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Catégorie', prefixIcon: Icon(Icons.category_outlined)),
              items: [
                for (final c in ElementCategorie.values)
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
              controller: _titre,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Titre', hintText: 'Ex. Lavoir de Genancourt'),
              validator: (v) => (v == null || v.trim().length < 3) ? 'Donnez un titre' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description (facultatif)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            Text('Emplacement', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            PositionPicker(
              itineraire: widget.itineraire,
              value: _position,
              onChanged: (p) => setState(() => _position = p),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _sending ? null : _submit,
              icon: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_outlined),
              label: const Text('Envoyer la proposition'),
            ),
          ],
        ),
      ),
    );
  }
}
