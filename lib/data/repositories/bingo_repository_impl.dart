import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/bingo_card.dart';
import '../../domain/repositories/bingo_repository.dart';

class BingoRepositoryImpl implements BingoRepository {
  final FirebaseFirestore _firestore;

  BingoRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> createGame(String gameId, Map<String, dynamic> data) async {
    await _firestore.collection('games').doc(gameId).set(data);
  }

  @override
  Stream<Map<String, dynamic>> streamGame(String gameId) {
    return _firestore
        .collection('games')
        .doc(gameId)
        .snapshots()
        .map((doc) => doc.data() ?? {});
  }

  @override
  Future<void> drawNumber(String gameId, int number) async {
    await _firestore.collection('games').doc(gameId).update({
      'drawnNumbers': FieldValue.arrayUnion([number]),
      'lastNumber': number,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> buyCartelas(String userId, List<BingoCard> cards) async {
    if (cards.isEmpty) return;

    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(userId);
    final cartelasCol = userRef.collection('cartelas');

    double totalCost = 0;
    for (var card in cards) {
      totalCost += card.price;
      final newCardRef = cartelasCol.doc(card.id); // Use card.id to prevent duplicates for the same user
      batch.set(newCardRef, {
        'cardId': card.id,
        'numbers': card.numbers.expand((i) => i).toList(), // Flatten 5x5 to 25 items
        'price': card.price,
        'purchasedAt': FieldValue.serverTimestamp(),
      });
    }

    // Deduct balance
    batch.update(userRef, {
      'balance': FieldValue.increment(-totalCost),
    });

    await batch.commit();
  }

  @override
  Future<List<BingoCard>> getUserCartelas(String userId, String gameId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('cartelas')
        // .where('gameId', isEqualTo: gameId) // Add this if gameId is stored
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final flatNumbers = (data['numbers'] as List).cast<int>();
      
      // Reshape flat list of 25 numbers back to 5x5 grid
      final List<List<int>> grid = [];
      for (var i = 0; i < 5; i++) {
        grid.add(flatNumbers.sublist(i * 5, (i + 1) * 5));
      }

      return BingoCard(
        id: data['cardId'],
        numbers: grid,
        price: (data['price'] as num).toDouble(),
      );
    }).toList();
  }

  @override
  Stream<List<int>> streamDrawnNumbers(String gameId) {
    return _firestore
        .collection('games')
        .doc(gameId)
        .snapshots()
        .map((doc) => (doc.data()?['drawnNumbers'] as List?)?.cast<int>() ?? []);
  }

  @override
  Future<double> getBalance(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return (doc.data()?['balance'] as num?)?.toDouble() ?? 0.0;
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
    await _firestore.collection('users').doc(userId).collection('deposits').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  @override
  Future<void> createWithdrawal(String userId, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(userId).collection('withdrawals').add({
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
    // This is an aggregation in Supabase, in Firestore we might need a separate collection
    // or just fetch recent winners and aggregate locally for now
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
      players[winnerId]!['totalPrize'] += (game['prize'] as num?)?.toDouble() ?? 0.0;
    }

    final sorted = players.values.toList()..sort((a, b) => (b['wins'] as int).compareTo(a['wins'] as int));
    return sorted;
  }

  @override
  Future<void> initializeGame() async {
    await _firestore.collection('games').doc('current_game').set({
      'status': 'buying',
      'pattern': 'Full House',
      'price': 10.0,
      'playerCount': 0,
      'cardsSoldCount': 0,
      'buyingCountdown': 120,
      'drawnNumbers': [],
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
