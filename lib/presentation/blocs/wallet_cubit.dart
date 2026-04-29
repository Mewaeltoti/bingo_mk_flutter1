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

  WalletLoaded({
    required this.balance,
    required this.deposits,
    required this.withdrawals,
  });

  @override
  List<Object?> get props => [balance, deposits, withdrawals];
}
class WalletError extends WalletState {
  final String message;
  WalletError(this.message);
}

class WalletCubit extends Cubit<WalletState> {
  final BingoRepository _bingoRepository;
  final String userId;

  WalletCubit({
    required BingoRepository bingoRepository,
    required this.userId,
  }) : _bingoRepository = bingoRepository, super(WalletInitial());

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
    try {
      await _bingoRepository.createDeposit(userId, {
        'amount': amount,
        'bank': bank,
        'reference': reference,
      });
      await loadWallet();
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  Future<void> withdraw(double amount, String bank, String accountNumber) async {
    try {
      await _bingoRepository.createWithdrawal(userId, {
        'amount': amount,
        'bank': bank,
        'accountNumber': accountNumber,
      });
      await loadWallet();
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }
}
