import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // メール+パスワードで新規登録
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // メール+パスワードでログイン
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Googleログイン
  Future<UserCredential> signInWithGoogle() async {
    final GoogleAuthProvider googleProvider = GoogleAuthProvider();
    if (kIsWeb) {
      return await _auth.signInWithPopup(googleProvider);
    }
    return await _auth.signInWithProvider(googleProvider);
  }

  // パスワードリセット
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ログアウト
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // アカウント削除
  Future<void> deleteAccount() async {
    await _auth.currentUser?.delete();
  }
}
