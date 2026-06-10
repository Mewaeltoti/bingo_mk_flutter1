// lib/data/repositories/bingo_repository_render.dart
//
// Drop-in replacement for BingoRepositoryFirebase that routes all
// mutating operations (buyCard, registerCard, removeCard, claimBingo)
// through the Render/FastAPI backend instead of Cloud Functions.
//
// Firestore READS are kept (onSnapshot / get) — they still go directly
// to Firestore; that's free and fast.
//
// Setup:
//   1. Add to pubspec.yaml:
//        http: ^1.2.1
//   2. Set RENDER_API_URL in your .env or pass it via --dart-define:
//        flutter run --dart-define=RENDER_API_URL=https://bingo-mk-api.onrender.com
//   3. Register this class in service_locator.dart instead of
//      BingoRepositoryFirebase.

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../domain/entities/bingo_card.dart';
import '../../domain/repositories/bingo_repository.dart';
import '../../core/services/logger_service.dart';

class BingoRepositoryRender implements BingoRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // The Render service URL — set via --dart-define or a config class.
  static const String _baseUrl = String.fromEnvironment(
    'RENDER_API_URL',
    defaultValue: 'https://bingo-mk-api.onrender.com',
  );

  BingoRepositoryRender({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ─── helpers ───────────────────────────────────────────────────────────────

  Future<String> _idToken() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    return await user.getIdToken() ?? '';
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await _idToken();
    final response = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      final detail = data['detail'] ?? data['error'] ?? 'Unknown error';
      throw Exception(detail.toString());
    }
    return data;
  }

  // ─── Firestore read streams (unchanged — still hit Firestore directly) ──────

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
        .doc(sessionId)
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

  @override
  Stream<List<int>> streamDrawnNumbers(String gameId) {
    return streamGame(gameId).map((game) {
      return List<int>.from(game['drawnNumbers'] ?? []);
    });
  }

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

  @override
  Stream<List<Map<String, dynamic>>> streamGameWinners(String sessionId) {
    return _firestore
        .collection('game_history')
        .where('sessionId', isEqualTo: sessionId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {
                  'cardNo': d.data()['winningCardNo']?.toString() ?? '',
                  'sessionId': d.data()['sessionId']?.toString() ?? '',
                  'userId': d.data()['winnerId']?.toString() ?? '',
                  'phone': d.data()['winnerName'] ?? '',
                  'createdAt':
                      (d.data()['createdAt'] as Timestamp?)?.toDate(),
                })
            .toList());
  }

  @override
  Stream<double> streamBalance(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snap) =>
            (snap.data()?['balance'] as num?)?.toDouble() ?? 0.0);
  }

  @override
  Future<double> getBalance(String userId) async {
    try {
      final doc =
          await _firestore.collection('users').doc(userId).get();
      return (doc.data()?['balance'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      Log.e('getBalance failed', e);
      return 0.0;
    }
  }

  // ─── Mutating calls → Render/FastAPI ───────────────────────────────────────

  /// POST /cards/buy
  @override
  Future<void> buyCartelas(String userId, {int count = 1}) async {
    try {
      await _post('/cards/buy', {'count': count});
    } catch (e) {
      Log.e('buyCartelas failed', e);
      throw Exception('Failed to buy card: $e');
    }
  }

  /// POST /cards/register
  @override
  Future<void> registerCard(String cardId, List<int> numbers) async {
    try {
      await _post('/cards/register', {
        'cardId': cardId,
        'numbers': numbers,
      });
    } catch (e) {
      Log.e('registerCard failed', e);
      throw Exception('Failed to register card: $e');
    }
  }

  /// POST /cards/remove
  @override
  Future<void> removeCard(String cardId) async {
    try {
      await _post('/cards/remove', {'cardId': cardId});
    } catch (e) {
      Log.e('removeCard failed', e);
      throw Exception('Failed to remove card: $e');
    }
  }

  /// POST /cards/claim
  @override
  Future<bool?> claimBingo(
    String gameId,
    String cardId, {
    List<String> markedCells = const [],
  }) async {
    try {
      final result = await _post('/cards/claim', {
        'cardIds': [cardId],
        'markedCellsMap': {cardId: markedCells},
      });
      return result['success'] == true;
    } catch (e) {
      Log.e('claimBingo failed', e);
      rethrow;
    }
  }

  @override
  Future<bool?> claimMultipleBingo(
    String gameId,
    List<String> cardIds, {
    Map<String, List<String>> markedCellsMap = const {},
  }) async {
    try {
      final result = await _post('/cards/claim', {
        'cardIds': cardIds,
        'markedCellsMap': markedCellsMap,
      });
      return result['success'] == true;
    } catch (e) {
      Log.e('claimMultipleBingo failed', e);
      rethrow;
    }
  }

  // ─── drawNumber — server authoritative (admin uses /game/draw) ────────────

  @override
  Future<void> drawNumber(String gameId, int number) async {
    throw UnimplementedError(
        'Server-authoritative: admin calls POST /game/draw.');
  }

  @override
  Future<void> initializeGame() async {
    throw UnimplementedError(
        'Initialization is handled by the Render backend.');
  }

  // ─── Card queries ──────────────────────────────────────────────────────────

  @override
  Future<List<BingoCard>> getUserCartelas(
    String userId,
    String gameId, {
    String? sessionId,
  }) async {
    try {
      var query = _firestore
          .collection('users')
          .doc(userId)
          .collection('cards')
          .where('game_id', isEqualTo: 'live');
      if (sessionId != null && sessionId.isNotEmpty) {
        query = query.where('sessionId', isEqualTo: sessionId);
      }
      final snap =
          await query.orderBy('createdAt', descending: true).get();
      return snap.docs.map((doc) => _cardFromDoc(doc)).toList();
    } catch (e) {
      Log.e('getUserCartelas failed', e);
      return [];
    }
  }

  @override
  Future<List<BingoCard>> getPendingCards(String userId) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('cards')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((doc) => _cardFromDoc(doc)).toList();
    } catch (e) {
      Log.e('getPendingCards failed', e);
      return [];
    }
  }

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
    }
  }

  @override
  Future<void> broadcastBlockedCard(int cardNo) async {
    await _firestore
        .collection('games')
        .doc('live')
        .update({
      'allBlockedCardNos': FieldValue.arrayUnion([cardNo]),
    });
  }

  @override
  Future<void> resetCardsForSession(
      String userId, String sessionId) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('cards')
          .where('sessionId', isEqualTo: sessionId)
          .get();
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'status': 'pending'});
      }
      await batch.commit();
    } catch (e) {
      Log.e('resetCardsForSession failed', e);
    }
  }

  @override
  Future<void> deleteCardsForSession(
      String userId, String sessionId) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('cards')
          .where('sessionId', isEqualTo: sessionId)
          .get();
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      Log.e('deleteCardsForSession failed', e);
    }
  }

  @override
  Future<void> createGame(
      String gameId, Map<String, dynamic> data) async {
    await _firestore.collection('games').doc(gameId).set(data);
  }

  // ─── Wallet / transaction history ─────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getDeposits(
      String userId) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('deposits')
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getWithdrawals(
      String userId) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('withdrawals')
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> createDeposit(
      String userId, Map<String, dynamic> data) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('deposits')
        .add(data);
  }

  @override
  Future<void> createWithdrawal(
      String userId, Map<String, dynamic> data) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('withdrawals')
        .add(data);
  }

  @override
  Future<List<Map<String, dynamic>>> getGameHistory() async {
    try {
      final snap = await _firestore
          .collection('game_history')
          .orderBy('endTime', descending: true)
          .limit(50)
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getTopPlayers() async {
    try {
      final snap = await _firestore
          .collection('users')
          .orderBy('balance', descending: true)
          .limit(20)
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPaymentAccounts() async {
    try {
      final snap =
          await _firestore.collection('paymentAccounts').get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      return [];
    }
  }

  // ─── private helpers ───────────────────────────────────────────────────────

  BingoCard _cardFromDoc(DocumentSnapshot doc) {
    final row = doc.data() as Map<String, dynamic>;
    final flatNumbers =
        List<int>.from(row['numbers'] ?? []);
    final status = row['status'] as String? ?? 'pending';
    final cardNo = row['cardNo'] as int? ?? 0;
    final cardSessionId = (row['sessionId'] ?? '').toString();
    final createdAt =
        (row['createdAt'] as Timestamp?)?.toDate();
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
      cardNo: cardNo,
      numbers: grid,
      status: status,
      sessionId: cardSessionId,
      createdAt: createdAt,
      isBlocked: isBlocked,
      price: (row['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> _mapGameToCamelCase(
      Map<String, dynamic> data) {
    // Field names in Firestore are already camelCase; pass through.
    return data;
  }
}
