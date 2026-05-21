import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/bingo_card.dart';
import '../../domain/repositories/bingo_repository.dart';
import '../../core/services/logger_service.dart';

class BingoRepositorySupabase implements BingoRepository {
  final SupabaseClient _client;

  BingoRepositorySupabase({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<void> createGame(String gameId, Map<String, dynamic> data) async {
    throw UnimplementedError("Games are managed by the server.");
  }

  @override
  Stream<Map<String, dynamic>> streamGame(String gameId) {
    final controller = StreamController<Map<String, dynamic>>.broadcast();

    // Fetch current state immediately so the UI isn't blank on first load
    _client
        .from('games')
        .select('*')
        .eq('id', 'live')
        .maybeSingle()
        .then((row) {
      if (row != null && !controller.isClosed) {
        controller.add(_mapGameToCamelCase(row));
      }
    }).catchError((_) {});

    // True Postgres change subscription — fires instantly on every UPDATE
    final channel = _client
        .channel('db:games:live')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'games',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: 'live',
          ),
          callback: (payload) {
            if (controller.isClosed) return;
            controller.add(_mapGameToCamelCase(
                Map<String, dynamic>.from(payload.newRecord)));
          },
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  @override
  Stream<List<Map<String, dynamic>>> streamGameWinners() {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();

    // Helper to map a raw row
    Map<String, dynamic> mapRow(Map<String, dynamic> row) => {
      'cardNo': row['card_no']?.toString() ?? '',
      'sessionId': row['session_id']?.toString() ?? '',
      'userId': row['user_id']?.toString() ?? '',
      'phone': row['phone'] ?? '',
      'createdAt': row['created_at'] != null
          ? DateTime.parse(row['created_at'])
          : null,
    };

    // Fetch current winners immediately
    _client
        .from('game_winners')
        .select('*')
        .then((rows) {
      if (!controller.isClosed) {
        controller.add((rows as List).map((r) => mapRow(Map<String, dynamic>.from(r as Map))).toList());
      }
    }).catchError((_) {});

    // Track all winners in memory so INSERT events can be accumulated
    final List<Map<String, dynamic>> _current = [];

    final channel = _client
        .channel('db:game_winners')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'game_winners',
          callback: (payload) {
            if (controller.isClosed) return;
            _current.add(mapRow(Map<String, dynamic>.from(payload.newRecord)));
            controller.add(List.from(_current));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'game_winners',
          callback: (payload) {
            if (controller.isClosed) return;
            _current.clear(); // delete means session reset
            controller.add([]);
          },
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  @override
  Future<void> drawNumber(String gameId, int number) async {
    throw UnimplementedError(
      "Server-authoritative architecture prevents clients from drawing numbers.",
    );
  }

  @override
  Future<void> buyCartelas(String userId, {int count = 1}) async {
    try {
      final response = await _client.functions.invoke('buy-card', body: {
        'count': count,
      });
      if (response.status != 200) {
        throw Exception(response.data['error'] ?? 'Function buy-card failed');
      }
    } catch (e) {
      Log.e("Repository buyCartelas failed", e);
      throw Exception('Failed to buy card: $e');
    }
  }

  @override
  Future<void> registerCard(String cardId, List<int> numbers) async {
    try {
      final response = await _client.functions.invoke('register-card', body: {
        'cardId': cardId,
        'numbers': numbers,
      });
      if (response.status != 200) {
        throw Exception(response.data['error'] ?? 'Function register-card failed');
      }
    } catch (e) {
      Log.e("Repository registerCard failed", e);
      throw Exception('Failed to register card: $e');
    }
  }

  @override
  Future<void> removeCard(String cardId) async {
    try {
      await _client.from('cards').delete().eq('id', cardId);
    } catch (e) {
      Log.e("Repository removeCard failed", e);
      throw Exception('Failed to remove card: $e');
    }
  }

  @override
  Future<bool> claimBingo(
    String gameId,
    String cardId, {
    List<String> markedCells = const [],
  }) async {
    try {
      final response = await _client.functions.invoke('claim-bingo', body: {
        'cardIds': [cardId],
        'markedCellsMap': {cardId: markedCells},
      });
      if (response.status != 200) {
        throw Exception(response.data['error'] ?? 'Function claim-bingo failed');
      }
      return response.data['success'] == true;
    } catch (e) {
      Log.e("Repository claimBingo failed", e);
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
      final response = await _client.functions.invoke('claim-bingo', body: {
        'cardIds': cardIds,
        'markedCellsMap': markedCellsMap,
      });
      if (response.status != 200) {
        throw Exception(response.data['error'] ?? 'Function claim-bingo failed');
      }
      return response.data['success'] == true;
    } catch (e) {
      Log.e("Repository claimMultipleBingo failed", e);
      rethrow;
    }
  }

  @override
  Future<List<BingoCard>> getUserCartelas(String userId, String gameId) async {
    try {
      final response = await _client
          .from('cards')
          .select('*')
          .eq('user_id', userId)
          .eq('game_id', 'live');

      final List<dynamic> rows = response as List<dynamic>;

      final cards = rows.map((row) {
        final flatNumbers = List<int>.from(row['numbers'] ?? []);
        final status = row['status'] as String? ?? 'pending';
        final cardNo = row['card_no'] as int? ?? 0;
        final cardSessionId = (row['session_id'] ?? '').toString();
        final createdAtStr = row['created_at'] as String?;
        final createdAt = createdAtStr != null ? DateTime.parse(createdAtStr) : null;

        final List<List<int>> grid = [];
        if (flatNumbers.length == 25) {
          for (var i = 0; i < 5; i++) {
            grid.add(flatNumbers.sublist(i * 5, (i + 1) * 5));
          }
        } else if (flatNumbers.length == 24) {
          final fullList = List<int>.from(flatNumbers);
          fullList.insert(12, 0); // Insert middle free space cell 0
          for (var i = 0; i < 5; i++) {
            grid.add(fullList.sublist(i * 5, (i + 1) * 5));
          }
        } else {
          for (var i = 0; i < 5; i++) {
            grid.add(List.filled(5, 0));
          }
        }

        return BingoCard(
          id: row['id'].toString(),
          numbers: grid,
          price: 10.0, // Standard card price
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
    } catch (e) {
      Log.e("Repository getUserCartelas failed", e);
      throw Exception('Failed to get user cards: $e');
    }
  }

  @override
  Stream<List<int>> streamDrawnNumbers(String gameId) {
    // All clients share ONE broadcast channel 'game:draws'.
    // The draw loop publishes each number there; we just subscribe.
    // Late-join: fetch current drawn_numbers from DB on first subscribe.
    final controller = StreamController<List<int>>();

    // ── 1. Late-join: fetch what's already drawn ──────────────────────────────
    _client
        .from('games')
        .select('drawn_numbers')
        .eq('id', 'live')
        .maybeSingle()
        .then((row) {
      if (row != null && !controller.isClosed) {
        controller.add(List<int>.from(row['drawn_numbers'] ?? []));
      }
    }).catchError((_) {});

    // ── 2. Live updates via shared broadcast channel ──────────────────────────
    final channel = _client
        .channel('game:draws')
        .onBroadcast(
          event: 'number_drawn',
          callback: (payload) {
            if (controller.isClosed) return;
            final drawn = payload['drawn'];
            if (drawn != null) {
              controller.add(List<int>.from(drawn as List));
            }
          },
        )
        .subscribe();

    // ── 3. Clean up on stream cancel ─────────────────────────────────────────
    controller.onCancel = () {
      _client.removeChannel(channel);
      if (!controller.isClosed) controller.close();
    };

    return controller.stream;
  }

  @override
  Future<double> getBalance(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select('balance')
          .eq('id', userId)
          .maybeSingle();
      return (response?['balance'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      Log.e("Repository getBalance failed", e);
      return 0.0;
    }
  }

  @override
  Stream<double> streamBalance(String userId) {
    final controller = StreamController<double>.broadcast();

    // Fetch current balance immediately
    _client
        .from('profiles')
        .select('balance')
        .eq('id', userId)
        .maybeSingle()
        .then((row) {
      if (row != null && !controller.isClosed) {
        controller.add((row['balance'] as num?)?.toDouble() ?? 0.0);
      }
    }).catchError((_) {});

    final channel = _client
        .channel('db:profiles:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            if (controller.isClosed) return;
            final balance =
                (payload.newRecord['balance'] as num?)?.toDouble() ?? 0.0;
            controller.add(balance);
          },
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  @override
  Future<List<Map<String, dynamic>>> getDeposits(String userId) async {
    try {
      final response = await _client
          .from('deposits')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (response as List<dynamic>).map<Map<String, dynamic>>((row) => <String, dynamic>{
        ...row as Map<String, dynamic>,
        'id': row['id'].toString(),
        'userId': row['user_id'].toString(),
        'amount': (row['amount'] as num?)?.toDouble() ?? 0.0,
        'reference': row['reference'] ?? '',
        'status': row['status'] ?? 'pending',
        'createdAt': row['created_at'] != null ? DateTime.parse(row['created_at']) : null,
        'verifiedAt': row['verified_at'] != null ? DateTime.parse(row['verified_at']) : null,
        'matchedVia': row['matched_via'],
        'rejectionReason': row['rejection_reason'],
      }).toList();
    } catch (e) {
      Log.e("Failed to get deposits", e);
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getWithdrawals(String userId) async {
    try {
      final response = await _client
          .from('withdrawals')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (response as List<dynamic>).map<Map<String, dynamic>>((row) => <String, dynamic>{
        ...row as Map<String, dynamic>,
        'id': row['id'].toString(),
        'userId': row['user_id'].toString(),
        'amount': (row['amount'] as num?)?.toDouble() ?? 0.0,
        'status': row['status'] ?? 'pending',
        'isReserved': row['is_reserved'] ?? false,
        'createdAt': row['created_at'] != null ? DateTime.parse(row['created_at']) : null,
        'reservedAt': row['reserved_at'] != null ? DateTime.parse(row['reserved_at']) : null,
        'refundedAt': row['refunded_at'] != null ? DateTime.parse(row['refunded_at']) : null,
        'rejectionReason': row['rejection_reason'],
      }).toList();
    } catch (e) {
      Log.e("Failed to get withdrawals", e);
      return [];
    }
  }

  @override
  Future<void> createDeposit(String userId, Map<String, dynamic> data) async {
    try {
      await _client.from('deposits').insert({
        'user_id': userId,
        'amount': data['amount'],
        'reference': data['reference'],
        'status': 'pending',
      });
    } catch (e) {
      Log.e("Failed to create deposit", e);
      rethrow;
    }
  }

  @override
  Future<void> createWithdrawal(String userId, Map<String, dynamic> data) async {
    try {
      await _client.from('withdrawals').insert({
        'user_id': userId,
        'amount': data['amount'],
        'status': 'pending',
      });
    } catch (e) {
      Log.e("Failed to create withdrawal", e);
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getGameHistory() async {
    try {
      final response = await _client
          .from('game_history')
          .select('*')
          .order('created_at', ascending: false)
          .limit(50);
      return (response as List<dynamic>).map<Map<String, dynamic>>((row) => <String, dynamic>{
        'id': row['id'].toString(),
        'sessionId': row['session_id'] ?? '',
        'status': row['status'] ?? '',
        'prize': (row['prize'] as num?)?.toDouble() ?? 0.0,
        'drawnNumbers': List<int>.from(row['drawn_numbers'] ?? []),
        'cardsSold': row['cards_sold'] ?? 0,
        'winnerId': row['winner_id'],
        'winnerName': row['winner_name'],
        'winningCardNo': row['winning_card_no'],
        'createdAt': row['created_at'] != null ? DateTime.parse(row['created_at']) : null,
      }).toList();
    } catch (e) {
      Log.e("Failed to get game history", e);
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
            'totalPrize': 0,
            'displayName': game['winnerName'] ?? 'Player',
          };
        }

        players[winnerId]!['wins'] = (players[winnerId]!['wins'] as int) + 1;
        players[winnerId]!['totalPrize'] =
            (players[winnerId]!['totalPrize'] as double) +
                ((game['prize'] as num?)?.toDouble() ?? 0.0);
      }

      final sorted = players.values.toList()
        ..sort((a, b) => (b['wins'] as int).compareTo(a['wins'] as int));
      return sorted;
    } catch (e) {
      Log.e("Failed to aggregate top players", e);
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPaymentAccounts() async {
    // Return standard CBE / Telebirr configurations for player deposit instructions
    return [
      {
        'bank': 'Commercial Bank of Ethiopia (CBE)',
        'accountName': 'Bingo MK Games',
        'accountNumber': '1000123456789',
        'instructions': 'Send the amount to this CBE account and submit the transaction reference below.',
      },
      {
        'bank': 'Telebirr',
        'accountName': 'Bingo MK Games Mobile',
        'accountNumber': '0912345678',
        'instructions': 'Send the amount via Telebirr to this phone number and submit the transaction reference below.',
      }
    ];
  }

  @override
  Future<void> initializeGame() async {
    throw UnimplementedError("Initialization is handled automatically by Deno draw-loop.");
  }

  Map<String, dynamic> _mapGameToCamelCase(Map<String, dynamic> row) {
    final pendingClaims = (row['pending_claims'] as List?)
        ?.map((c) => Map<String, dynamic>.from(c as Map))
        .toList() ?? [];

    final claims = pendingClaims
        .map((c) => (c['cardId'] ?? '').toString())
        .toList();

    return {
      'status': row['status'] ?? 'waiting',
      'sessionId': row['session_id']?.toString() ?? '',
      'drawnNumbers': List<int>.from(row['drawn_numbers'] ?? []),
      'drawSequence': List<int>.from(row['draw_sequence'] ?? []),
      'isPaused': row['is_paused'] ?? false,
      'prizePool': (row['prize_pool'] ?? 0.0).toDouble(),
      'cardPrice': (row['card_price'] ?? 10.0).toDouble(),
      'gamePattern': row['game_pattern'] ?? 'full_house',
      'currentNumber': row['current_number'],
      'lastDrawTime': row['last_draw_time'],
      'heartbeat': row['heartbeat'],
      'loopId': row['loop_id'],
      'winners': List<String>.from(row['winners'] ?? []),
      'winnerId': row['winner_id'],
      'winningCardNo': row['winning_card_no'],
      'winningCardNumbers': row['winning_card_numbers'] != null
          ? List<int>.from(row['winning_card_numbers'])
          : null,
      'statusMessage': row['status_message'] ?? '',
      'cardsSold': row['cards_sold'] ?? 0,
      'playersCount': row['players_count'] ?? 0,
      'createdAt': row['start_time'] ?? row['last_draw_time'], // map start_time/last_draw_time to createdAt
      'claimDeadline': row['claim_deadline'],
      'pendingClaims': pendingClaims,
      'claims': claims, // Synthesized claims list of UUIDs for claimedCardIds in GameCubit
      'confirmedWinners': (row['confirmed_winners'] as List?)
          ?.map((c) => Map<String, dynamic>.from(c as Map))
          .toList() ?? [],
    };
  }
}