import '../../domain/entities/bingo_card.dart';

abstract class BingoRepository {
  Future<void> createGame(String gameId, Map<String, dynamic> data);
  Stream<Map<String, dynamic>> streamGame(String gameId);
  Stream<List<Map<String, dynamic>>> streamGameWinners(String sessionId);
  Future<void> drawNumber(String gameId, int number);
  Future<void> buyCartelas(String userId, {int count = 1});
  Future<void> registerCard(String cardId, List<int> numbers);
  Future<void> removeCard(String cardId);
  Future<void> blockCard(String userId, String cardId);
  Future<bool?> claimBingo(String gameId, String cardId, {List<String> markedCells = const []});
  Future<bool?> claimMultipleBingo(String gameId, List<String> cardIds, {Map<String, List<String>> markedCellsMap = const {}});
  Future<List<BingoCard>> getUserCartelas(String userId, String gameId, {String? sessionId});
  Future<double> getBalance(String userId);
  Stream<double> streamBalance(String userId);
  Future<List<Map<String, dynamic>>> getDeposits(String userId);
  Future<List<Map<String, dynamic>>> getWithdrawals(String userId);
  Future<void> createDeposit(String userId, Map<String, dynamic> data);
  Future<void> createWithdrawal(String userId, Map<String, dynamic> data);
  Stream<List<int>> streamDrawnNumbers(String gameId);

  /// v2: lightweight per-number draw stream (game_draws table INSERTs)
  Stream<List<int>> streamGameDraws(String sessionId);

  /// v2: fetch all drawn numbers for a session on initial load
  Future<List<int>> fetchDrawnNumbers(String sessionId);

  /// v2: fetch the current live game's session_id (used by GameCubit on init)
  Future<String> getLiveSessionId();

  Future<List<Map<String, dynamic>>> getGameHistory();
  Future<List<Map<String, dynamic>>> getTopPlayers();
  Future<List<Map<String, dynamic>>> getPaymentAccounts();
  Future<void> initializeGame();
}
  /// Resets all of the current user's cards from [sessionId] back to
  /// status:'pending' so they appear as available for the next game.
  /// Called by the Flutter client as a belt-and-suspenders fallback
  /// (the Cloud Function is the primary reset path).
  Future<void> resetCardsForSession(String userId, String sessionId);
