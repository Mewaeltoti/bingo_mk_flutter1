import '../../domain/entities/bingo_card.dart';

abstract class BingoRepository {
  Future<void> createGame(String gameId, Map<String, dynamic> data);
  Stream<Map<String, dynamic>> streamGame(String gameId);
  Future<void> drawNumber(String gameId, int number);
  Future<void> buyCartelas(String userId, List<BingoCard> cards);
  Future<List<BingoCard>> getUserCartelas(String userId, String gameId);
  Future<double> getBalance(String userId);
  Future<List<Map<String, dynamic>>> getDeposits(String userId);
  Future<List<Map<String, dynamic>>> getWithdrawals(String userId);
  Future<void> createDeposit(String userId, Map<String, dynamic> data);
  Future<void> createWithdrawal(String userId, Map<String, dynamic> data);
  Stream<List<int>> streamDrawnNumbers(String gameId);
  Future<List<Map<String, dynamic>>> getGameHistory();
  Future<List<Map<String, dynamic>>> getTopPlayers();
  Future<void> initializeGame();
}
