import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static Stream<User?> userChanges() =>
      FirebaseAuth.instance.authStateChanges();

  static User? get currentUser => FirebaseAuth.instance.currentUser;

  static bool get isSignedIn {
    final u = currentUser;
    return u != null && !u.isAnonymous;
  }

  static Future<void> signInWithGoogle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      if (user != null && user.isAnonymous) {
        try {
          await user.linkWithPopup(provider);
          return;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' ||
              e.code == 'email-already-in-use' ||
              e.code == 'provider-already-linked') {
            await FirebaseAuth.instance.signInWithPopup(provider);
            return;
          }
          rethrow;
        }
      }
      await FirebaseAuth.instance.signInWithPopup(provider);
      return;
    }

    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'cancelled',
        message: 'Connexion annulée.',
      );
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    if (user != null && user.isAnonymous) {
      try {
        await user.linkWithCredential(credential);
        return;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' ||
            e.code == 'email-already-in-use' ||
            e.code == 'provider-already-linked') {
          await FirebaseAuth.instance.signInWithCredential(credential);
          return;
        }
        rethrow;
      }
    }
    await FirebaseAuth.instance.signInWithCredential(credential);
  }

  static Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    }
    await FirebaseAuth.instance.signOut();
  }
}
