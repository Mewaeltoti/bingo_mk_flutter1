import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/repositories/bingo_repository.dart';

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
  final bool isActionLoading;

  WalletLoaded({
    required this.balance,
    required this.deposits,
    required this.withdrawals,
    this.isActionLoading = false,
  });

  @override
  List<Object?> get props => [balance, deposits, withdrawals, isActionLoading];

  WalletLoaded copyWith({
    double? balance,
    List<Map<String, dynamic>>? deposits,
    List<Map<String, dynamic>>? withdrawals,
    bool? isActionLoading,
  }) {
    return WalletLoaded(
      balance: balance ?? this.balance,
      deposits: deposits ?? this.deposits,
      withdrawals: withdrawals ?? this.withdrawals,
      isActionLoading: isActionLoading ?? this.isActionLoading,
    );
  }
}
class WalletError extends WalletState {
  final String message;
  WalletError(this.message);
}

class WalletCubit extends Cubit<WalletState> {
  final BingoRepository _bingoRepository;
  final String userId;
  StreamSubscription? _balanceSubscription;

  WalletCubit({
    required BingoRepository bingoRepository,
    required this.userId,
  }) : _bingoRepository = bingoRepository, super(WalletInitial()) {
    _init();
  }

  void _init() {
    _balanceSubscription = _bingoRepository.streamBalance(userId).listen((balance) {
      if (state is WalletLoaded) {
        emit((state as WalletLoaded).copyWith(balance: balance));
      } else if (state is WalletInitial) {
        loadWallet(); // Initially load everything
      }
    });
  }

  @override
  Future<void> close() {
    _balanceSubscription?.cancel();
    return super.close();
  }

  Future<void> loadWallet() async {
    emit(WalletLoading());
    try {
      final balance = await _bingoRepository.getBalance(userId);
      final deposits = await _bingoRepository.getDeposits(userId);
      final withdrawals = await _bingoRepository.getWithdrawals(userId);
      emit(WalletLoaded(
        balance: balance,
        deposits: deposits,
        withdrawals: withdrawals,
      ));
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  Future<void> deposit(double amount, String bank, String reference) async {
    final current = state;
    if (current is WalletLoaded) {
      emit(current.copyWith(isActionLoading: true));
    }
    try {
      await _bingoRepository.createDeposit(userId, {
        'amount': amount,
        'bank': bank,
        'reference': reference,
      });
      await loadWallet();
    } catch (e) {
      emit(WalletError(e.toString()));
    } finally {
      if (state is WalletLoaded) {
        emit((state as WalletLoaded).copyWith(isActionLoading: false));
      }
    }
  }

  Future<void> withdraw(double amount, String bank, String accountNumber) async {
    final current = state;
    if (current is WalletLoaded) {
      emit(current.copyWith(isActionLoading: true));
    }
    try {
      await _bingoRepository.createWithdrawal(userId, {
        'amount': amount,
        'bank': bank,
        'accountNumber': accountNumber,
      });
      await loadWallet();
    } catch (e) {
      emit(WalletError(e.toString()));
    } finally {
      if (state is WalletLoaded) {
        emit((state as WalletLoaded).copyWith(isActionLoading: false));
      }
    }
  }
}
