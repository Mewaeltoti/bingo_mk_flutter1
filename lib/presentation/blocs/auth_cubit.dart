import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/repositories/auth_repository.dart';

abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {
  final String userId;
  final bool isAdmin;
  AuthAuthenticated(this.userId, {this.isAdmin = false});
  @override
  List<Object?> get props => [userId, isAdmin];
}
class AuthUnauthenticated extends AuthState {}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;

  AuthCubit(this._authRepository) : super(AuthInitial()) {
    _authRepository.user.listen((user) async {
      if (user != null) {
        final admin = await _authRepository.isAdmin(user.uid);
        emit(AuthAuthenticated(user.uid, isAdmin: admin));
      } else {
        emit(AuthUnauthenticated());
      }
    });
  }

  Future<void> login(String email, String password) async {
    emit(AuthLoading());
    try {
      await _authRepository.signInWithEmail(email, password);
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> signUp(String email, String password, [String? displayName]) async {
    emit(AuthLoading());
    try {
      final creds = await _authRepository.signUpWithEmail(email, password);
      if (creds != null && creds.user != null) {
        await _authRepository.createUserDocument(creds.user!.uid, email);
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> logout() async {
    await _authRepository.signOut();
  }
}
