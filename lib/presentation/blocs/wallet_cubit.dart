import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/bingo_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WALLET LIMITS MODEL
// Read from Firestore: metadata/paymentLimits
// ─────────────────────────────────────────────────────────────────────────────
class WalletLimits extends Equatable {
  final double minDeposit;
  final double maxDeposit;
  final double minWithdraw;
  final double maxWithdraw;

  const WalletLimits({
    this.minDeposit = 50,
    this.maxDeposit = 50000,
    this.minWithdraw = 50,
    this.maxWithdraw = 10000,
  });

  factory WalletLimits.fromMap(Map<String, dynamic> map) {
    return WalletLimits(
      minDeposit: (map['minDeposit'] as num?)?.toDouble() ?? 50,
      maxDeposit: (map['maxDeposit'] as num?)?.toDouble() ?? 50000,
      minWithdraw: (map['minWithdraw'] as num?)?.toDouble() ?? 50,
      maxWithdraw: (map['maxWithdraw'] as num?)?.toDouble() ?? 10000,
    );
  }

  @override
  List<Object?> get props => [minDeposit, maxDeposit, minWithdraw, maxWithdraw];
}

// ─────────────────────────────────────────────────────────────────────────────
// STATES
// ─────────────────────────────────────────────────────────────────────────────
abstract class WalletState extends Equatable {
  @override
  List<Object?> get props => [];
}

class WalletInitial extends WalletState {}

class WalletLoading extends WalletState {}

class WalletLoaded extends WalletState {
  final double balance;
  final List<Map<String, dynamic>> deposits;
  final List<Map<String, dynamic>> withdrawals;
  final List<Map<String, dynamic>> bankAccounts;
  final WalletLimits limits;
  final bool isActionLoading;
  final String? statusMessage;

  WalletLoaded({
    required this.balance,
    required this.deposits,
    required this.withdrawals,
    this.bankAccounts = const [],
    this.limits = const WalletLimits(),
    this.isActionLoading = false,
    this.statusMessage,
  });

  @override
  List<Object?> get props =>
      [balance, deposits, withdrawals, bankAccounts, limits, isActionLoading, statusMessage];

  WalletLoaded copyWith({
    double? balance,
    List<Map<String, dynamic>>? deposits,
    List<Map<String, dynamic>>? withdrawals,
    List<Map<String, dynamic>>? bankAccounts,
    WalletLimits? limits,
    bool? isActionLoading,
    String? statusMessage,
  }) {
    return WalletLoaded(
      balance: balance ?? this.balance,
      deposits: deposits ?? this.deposits,
      withdrawals: withdrawals ?? this.withdrawals,
      bankAccounts: bankAccounts ?? this.bankAccounts,
      limits: limits ?? this.limits,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      statusMessage: statusMessage,  // null clears the message intentionally
    );
  }
}

class WalletError extends WalletState {
  final String message;
  WalletError(this.message);

  @override
  List<Object?> get props => [message];
}

// ─────────────────────────────────────────────────────────────────────────────
// CUBIT
// ─────────────────────────────────────────────────────────────────────────────
class WalletCubit extends Cubit<WalletState> {
  final BingoRepository _bingoRepository;
  final String userId;
  StreamSubscription? _balanceSubscription;

  WalletCubit({
    required BingoRepository bingoRepository,
    required this.userId,
  })  : _bingoRepository = bingoRepository,
        super(WalletInitial()) {
    _init();
  }

  void _init() {
    _balanceSubscription =
        _bingoRepository.streamBalance(userId).listen((balance) {
      if (state is WalletLoaded) {
        final current = state as WalletLoaded;
        // Do NOT forward statusMessage — balance stream ticks should
        // silently clear any lingering error banner.
        emit(WalletLoaded(
          balance: balance,
          deposits: current.deposits,
          withdrawals: current.withdrawals,
          bankAccounts: current.bankAccounts,
          limits: current.limits,
          isActionLoading: current.isActionLoading,
          statusMessage: null,
        ));
      } else if (state is WalletInitial) {
        loadWallet();
      }
    });
  }


  /// Returns a user-friendly error message, never exposing raw Firebase strings.
  String _friendlyError(Object e, {String? prefix}) {
    String message;
    final s = e.toString().toLowerCase();
    if (s.contains('permission') || s.contains('permission-denied')) {
      message = e.toString().contains('sign in') 
          ? e.toString().replaceAll('Exception: ', '')
          : 'Permission denied. Please sign in again.';
    } else if (s.contains('network') || s.contains('unavailable')) {
      message = 'Network error. Please check your connection.';
    } else if (s.contains('unauthenticated')) {
      message = 'Session expired. Please sign in again.';
    } else if (s.contains('already been submitted') || s.contains('already exists') ||
               s.contains('pending withdrawal') || s.contains('already exists')) {
      // Preserve duplicate-reference / duplicate-withdrawal messages — already user-friendly
      message = e.toString().replaceAll('Exception: ', '');
    } else if (s.contains('insufficient') || s.contains('available:')) {
      message = e.toString().replaceAll('Exception: ', '');
    } else {
      message = 'Something went wrong. Please try again.';
    }
    if (prefix != null) return '$prefix: $message';
    return message;
  }

