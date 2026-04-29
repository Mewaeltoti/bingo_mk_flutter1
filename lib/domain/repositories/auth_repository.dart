import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Future<UserCredential?> signInWithEmail(String email, String password);
  Future<UserCredential?> signUpWithEmail(String email, String password);
  Future<void> signOut();
  Stream<User?> get user;
  Future<bool> isAdmin(String userId);
  Future<void> createUserDocument(String userId, String email);
}
