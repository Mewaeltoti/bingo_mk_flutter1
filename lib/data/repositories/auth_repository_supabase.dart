import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositorySupabase implements AuthRepository {
  final SupabaseClient _client;

  AuthRepositorySupabase({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> signUpWithEmail(String email, String password, String phone) async {
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
        data: {'phone': phone},
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Stream<String?> get userIdStream {
    return _client.auth.onAuthStateChange.map((data) => data.session?.user.id);
  }

  @override
  Future<bool> isAdmin(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      return response?['role'] == 'admin';
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> createUserDocument(String userId, String phone) async {
    // The profile table is automatically synchronized using PostgreSQL triggers,
    // so no client-side profile creation is needed. We keep it as a no-op 
    // to preserve interface compliance.
  }
}
