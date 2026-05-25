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

  // ─────────────────────────────────────────────────────────────────────────
  // STREAM GAME
  // Subscribes to the shared broadcast channel 'game:state'.
  // The Postgres trigger broadcast_game_state() fires on EVERY games UPDATE
  // and sends the full row — no postgres_changes, no RLS interference.
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Stream<Map<String, dynamic>> streamGame(String gameId) {
    late final RealtimeChannel channel;
    late final StreamController<Map<String, dynamic>> controller;

    controller = StreamController<Map<String, dynamic>>(
      onListen: () {
        // Fetch current state immediately so UI isn't blank before first event
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

        // Subscribe directly to Postgres Changes on the games table.
        // This fires on every UPDATE to the 'live' row — no broadcast trigger needed.
        channel = _client
            .channel('game-state-realtime')
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
      },
      onCancel: () {
        _client.removeChannel(channel);
      },
    );

    return controller.stream;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STREAM DRAWN NUMBERS
  // Derived from streamGame — no extra channel needed.
  // GameCubit already reads drawnNumbers from the game stream,
  // but this method is kept for interface compatibility.
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Stream<List<int>> streamDrawnNumbers(String gameId) {
    return streamGame(gameId).map((game) {
      return List<int>.from(game['drawnNumbers'] ?? []);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STREAM GAME WINNERS
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Stream<List<Map<String, dynamic>>> streamGameWinners() {
    late final RealtimeChannel channel;
    late final StreamController<List<Map<String, dynamic>>> controller;
    final List<Map<String, dynamic>> current = [];

    Map<String, dynamic> _mapRow(Map<String, dynamic> row) => {
          'cardNo': row['card_no']?.toString() ?? '',
          'sessionId': row['session_id']?.toString() ?? '',
          'userId': row['user_id']?.toString() ?? '',
          'phone': row['phone'] ?? '',
          'createdAt': row['created_at'] != null
              ? DateTime.parse(row['created_at'])
              : null,
        };

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        _client.from('game_winners').select('*').then((rows) {
          if (controller.isClosed) return;
          current.clear();
          current.addAll((rows as List)
              .map((r) => _mapRow(Map<String, dynamic>.from(r as Map)))
              .toList());
          controller.add(List.from(current));
        }).catchError((_) {});

        channel = _client
            .channel('db-game-winners')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'game_winners',
              callback: (payload) {
                if (controller.isClosed) return;
                current.add(_mapRow(
                    Map<String, dynamic>.from(payload.newRecord)));
                controller.add(List.from(current));
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.delete,
              schema: 'public',
              table: 'game_winners',
              callback: (payload) {
                if (controller.isClosed) return;
                current.clear();
                controller.add([]);
              },
            )
            .subscribe();
      },
      onCancel: () {
        _client.removeChannel(channel);
      },
    );

    return controller.stream;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STREAM BALANCE
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Stream<double> streamBalance(String userId) {
    late final RealtimeChannel channel;
    late final StreamController<double> controller;

    controller = StreamController<double>(
      onListen: () {
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

        channel = _client
            .channel('db-profiles-$userId')
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
                controller.add(
                  (payload.newRecord['balance'] as num?)?.toDouble() ?? 0.0,
                );
              },
            )
            .subscribe();
      },
      onCancel: () {
        _client.removeChannel(channel);
      },
    );

    return controller.stream;
  }

  @override
  Future<void> drawNumber(String gameId, int number) async {
    throw UnimplementedError(
      "Server-authoritative: pg_cron drives all draws.",
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
        throw Exception(
            response.data['error'] ?? 'Function register-card failed');
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
        throw Exception(
            response.data['error'] ?? 'Function claim-bingo failed');
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
        throw Exception(
            response.data['error'] ?? 'Function claim-bingo failed');
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

      final cards = (response as List).map((row) {
        final flatNumbers = List<int>.from(row['numbers'] ?? []);
        final status = row['status'] as String? ?? 'pending';
        final cardNo = row['card_no'] as int? ?? 0;
        final cardSessionId = (row['session_id'] ?? '').toString();
        final createdAt = row['created_at'] != null
            ? DateTime.parse(row['created_at'])
            : null;

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
          id: row['id'].toString(),
          numbers: grid,
          price: 10.0,
          status: status,
          cardNo: cardNo,
          sessionId: cardSessionId,
          createdAt: createdAt,
        );
      }).toList();

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
  Future<List<Map<String, dynamic>>> getDeposits(String userId) async {
    try {
      final response = await _client
          .from('deposits')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (response as List).map<Map<String, dynamic>>((row) => {
            'id': row['id'].toString(),
            'userId': row['user_id'].toString(),
            'amount': (row['amount'] as num?)?.toDouble() ?? 0.0,
            'reference': row['reference'] ?? '',
            'status': row['status'] ?? 'pending',
            'createdAt': row['created_at'] != null
                ? DateTime.parse(row['created_at'])
                : null,
            'verifiedAt': row['verified_at'] != null
                ? DateTime.parse(row['verified_at'])
                : null,
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
      return (response as List).map<Map<String, dynamic>>((row) => {
            'id': row['id'].toString(),
            'userId': row['user_id'].toString(),
            'amount': (row['amount'] as num?)?.toDouble() ?? 0.0,
            'status': row['status'] ?? 'pending',
            'isReserved': row['is_reserved'] ?? false,
            'createdAt': row['created_at'] != null
                ? DateTime.parse(row['created_at'])
                : null,
            'reservedAt': row['reserved_at'] != null
                ? DateTime.parse(row['reserved_at'])
                : null,
            'refundedAt': row['refunded_at'] != null
                ? DateTime.parse(row['refunded_at'])
                : null,
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
  Future<void> createWithdrawal(
      String userId, Map<String, dynamic> data) async {
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
      return (response as List).map<Map<String, dynamic>>((row) => {
            'id': row['id'].toString(),
            'sessionId': row['session_id'] ?? '',
            'status': row['status'] ?? '',
            'prize': (row['prize'] as num?)?.toDouble() ?? 0.0,
            'drawnNumbers': List<int>.from(row['drawn_numbers'] ?? []),
            'cardsSold': row['cards_sold'] ?? 0,
            'winnerId': row['winner_id'],
            'winnerName': row['winner_name'],
            'winningCardNo': row['winning_card_no'],
            'createdAt': row['created_at'] != null
                ? DateTime.parse(row['created_at'])
                : null,
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
      Log.e("Failed to aggregate top players", e);
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
  Future<void> initializeGame() async {
    throw UnimplementedError(
        "Initialization is handled automatically by the draw-loop.");
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Map raw Postgres snake_case row → camelCase for GameCubit
  // ─────────────────────────────────────────────────────────────────────────
  Map<String, dynamic> _mapGameToCamelCase(Map<String, dynamic> row) {
    final pendingClaims = (row['pending_claims'] as List?)
            ?.map((c) => Map<String, dynamic>.from(c as Map))
            .toList() ??
        [];
    final claims =
        pendingClaims.map((c) => (c['cardId'] ?? '').toString()).toList();

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
      'createdAt': row['start_time'] ?? row['last_draw_time'],
      'claimDeadline': row['claim_deadline'],
      'pendingClaims': pendingClaims,
      'claims': claims,
      'confirmedWinners': (row['confirmed_winners'] as List?)
              ?.map((c) => Map<String, dynamic>.from(c as Map))
              .toList() ??
          [],
      // broadcastMessage comes from a dedicated column if available,
      // otherwise null — never reuse status_message which is a draw-loop field.
      'broadcastMessage': row['broadcast_message'],
    };
  }
}