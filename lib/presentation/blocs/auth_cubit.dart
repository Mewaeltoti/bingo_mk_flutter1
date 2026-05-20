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
    _authRepository.userIdStream.listen((userId) async {
      if (userId != null) {
        try {
          final admin = await _authRepository.isAdmin(userId);
          emit(AuthAuthenticated(userId, isAdmin: admin));
        } catch (e) {
          // Fallback to player role if Postgres is cold-starting, document doesn't exist yet,
          // or network is offline, to ensure the login session completes successfully.
          emit(AuthAuthenticated(userId, isAdmin: false));
        }
      } else {
        emit(AuthUnauthenticated());
      }
    }, onError: (e) {
      emit(AuthUnauthenticated());
    });
  }

  String _formatPhone(String phone) {
    String clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return '$clean@bingo.mk';
  }

  Future<void> login(String phone, String password) async {
    emit(AuthLoading());
    try {
      await _authRepository.signInWithEmail(_formatPhone(phone), password);
    } catch (e) {
      emit(AuthError("Login failed. Check your number and password."));
    }
  }

  Future<void> signUp(String phone, String password) async {
    if (phone.length < 9) {
      emit(AuthError("Please enter a valid phone number."));
      return;
    }
    emit(AuthLoading());
    try {
      final email = _formatPhone(phone);
      await _authRepository.signUpWithEmail(email, password, phone);
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> logout() async {
    await _authRepository.signOut();
  }
}
