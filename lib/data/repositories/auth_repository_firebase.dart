import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryFirebase implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepositoryFirebase({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> signUpWithEmail(String email, String password, String phone) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    // Create user profile document in Firestore
    await createUserDocument(credential.user!.uid, phone);
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Stream<String?> get userIdStream {
    return _auth.authStateChanges().map((user) => user?.uid);
  }

  @override
  Future<bool> isAdmin(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['role'] == 'admin';
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> createUserDocument(String userId, String phone) async {
    final doc = _firestore.collection('users').doc(userId);
    final snapshot = await doc.get();
    if (!snapshot.exists) {
      await doc.set({
        'phone': phone,
        'role': 'player',
        'balance': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
