import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';

import 'firebase_options.dart';
import 'screens/admin_shell.dart';
import 'screens/login_screen.dart';
import 'screens/no_access_screen.dart';
import 'session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const RandoAdminApp());
}

class RandoAdminApp extends StatelessWidget {
  const RandoAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<RandoRepository>(
          create: (_) => RandoRepository(FirebaseFirestore.instance),
        ),
        ChangeNotifierProvider<AdminSession>(
          create: (ctx) =>
              AdminSession(FirebaseAuth.instance, ctx.read<RandoRepository>()),
        ),
      ],
      child: MaterialApp(
        title: 'Rando Oise – Administration',
        debugShowCheckedModeBanner: false,
        theme: buildRandoTheme(),
        darkTheme: buildRandoTheme(brightness: Brightness.dark),
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const _AuthGate(),
      ),
    );
  }
}

/// Routes to the login screen, an "access denied" screen, or the admin
/// shell, depending on the Firebase auth state and admin rights.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AdminSession>();
    switch (session.status) {
      case AdminAuthStatus.unknown:
      case AdminAuthStatus.checkingAdmin:
        return const Scaffold(
          backgroundColor: RandoColors.paper,
          body: Center(child: CircularProgressIndicator()),
        );
      case AdminAuthStatus.signedOut:
        return const LoginScreen();
      case AdminAuthStatus.notAdmin:
        return const NoAccessScreen();
      case AdminAuthStatus.admin:
        return const AdminShell();
    }
  }
}
