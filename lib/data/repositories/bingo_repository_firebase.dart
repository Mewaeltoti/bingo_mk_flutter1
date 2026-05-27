import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../domain/entities/bingo_card.dart';
import '../../domain/repositories/bingo_repository.dart';
import '../../core/services/logger_service.dart';

class BingoRepositoryFirebase implements BingoRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  BingoRepositoryFirebase({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  // ─────────────────────────────────────────────────────────────────────────
  // STREAM GAME
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Stream<Map<String, dynamic>> streamGame(String gameId) {
    return _firestore
        .collection('games')
        .doc(gameId)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return <String, dynamic>{};
      return _mapGameToCamelCase(snap.data()!);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STREAM GAME DRAWS
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Stream<int> streamGameDraws(String sessionId) {
    final controller = StreamController<int>();

    final sub = _firestore
        .collection('games')
        .doc('live')
        .collection('draws')
        .where('sessionId', isEqualTo: sessionId)
        .orderBy('drawnAt')
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final number = change.doc.data()?['number'] as int?;
          if (number != null && !controller.isClosed) {
            controller.add(number);
          }
        }
      }
    });

    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FETCH DRAWN NUMBERS
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Future<List<int>> fetchDrawnNumbers(String sessionId) async {
    try {
      final snap = await _firestore
          .collection('games')
          .doc('live')
          .collection('draws')
          .where('sessionId', isEqualTo: sessionId)
          .orderBy('drawnAt')
          .get();
      return snap.docs
          .map((d) => d.data()['number'] as int? ?? 0)
          .where((n) => n > 0)
          .toList();
    } catch (e) {
      Log.e('fetchDrawnNumbers failed', e);
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STREAM DRAWN NUMBERS  (derived from streamGame)
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Stream<List<int>> streamDrawnNumbers(String gameId) {
    return streamGame(gameId).map((game) {
      return List<int>.from(game['drawnNumbers'] ?? []);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET LIVE SESSION ID
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Future<String> getLiveSessionId() async {
    try {
      final doc = await _firestore.collection('games').doc('live').get();
      return doc.data()?['sessionId']?.toString() ?? '';
    } catch (e) {
      Log.e('getLiveSessionId failed', e);
      return '';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STREAM GAME WINNERS
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Stream<List<Map<String, dynamic>>> streamGameWinners() {
    return _firestore
        .collection('game_history')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {
                  'cardNo': d.data()['winningCardNo']?.toString() ?? '',
                  'sessionId': d.data()['sessionId']?.toString() ?? '',
                  'userId': d.data()['winnerId']?.toString() ?? '',
                  'phone': d.data()['winnerName'] ?? '',
                  'createdAt': (d.data()['createdAt'] as Timestamp?)?.toDate(),
                })
            .toList());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STREAM BALANCE
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Stream<double> streamBalance(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snap) => (snap.data()?['balance'] as num?)?.toDouble() ?? 0.0);
  }

  @override
  Future<double> getBalance(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return (doc.data()?['balance'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      Log.e('getBalance failed', e);
      return 0.0;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUY CARTELAS  (calls Cloud Function)
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Future<void> buyCartelas(String userId, {int count = 1}) async {
    try {
      final callable = _functions.httpsCallable('buyCard');
      final result = await callable.call({'count': count});
      if (result.data['error'] != null) {
        throw Exception(result.data['error']);
      }
    } catch (e) {
      Log.e('buyCartelas failed', e);
      throw Exception('Failed to buy card: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REGISTER CARD  (calls Cloud Function, with jitter to spread burst load)
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Future<void> registerCard(String cardId, List<int> numbers) async {
    // Spread simultaneous purchases across 0–3 seconds to reduce CF contention
    final jitterMs = Random().nextInt(3000);
    await Future.delayed(Duration(milliseconds: jitterMs));

    try {
      final callable = _functions.httpsCallable(
        'registerCard',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      final result = await callable.call({'cardId': cardId, 'numbers': numbers});
      if (result.data['error'] != null) {
        throw Exception(result.data['error']);
      }
    } catch (e) {
      Log.e('registerCard failed', e);
      throw Exception('Failed to register card: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REMOVE CARD  (calls Cloud Function — handles refund + assignment cleanup)
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Future<void> removeCard(String cardId) async {
    try {
      // Route through the Cloud Function so refund + cardAssignment cleanup
      // happen atomically — direct Firestore delete skips both.
      final callable = _functions.httpsCallable('removeCard');
      final result = await callable.call({'cardId': cardId});
      if (result.data['error'] != null) {
        throw Exception(result.data['error']);
      }
    } catch (e) {
      Log.e('removeCard failed', e);
      throw Exception('Failed to remove card: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CLAIM BINGO  (calls Cloud Function)
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Future<bool> claimBingo(
    String gameId,
    String cardId, {
    List<String> markedCells = const [],
  }) async {
    try {
      final callable = _functions.httpsCallable('claimBingo');
      final result = await callable.call({
        'cardIds': [cardId],
        'markedCellsMap': {cardId: markedCells},
      });
      if (result.data['error'] != null) {
        throw Exception(result.data['error']);
      }
      return result.data['success'] == true;
    } catch (e) {
      Log.e('claimBingo failed', e);
      rethrow;
    }
  }

  @override
  Future<bool> claimMultipleBingo(
    String gameId,
    List<String> cardIds, {
    Map<String, List<String>> markedCellsMap = const {},
  }) async {
    try {
      final callable = _functions.httpsCallable('claimBingo');
      final result = await callable.call({
        'cardIds': cardIds,
        'markedCellsMap': markedCellsMap,
      });
      if (result.data['error'] != null) {
        throw Exception(result.data['error']);
      }
      return result.data['success'] == true;
    } catch (e) {
      Log.e('claimMultipleBingo failed', e);
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GET USER CARTELAS
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Future<List<BingoCard>> getUserCartelas(String userId, String gameId) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('cards')
          .where('game_id', isEqualTo: 'live')
          .orderBy('createdAt', descending: true)
          .get();

      return snap.docs.map((doc) {
        final row = doc.data();
        final flatNumbers = List<int>.from(row['numbers'] ?? []);
        final status = row['status'] as String? ?? 'pending';
        final cardNo = row['cardNo'] as int? ?? 0;
        final cardSessionId = (row['sessionId'] ?? '').toString();
        final createdAt = (row['createdAt'] as Timestamp?)?.toDate();

        List<List<int>> grid = [];
        if (flatNumbers.length == 25) {
          for (var i = 0; i < 5; i++) {
            grid.add(flatNumbers.sublist(i * 5, (i + 1) * 5));
          }
        } else if (flatNumbers.length == 24) {
          final full = List<int>.from(flatNumbers)..insert(12, 0);
          for (var i = 0; i < 5; i++) {
            grid.add(full.sublist(i * 5, (i + 1) * 5));
          }
        } else {
          grid = List.generate(5, (_) => List.filled(5, 0));
        }

        return BingoCard(
          id: doc.id,
          numbers: grid,
          price: 10.0,
          status: status,
          cardNo: cardNo,
          sessionId: cardSessionId,
          createdAt: createdAt,
        );
      }).toList();
    } catch (e) {
      Log.e('getUserCartelas failed', e);
      throw Exception('Failed to get user cards: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DEPOSITS & WITHDRAWALS
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Future<List<Map<String, dynamic>>> getDeposits(String userId) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('deposits')
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((d) => {
            'id': d.id,
            'userId': userId,
            'amount': (d.data()['amount'] as num?)?.toDouble() ?? 0.0,
            'reference': d.data()['reference'] ?? '',
            'status': d.data()['status'] ?? 'pending',
            'createdAt': (d.data()['createdAt'] as Timestamp?)?.toDate(),
            'verifiedAt': (d.data()['verifiedAt'] as Timestamp?)?.toDate(),
            'matchedVia': d.data()['matchedVia'],
            'rejectionReason': d.data()['rejectionReason'],
          }).toList();
    } catch (e) {
      Log.e('getDeposits failed', e);
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getWithdrawals(String userId) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('withdrawals')
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((d) => {
            'id': d.id,
            'userId': userId,
            'amount': (d.data()['amount'] as num?)?.toDouble() ?? 0.0,
            'status': d.data()['status'] ?? 'pending',
            'isReserved': d.data()['isReserved'] ?? false,
            'createdAt': (d.data()['createdAt'] as Timestamp?)?.toDate(),
            'reservedAt': (d.data()['reservedAt'] as Timestamp?)?.toDate(),
            'refundedAt': (d.data()['refundedAt'] as Timestamp?)?.toDate(),
            'rejectionReason': d.data()['rejectionReason'],
          }).toList();
    } catch (e) {
      Log.e('getWithdrawals failed', e);
      return [];
    }
  }

  @override
  Future<void> createDeposit(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('deposits')
          .add({
        'amount': data['amount'],
        'reference': data['reference'],
        'bank': data['bank'] ?? '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      Log.e('createDeposit failed', e);
      rethrow;
    }
  }

  @override
  Future<void> createWithdrawal(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('withdrawals')
          .add({
        'amount': data['amount'],
        'bank': data['bank'] ?? '',
        'accountNumber': data['accountNumber'] ?? '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      Log.e('createWithdrawal failed', e);
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GAME HISTORY & TOP PLAYERS
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Future<List<Map<String, dynamic>>> getGameHistory() async {
    try {
      final snap = await _firestore
          .collection('game_history')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      return snap.docs.map((d) => {
            'id': d.id,
            'sessionId': d.data()['sessionId'] ?? '',
            'status': d.data()['status'] ?? '',
            'prize': (d.data()['prize'] as num?)?.toDouble() ?? 0.0,
            'drawnNumbers': List<int>.from(d.data()['drawnNumbers'] ?? []),
            'cardsSold': d.data()['cardsSold'] ?? 0,
            'winnerId': d.data()['winnerId'],
            'winnerName': d.data()['winnerName'],
            'winningCardNo': d.data()['winningCardNo'],
            'createdAt': (d.data()['createdAt'] as Timestamp?)?.toDate(),
          }).toList();
    } catch (e) {
      Log.e('getGameHistory failed', e);
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getTopPlayers() async {
    try {
      final history = await getGameHistory();
      final Map<String, Map<String, dynamic>> players = {};
      for (var game in history) {
        final winnerId = game['winnerId'];
        if (winnerId == null) continue;
        if (!players.containsKey(winnerId)) {
          players[winnerId] = {
            'winnerId': winnerId,
            'wins': 0,
            'totalPrize': 0.0,
            'displayName': game['winnerName'] ?? 'Player',
          };
        }
        players[winnerId]!['wins'] = (players[winnerId]!['wins'] as int) + 1;
        players[winnerId]!['totalPrize'] =
            (players[winnerId]!['totalPrize'] as double) +
                ((game['prize'] as num?)?.toDouble() ?? 0.0);
      }
      return players.values.toList()
        ..sort((a, b) => (b['wins'] as int).compareTo(a['wins'] as int));
    } catch (e) {
      Log.e('getTopPlayers failed', e);
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPaymentAccounts() async {
    return [
      {
        'bank': 'Commercial Bank of Ethiopia (CBE)',
        'accountName': 'Bingo MK Games',
        'accountNumber': '1000123456789',
        'instructions':
            'Send to this CBE account and submit the transaction reference.',
      },
      {
        'bank': 'Telebirr',
        'accountName': 'Bingo MK Games Mobile',
        'accountNumber': '0912345678',
        'instructions':
            'Send via Telebirr to this number and submit the reference.',
      }
    ];
  }

  @override
  Future<void> createGame(String gameId, Map<String, dynamic> data) async {
    throw UnimplementedError("Games are managed by the server.");
  }

  @override
  Future<void> drawNumber(String gameId, int number) async {
    throw UnimplementedError("Server-authoritative: Cloud Functions drive draws.");
  }

  @override
  Future<void> initializeGame() async {
    throw UnimplementedError("Initialization is handled by Cloud Functions.");
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE: Map raw Firestore data → camelCase for GameCubit
  // ─────────────────────────────────────────────────────────────────────────
  Map<String, dynamic> _mapGameToCamelCase(Map<String, dynamic> row) {
    final pendingClaims =
        ((row['pendingClaims'] ?? row['pending_claims'] ?? []) as List)
            .map((c) => Map<String, dynamic>.from(c as Map))
            .toList();

    final claims =
        pendingClaims.map((c) => (c['cardId'] ?? '').toString()).toList();

    return {
      'status': row['status'] ?? 'waiting',
      'sessionId': row['sessionId']?.toString() ??
          row['session_id']?.toString() ??
          '',
      'drawnNumbers':
          List<int>.from(row['drawnNumbers'] ?? row['drawn_numbers'] ?? []),
      'isPaused': row['isPaused'] ?? row['is_paused'] ?? false,
      'prizePool':
          ((row['prizePool'] ?? row['prize_pool'] ?? 0.0) as num).toDouble(),
      'cardPrice':
          ((row['cardPrice'] ?? row['card_price'] ?? 10.0) as num).toDouble(),
      'gamePattern':
          row['gamePattern'] ?? row['game_pattern'] ?? 'full_house',
      'currentNumber': row['currentNumber'] ?? row['current_number'],
      'lastDrawTime': row['lastDrawTime'] ?? row['last_draw_time'],
      'winners': List<String>.from(row['winners'] ?? []),
      'winnerId': row['winnerId'] ?? row['winner_id'],
      'winningCardNo': row['winningCardNo'] ?? row['winning_card_no'],
      'winningCardNumbers': row['winningCardNumbers'] != null
          ? List<int>.from(row['winningCardNumbers'])
          : (row['winning_card_numbers'] != null
              ? List<int>.from(row['winning_card_numbers'])
              : null),
      'statusMessage':
          row['statusMessage'] ?? row['status_message'] ?? '',
      'cardsSold': row['cardsSold'] ?? row['cards_sold'] ?? 0,
      'playersCount': row['playersCount'] ?? row['players_count'] ?? 0,
      'createdAt':
          row['startTime'] ?? row['start_time'] ?? row['lastDrawTime'],
      'claimDeadline': row['claimDeadline'] ?? row['claim_deadline'],
      'pendingClaims': pendingClaims,
      'claims': claims,
      'confirmedWinners':
          ((row['confirmedWinners'] ?? row['confirmed_winners'] ?? []) as List)
              .map((c) => Map<String, dynamic>.from(c as Map))
              .toList(),
      'broadcastMessage':
          row['broadcastMessage'] ?? row['broadcast_message'],
    };
  }
}