  @override
  Future<void> close() {
    _balanceSubscription?.cancel();
    return super.close();
  }

  // ─── Load wallet (balance + history + accounts + limits) ───────────────────
  Future<void> loadWallet() async {
    emit(WalletLoading());
    try {
      final results = await Future.wait([
        _bingoRepository.getBalance(userId),
        _bingoRepository.getDeposits(userId),
        _bingoRepository.getWithdrawals(userId),
        _bingoRepository.getPaymentAccounts(),
        _fetchLimits(),
      ]);

      emit(WalletLoaded(
        balance: results[0] as double,
        deposits: results[1] as List<Map<String, dynamic>>,
        withdrawals: results[2] as List<Map<String, dynamic>>,
        bankAccounts: results[3] as List<Map<String, dynamic>>,
        limits: results[4] as WalletLimits,
      ));
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  // ─── Fetch min/max limits from Firestore metadata/paymentLimits ────────────
  Future<WalletLimits> _fetchLimits() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('metadata')
          .doc('paymentLimits')
          .get();
      if (doc.exists && doc.data() != null) {
        return WalletLimits.fromMap(doc.data()!);
      }
    } catch (_) {
      // Fall through to defaults if metadata doc doesn't exist yet
    }
    return const WalletLimits();
  }

  // ─── Validate deposit amount against limits ────────────────────────────────
  /// Returns an error string, or null if valid.
  String? validateDeposit(double amount) {
    final limits = state is WalletLoaded
        ? (state as WalletLoaded).limits
        : const WalletLimits();
    if (amount < limits.minDeposit) {
      return 'Minimum deposit is ${limits.minDeposit.toStringAsFixed(0)} ETB';
    }
    if (amount > limits.maxDeposit) {
      return 'Maximum deposit is ${limits.maxDeposit.toStringAsFixed(0)} ETB';
    }
    return null;
  }

  // ─── Validate withdrawal amount against limits and balance ─────────────────
  /// Returns an error string, or null if valid.
  String? validateWithdrawal(double amount) {
    final limits = state is WalletLoaded
        ? (state as WalletLoaded).limits
        : const WalletLimits();
    final balance =
        state is WalletLoaded ? (state as WalletLoaded).balance : 0.0;

    if (amount < limits.minWithdraw) {
      return 'Minimum withdrawal is ${limits.minWithdraw.toStringAsFixed(0)} ETB';
    }
    if (amount > limits.maxWithdraw) {
      return 'Maximum withdrawal is ${limits.maxWithdraw.toStringAsFixed(0)} ETB';
    }
    if (amount > balance) {
      return 'Insufficient balance (${balance.toStringAsFixed(2)} ETB available)';
    }
    return null;
  }

  // ─── Deposit ───────────────────────────────────────────────────────────────
  Future<void> deposit(
      double amount, String bank, String reference) async {
    // Capture the loaded state BEFORE any async work so we can restore it on
    // failure. The old pattern emitted WalletError on catch then checked
    // `state is WalletLoaded` in finally — which was always false after an
    // error, so the loading spinner never cleared and the page was stuck.
    final loaded = state is WalletLoaded ? state as WalletLoaded : null;
    if (loaded != null) emit(loaded.copyWith(isActionLoading: true));

    try {
      await _bingoRepository.createDeposit(userId, {
        'amount': amount,
        'bank': bank,
        'reference': reference,
      });
      await loadWallet();
    } catch (e) {
      // Restore the previous loaded state with the error surfaced as a
      // statusMessage so the wallet page stays functional.
      if (!isClosed) {
        emit(loaded?.copyWith(
              isActionLoading: false,
              statusMessage: _friendlyError(e, prefix: 'Deposit failed'),
            ) ??
            WalletError(e.toString()));
      }
    }
  }

  // ─── Withdraw ──────────────────────────────────────────────────────────────
  Future<void> withdraw(
      double amount, String bank, String accountNumber) async {
    final loaded = state is WalletLoaded ? state as WalletLoaded : null;
    if (loaded != null) emit(loaded.copyWith(isActionLoading: true));

    try {
      await _bingoRepository.createWithdrawal(userId, {
        'amount': amount,
        'bank': bank,
        'accountNumber': accountNumber,
      });
      await loadWallet();
    } catch (e) {
      if (!isClosed) {
        emit(loaded?.copyWith(
              isActionLoading: false,
              statusMessage: _friendlyError(e, prefix: 'Withdrawal failed'),
            ) ??
            WalletError(e.toString()));
      }
    }
  }

  // ─── Delete rejected transaction ───────────────────────────────────────────
  Future<void> deleteTransaction(
      String collectionPath, String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(collectionPath)
          .doc(docId)
          .delete();
      await loadWallet();
    } catch (e) {
      // Silent: deletion failure is non-critical
    }
  }

  // ─── Save FCM token for push notifications ─────────────────────────────────
  Future<void> saveFcmToken(String token) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({'fcmToken': token}, SetOptions(merge: true));
    } catch (_) {}
  }
}