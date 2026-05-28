import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/repositories/auth_repository.dart';

/// ======================================================
/// AUTH STATES
/// ======================================================
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

/// ======================================================
/// AUTH CUBIT (FIXED)
/// ======================================================
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription? _authSub;

  AuthCubit(this._authRepository) : super(AuthInitial()) {
    _initialize();
  }

  /// ======================================================
  /// INITIAL RESOLUTION (CRITICAL FIX)
  /// ======================================================
  Future<void> _initialize() async {
    emit(AuthLoading());

    try {
      /// STEP 1: Try immediate session check (IMPORTANT FIX)
      final userId = await _authRepository.getCurrentUserId();

      if (userId != null) {
        final isAdmin = await _safeCheckAdmin(userId);

        emit(AuthAuthenticated(userId, isAdmin: isAdmin));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthUnauthenticated());
    }

    /// STEP 2: Start listening for auth changes
    _listenAuthStream();
  }

  /// ======================================================
  /// STREAM LISTENER (REAL-TIME UPDATES)
  /// ======================================================
  void _listenAuthStream() {
    _authSub = _authRepository.userIdStream.listen(
      (userId) async {
        if (isClosed) return;

        if (userId != null) {
          final isAdmin = await _safeCheckAdmin(userId);

          if (!isClosed) {
            emit(AuthAuthenticated(userId, isAdmin: isAdmin));
          }
        } else {
          if (!isClosed) {
            emit(AuthUnauthenticated());
          }
        }
      },
      onError: (e) {
        if (!isClosed) {
          emit(AuthUnauthenticated());
        }
      },
    );
  }

  /// ======================================================
  /// SAFE ADMIN CHECK (FAIL-SAFE)
  /// ======================================================
  Future<bool> _safeCheckAdmin(String userId) async {
    try {
      return await _authRepository.isAdmin(userId);
    } catch (_) {
      return false;
    }
  }

  /// ======================================================
  /// LOGIN
  /// ======================================================
  Future<void> login(String phone, String password) async {
    emit(AuthLoading());

    try {
      await _authRepository.signInWithEmail(
        _formatPhone(phone),
        password,
      );
    } catch (e) {
      emit(AuthError("Login failed. Check your credentials."));
    }
  }

  /// ======================================================
  /// SIGN UP
  /// ======================================================
  Future<void> signUp(String phone, String password) async {
    if (phone.length < 9) {
      emit(AuthError("Invalid phone number"));
      return;
    }

    emit(AuthLoading());

    try {
      final email = _formatPhone(phone);

      await _authRepository.signUpWithEmail(
        email,
        password,
        phone,
      );
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  /// ======================================================
  /// LOGOUT
  /// ======================================================
  Future<void> logout() async {
    await _authRepository.signOut();
  }

  /// ======================================================
  /// FORMAT PHONE
  /// ======================================================
  String _formatPhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return '$clean@bingo.mk';
  }

  /// ======================================================
  /// CLEANUP
  /// ======================================================
  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }
}