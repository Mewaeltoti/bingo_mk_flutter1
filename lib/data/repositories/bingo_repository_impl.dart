import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../domain/entities/bingo_card.dart';
import '../../domain/repositories/bingo_repository.dart';
import '../../core/services/logger_service.dart';

class BingoRepositoryImpl implements BingoRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  BingoRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  @override
  Future<void> createGame(String gameId, Map<String, dynamic> data) async {
    // Clients shouldn't create games directly anymore.
    // This could be kept if used by an admin SDK script, but typically disabled.
    throw UnimplementedError("Games are managed by the server.");
  }

  @override
  Stream<Map<String, dynamic>> streamGame(String gameId) {
    // We now enforce the single 'games/live' document
    return _firestore
        .collection('games')
        .doc('live')
        .snapshots()
        .map((doc) => doc.data() ?? {});
  }

  @override
  Future<void> drawNumber(String gameId, int number) async {
    // CLIENTS CAN NO LONGER DRAW NUMBERS
    throw UnimplementedError(
      "Server-authoritative architecture prevents clients from drawing numbers.",
    );
  }

  @override
  Future<void> buyCartelas(String userId, {int count = 1}) async {
    try {
      await _functions.httpsCallable('buyCard').call({'count': count});
    } catch (e) {
      throw Exception('Failed to buy card: $e');
    }
  }

  @override
  Future<void> registerCard(String cardId, List<int> numbers) async {
    try {
      await _functions.httpsCallable('registerCard').call({
        'cardId': cardId,
        'numbers': numbers,
      });
    } catch (e) {
      throw Exception('Failed to register card: $e');
    }
  }

  @override
  Future<void> removeCard(String cardId) async {
    try {
      await _functions.httpsCallable('removeCard').call({'cardId': cardId});
    } catch (e) {
      throw Exception('Failed to remove card: $e');
    }
  }

  @override
  Future<bool> claimBingo(String gameId, String cardId) async {
    try {
      final result = await _functions.httpsCallable('claimBingo').call({
        'cardId': cardId,
      });
      return result.data['success'] == true;
    } catch (e) {
      Log.e("Repository claimBingo failed", e);
      rethrow;
    }
  }

  @override
  Future<List<BingoCard>> getUserCartelas(String userId, String gameId) async {
    // We remove the Firestore-side orderBy to avoid requiring a composite index
    // and to ensure we don't skip documents that might be missing the timestamp.
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('cards')
        .where('gameId', isEqualTo: 'live')
        .get();

    final cards = snapshot.docs.map((doc) {
      final data = doc.data();
      final flatNumbers = (data['numbers'] as List?)?.cast<int>() ?? [];
      final status = data['status'] as String? ?? 'pending';
      final cardNo = data['cardNo'] as int? ?? 0;
      final cardSessionId = (data['sessionId'] ?? '').toString();
      final createdAt = data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null;

      final List<List<int>> grid = [];
      if (flatNumbers.length == 25) {
        for (var i = 0; i < 5; i++) {
          grid.add(flatNumbers.sublist(i * 5, (i + 1) * 5));
        }
      } else {
        for (var i = 0; i < 5; i++) {
          grid.add(List.filled(5, 0));
        }
      }

      final price = (data['price'] as num?)?.toDouble() ?? 10.0;

      return BingoCard(
        id: doc.id,
        numbers: grid,
        price: price,
        status: status,
        cardNo: cardNo,
        sessionId: cardSessionId,
        createdAt: createdAt,
      );
    }).toList();

    // Sort locally by createdAt (newest first)
    cards.sort((a, b) {
      if (a.createdAt == null) return 1;
      if (b.createdAt == null) return -1;
      return b.createdAt!.compareTo(a.createdAt!);
    });

    return cards;
  }

  @override
  Stream<List<int>> streamDrawnNumbers(String gameId) {
    return _firestore
        .collection('games')
        .doc('live')
        .snapshots()
        .map(
          (doc) => (doc.data()?['drawnNumbers'] as List?)?.cast<int>() ?? [],
        );
  }

  @override
  Future<double> getBalance(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return (doc.data()?['balance'] as num?)?.toDouble() ?? 0.0;
  }

  @override
  Stream<double> streamBalance(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => (doc.data()?['balance'] as num?)?.toDouble() ?? 0.0);
  }

  @override
  Future<List<Map<String, dynamic>>> getDeposits(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('deposits')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getWithdrawals(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('withdrawals')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  @override
  Future<void> createDeposit(String userId, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(userId).collection('deposits').add(
      {...data, 'createdAt': FieldValue.serverTimestamp(), 'status': 'pending'},
    );
  }

  @override
  Future<void> createWithdrawal(
    String userId,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('withdrawals')
        .add({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
  }

  @override
  Future<List<Map<String, dynamic>>> getGameHistory() async {
    final snapshot = await _firestore
        .collection('game_history')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getTopPlayers() async {
    final history = await getGameHistory();
    final Map<String, Map<String, dynamic>> players = {};

    for (var game in history) {
      final winnerId = game['winnerId'];
      if (winnerId == null) continue;

      if (!players.containsKey(winnerId)) {
        players[winnerId] = {
          'winnerId': winnerId,
          'wins': 0,
          'totalPrize': 0,
          'displayName': game['winnerName'],
        };
      }

      players[winnerId]!['wins'] += 1;
      players[winnerId]!['totalPrize'] +=
          (game['prize'] as num?)?.toDouble() ?? 0.0;
    }

    final sorted = players.values.toList()
      ..sort((a, b) => (b['wins'] as int).compareTo(a['wins'] as int));
    return sorted;
  }

  @override
  Future<List<Map<String, dynamic>>> getPaymentAccounts() async {
    try {
      final doc = await _firestore.collection('metadata').doc('payment_info').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['accounts'] != null) {
          final list = data['accounts'] as List;
          return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        }
      }
    } catch (e) {
      Log.e("Failed to get payment accounts from Firestore", e);
    }
    // Fallback to default accounts if document doesn't exist or load fails
    return [
      {'bank': 'Telebirr', 'number': '0978187178', 'name': 'Ephrem'},
      {'bank': 'CBE', 'number': '1000217643426', 'name': 'Ephrem'},
    ];
  }

  @override
  Future<void> initializeGame() async {
    throw UnimplementedError(
      "Initialization is handled by Admin Dashboard via Cloud Functions.",
    );
  }
}
