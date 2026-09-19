import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import '../session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AdminSession session) async {
    if (!_formKey.currentState!.validate()) return;
    await session.signIn(_emailController.text, _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AdminSession>();
    return Scaffold(
      backgroundColor: RandoColors.paper,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.route, color: RandoColors.forest, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'Rando Oise',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Espace administrateur – Agglomération de la Région de Compiègne',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: RandoColors.inkMuted),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        labelText: 'Adresse e-mail',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Veuillez saisir votre e-mail.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      onFieldSubmitted: (_) => _submit(session),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Veuillez saisir votre mot de passe.'
                          : null,
                    ),
                    if (session.lastError != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        session.lastError!,
                        style: const TextStyle(color: RandoColors.danger),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed:
                          session.signingIn ? null : () => _submit(session),
                      child: session.signingIn
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Se connecter'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
