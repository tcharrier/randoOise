import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:rando_core/rando_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'services/favorites_service.dart';
import 'services/offline_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Offline first: keep every document we ever read, without size limit.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  final prefs = await SharedPreferences.getInstance();
  final favorites = await FavoritesService.load();
  final offline = await OfflineService.create();
  final state = AppState(
    repository: RandoRepository(FirebaseFirestore.instance),
    favorites: favorites,
    offline: offline,
    prefs: prefs,
  );
  state.start();

  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const RandoOiseApp(),
    ),
  );
}

class RandoOiseApp extends StatelessWidget {
  const RandoOiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<AppState, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      title: 'Rando Oise',
      debugShowCheckedModeBanner: false,
      theme: buildRandoTheme(),
      darkTheme: buildRandoTheme(brightness: Brightness.dark),
      themeMode: themeMode,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
          ),
          child: child!,
        );
      },
      home: const HomeScreen(),
    );
  }
}

/// Signs the device in anonymously so reports can be attributed and voted
/// once per device. Works without network once the session is cached.
Future<String?> ensureSignedIn() async {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser != null) return auth.currentUser!.uid;
  try {
    final cred = await auth.signInAnonymously();
    return cred.user?.uid;
  } catch (_) {
    return null;
  }
}
