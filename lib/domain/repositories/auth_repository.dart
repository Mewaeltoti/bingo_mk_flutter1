abstract class AuthRepository {
  Future<void> signInWithEmail(String email, String password);
  Future<void> signUpWithEmail(String email, String password, String phone);
  Future<void> signOut();
  Stream<String?> get userIdStream;
  Future<String?> getCurrentUserId();
  Future<bool> isAdmin(String userId);
  Future<void> createUserDocument(String userId, String phone);
}
