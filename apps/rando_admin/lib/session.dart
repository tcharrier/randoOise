import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:rando_core/rando_core.dart';

/// Maps the identifier / password typed by the admin to Firebase credentials.
/// Identifier without `@` -> `<identifiant>@rando-oise.app`; password shorter
/// than 6 characters is padded with `#` (`admin` -> `admin#`).
({String email, String password}) adminCredentials(
    String identifiant, String motDePasse) {
  final id = identifiant.trim();
  final email = id.contains('@') ? id : '$id@rando-oise.app';
  final password = motDePasse.length < 6 ? motDePasse.padRight(6, '#') : motDePasse;
  return (email: email, password: password);
}

/// Authentication + admin-rights state of the current session.
enum AdminAuthStatus { unknown, signedOut, checkingAdmin, admin, notAdmin }

class AdminSession extends ChangeNotifier {
  AdminSession(this._auth, this._repo) {
    _sub = _auth.authStateChanges().listen(_onUser);
  }

  final FirebaseAuth _auth;
  final RandoRepository _repo;
  late final StreamSubscription<User?> _sub;

  User? user;
  AdminAuthStatus status = AdminAuthStatus.unknown;
  String? lastError;
  bool signingIn = false;

  Future<void> _onUser(User? u) async {
    user = u;
    lastError = null;
    if (u == null) {
      status = AdminAuthStatus.signedOut;
      notifyListeners();
      return;
    }
    status = AdminAuthStatus.checkingAdmin;
    notifyListeners();
    final ok = await _repo.isAdmin(u.uid);
    status = ok ? AdminAuthStatus.admin : AdminAuthStatus.notAdmin;
    notifyListeners();
  }

  Future<void> signIn(String identifiant, String motDePasse) async {
    final c = adminCredentials(identifiant, motDePasse);
    signingIn = true;
    lastError = null;
    notifyListeners();
    try {
      await _auth.signInWithEmailAndPassword(
          email: c.email, password: c.password);
    } on FirebaseAuthException catch (e) {
      lastError = _frenchError(e.code);
    } catch (_) {
      lastError = 'Une erreur est survenue. Veuillez réessayer.';
    } finally {
      signingIn = false;
      notifyListeners();
    }
  }

  Future<void> signOut() => _auth.signOut();

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  static String _frenchError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Identifiant invalide.';
      case 'user-disabled':
        return 'Ce compte a été désactivé.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Identifiant ou mot de passe incorrect.';
      case 'too-many-requests':
        return 'Trop de tentatives, veuillez réessayer plus tard.';
      case 'configuration-not-found':
      case 'operation-not-allowed':
        return 'Authentification Firebase non activée : dans la console Firebase, Authentication → Commencer, puis activer “E‑mail/mot de passe” et “Anonyme”.';
      case 'network-request-failed':
        return 'Connexion réseau impossible.';
      default:
        return 'Connexion impossible ($code).';
    }
  }
}
