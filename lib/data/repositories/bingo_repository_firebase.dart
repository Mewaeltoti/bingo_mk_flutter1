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

 @override
Stream<List<int>> streamGameDraws(String sessionId) {
  return _firestore
      .collection('games')
      .doc('live')
      .collection('sessions')
      .doc(sessionId)              // single doc, not a filtered collection
      .snapshots()
      .map((snap) {
        if (!snap.exists || snap.data() == null) return <int>[];
        return List<int>.from(snap.data()!['numbers'] ?? []);
      });
}

@override
Future<List<int>> fetchDrawnNumbers(String sessionId) async {
  try {
    final snap = await _firestore
        .collection('games')
        .doc('live')
        .collection('sessions')
        .doc(sessionId)
        .get();
    if (!snap.exists || snap.data() == null) return [];
    return List<int>.from(snap.data()!['numbers'] ?? []);
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
  Stream<List<Map<String, dynamic>>> streamGameWinners(String sessionId) {
    return _firestore
        .collection('game_history')
        .where('sessionId', isEqualTo: sessionId)  // ← only current session
        .orderBy('createdAt', descending: true)
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
  // BLOCK CARD  (persists failed claim to Firestore so it survives restarts)
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Future<void> blockCard(String userId, String cardId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('cards')
          .doc(cardId)
          .update({'blocked': true});
    } catch (e) {
      Log.e('blockCard failed', e);
      // Non-fatal — blocked state will at least survive the current session
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
  Future<List<BingoCard>> getUserCartelas(String userId, String gameId, {String? sessionId}) async {
    try {
      // Pass sessionId to filter at the Firestore level, avoiding loading
      // all historic cards on every call (MEDIUM fix #7).
      var query = _firestore
          .collection('users')
          .doc(userId)
          .collection('cards')
          .where('game_id', isEqualTo: 'live');
      if (sessionId != null && sessionId.isNotEmpty) {
        query = query.where('sessionId', isEqualTo: sessionId);
      }
      final snap = await query.orderBy('createdAt', descending: true).get();

      return snap.docs.map((doc) {
        final row = doc.data();
        final flatNumbers = List<int>.from(row['numbers'] ?? []);
        final status = row['status'] as String? ?? 'pending';
        final cardNo = row['cardNo'] as int? ?? 0;
        final cardSessionId = (row['sessionId'] ?? '').toString();
        final createdAt = (row['createdAt'] as Timestamp?)?.toDate();
        final isBlocked = row['blocked'] as bool? ?? false;

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
          isBlocked: isBlocked,
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
            'bank': d.data()['bank'] ?? '',
            'accountNumber': d.data()['accountNumber'] ?? '',
            'status': d.data()['status'] ?? 'pending',
            'isReserved': d.data()['isReserved'] ?? false,
            'createdAt': (d.data()['createdAt'] as Timestamp?)?.toDate(),
            'reservedAt': (d.data()['reservedAt'] as Timestamp?)?.toDate(),
            'refundedAt': (d.data()['refundedAt'] as Timestamp?)?.toDate(),
            'verifiedAt': (d.data()['verifiedAt'] as Timestamp?)?.toDate(),
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
      final reference = (data['reference'] as String?)?.trim() ?? '';

      // Guard against duplicate submissions of the same bank transfer reference.
      if (reference.isNotEmpty) {
        final existing = await _firestore
            .collection('users')
            .doc(userId)
            .collection('deposits')
            .where('reference', isEqualTo: reference)
            .limit(1)
            .get();
        if (existing.docs.isNotEmpty) {
          throw Exception(
              'A deposit with reference "$reference" has already been submitted. '
              'Please wait for it to be verified.');
        }
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('deposits')
          .add({
        'amount': data['amount'],
        'reference': reference,
        'bank': data['bank'] ?? '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      Log.e('createDeposit Firebase error', e);
      throw Exception(_mapFirebaseError(e));
    } catch (e) {
      Log.e('createDeposit failed', e);
      rethrow;
    }
  }

  @override
  Future<void> createWithdrawal(String userId, Map<String, dynamic> data) async {
    // Pure Firestore write — no Cloud Function.
    // Balance is NOT reserved on submit. The admin approves and deducts manually.
    // This prevents the double-credit bug: if the CF reserved balance on submit
    // and the admin then rejected, the refund would add back money that was
    // never actually deducted from the user perspective — resulting in +ETB.
    final amount = (data['amount'] as num).toDouble();
    final bank = data['bank'] as String? ?? '';
    final accountNumber = data['accountNumber'] as String? ?? '';

    try {
      // Client-side balance check — give a clear error before writing.
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final balance = (userDoc.data()?['balance'] as num?)?.toDouble() ?? 0.0;
      if (amount > balance) {
        throw Exception(
          'Insufficient balance. You have ${balance.toStringAsFixed(2)} ETB available.',
        );
      }

      // Guard against accidental double-tap: block duplicate pending request
      // for same amount + account.
      final existing = await _firestore
          .collection('users')
          .doc(userId)
          .collection('withdrawals')
          .where('status', isEqualTo: 'pending')
          .where('amount', isEqualTo: amount)
          .where('accountNumber', isEqualTo: accountNumber)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        throw Exception(
          'A pending withdrawal of ${amount.toStringAsFixed(0)} ETB to this '
          'account already exists. Please wait for it to be processed.',
        );
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('withdrawals')
          .add({
        'amount': amount,
        'bank': bank,
        'accountNumber': accountNumber,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      Log.e('createWithdrawal error', e);
      if (e.code == 'permission-denied') {
        throw Exception('Withdrawal failed: permission denied. Please sign in again.');
      }
      throw Exception('Withdrawal failed. Please try again.');
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

  // ─────────────────────────────────────────────────────────────────────────
  // GET PAYMENT ACCOUNTS
  // Fetched from metadata/paymentAccounts so the admin can update bank
  // details without a new app release. Falls back to an empty list —
  // the UI shows a "no accounts configured" message instead of stale
  // hardcoded numbers.
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Future<List<Map<String, dynamic>>> getPaymentAccounts() async {
    try {
      final doc = await _firestore
          .collection('payment_settings')
          .doc('current')
          .get();

      if (!doc.exists || doc.data() == null) return [];

      final accounts = doc.data()!['accounts'];
      if (accounts is! List) return [];

      return accounts
          .whereType<Map>()
          .map((a) => Map<String, dynamic>.from(a))
          .toList();
    } catch (e) {
      Log.e('getPaymentAccounts failed', e);
      return [];
    }
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
  // RESET CARDS FOR SESSION
  // Belt-and-suspenders fallback: the Cloud Function (resetSessionCards.js)
  // is the primary reset path. This method is called by GameCubit when it
  // detects a sessionChanged transition so any cards the CF missed (e.g.,
  // offline users coming back) are still reset on the client side.
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Future<void> resetCardsForSession(String userId, String sessionId) async {
    if (sessionId.isEmpty) return;
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('cards')
          .where('sessionId', isEqualTo: sessionId)
          .where('status', isEqualTo: 'registered')
          .get();

      if (snap.docs.isEmpty) return;

      // Batch all updates into a single round-trip (max 500 ops per batch).
      const int batchSize = 500;
      var batch = _firestore.batch();
      int ops = 0;

      for (final doc in snap.docs) {
        batch.update(doc.reference, {
          'status': 'pending',
          'sessionId': '',
          'blocked': false,
        });
        ops++;
        if (ops == batchSize) {
          await batch.commit();
          batch = _firestore.batch();
          ops = 0;
        }
      }
      if (ops > 0) await batch.commit();

      Log.i('resetCardsForSession: reset ${snap.docs.length} card(s) '
            'from session $sessionId');
    } catch (e) {
      Log.e('resetCardsForSession failed', e);
      // Non-fatal — CF is the primary reset; this is a fallback.
    }
  }

  // In BingoRepositoryFirebase, add a batch version:
  Future<void> blockCards(String userId, List<String> cardIds) async {
    final batch = _firestore.batch();
    for (final cardId in cardIds) {
      final ref = _firestore.collection('users').doc(userId).collection('cards').doc(cardId);
      batch.update(ref, {'blocked': true});
    }
    await batch.commit();  // 1 round-trip instead of N
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BROADCAST BLOCKED CARD
  // Appends the blocked card number to games/live.blockedCardNos so every
  // connected player sees the blocked badge in real-time via streamGame.
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Future<void> broadcastBlockedCard(int cardNo) async {
    try {
      await _firestore
          .collection('games')
          .doc('live')
          .update({
            'blockedCardNos': FieldValue.arrayUnion([cardNo]),
          });
    } catch (e) {
      Log.e('broadcastBlockedCard failed', e);
      // Non-fatal — own blocked badge still shows locally.
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DELETE CARDS FOR SESSION
  // Permanently removes every card that belongs to [userId] for [sessionId].
  // Called by GameCubit when a session finishes or is canceled so stale cards
  // never bleed into the next game.
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Future<void> deleteCardsForSession(String userId, String sessionId) async {
    if (sessionId.isEmpty) return;
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('cards')
          .where('sessionId', isEqualTo: sessionId)
          .get();

      if (snap.docs.isEmpty) return;

      // Firestore batch allows up to 500 deletes per commit.
      const int batchSize = 500;
      var batch = _firestore.batch();
      int ops = 0;

      for (final doc in snap.docs) {
        batch.delete(doc.reference);
        ops++;
        if (ops == batchSize) {
          await batch.commit();
          batch = _firestore.batch();
          ops = 0;
        }
      }
      if (ops > 0) await batch.commit();

      Log.i('deleteCardsForSession: deleted \${snap.docs.length} card(s) '
            'for session \$sessionId');
    } catch (e) {
      Log.e('deleteCardsForSession failed', e);
      // Non-fatal — worst case the cards remain but are filtered by sessionId.
    }
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
      'blockedCardNos': List<int>.from(
          (row['blockedCardNos'] ?? row['blocked_card_nos'] ?? []).map((v) => (v as num).toInt())),
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ERROR MAPPING — never leak raw Firebase internals to the UI
  // ─────────────────────────────────────────────────────────────────────────
  String _mapFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You do not have permission to do that. Please sign in again.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Network error. Please check your connection and try again.';
      case 'not-found':
        return 'The requested item was not found.';
      case 'already-exists':
        return 'This item already exists.';
      case 'resource-exhausted':
        return 'Too many requests. Please wait a moment and try again.';
      case 'unauthenticated':
        return 'Session expired. Please sign in again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}