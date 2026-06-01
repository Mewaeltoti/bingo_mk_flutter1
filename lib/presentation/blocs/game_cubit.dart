import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/bingo_card.dart';
import '../../domain/repositories/bingo_repository.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/service_locator.dart';
import '../../core/services/card_generator_service.dart';
import '../../core/services/connectivity_service.dart';

const Object _sentinel = Object();

const String kLiveGameId = 'live';
const int kDefaultBuyingCountdown = 120;

enum GameStatus { buying, active, won, waiting, paused }

abstract class GameState extends Equatable {
  @override
  List<Object?> get props => [];
}

class GameInitial extends GameState {}

class GameLoading extends GameState {}

class GameLoaded extends GameState {
  final List<int> drawnNumbers;
  final Map<String, Set<String>> markedCells;
  final List<BingoCard> userCards;
  final Set<String> blockedCardIds;
  final List<String> winners;
  final List<String> claimedCardIds;
  final List<Map<String, dynamic>> rawClaimsData;
  final List<Map<String, dynamic>> rawWinnersData;
  final int? winningCardNo;
  final List<int>? winningCardNumbers;
  final String sessionId;
  final bool isPaused;
  final String gamePattern;
  final double gamePrice;
  final double prizePool;
  final bool hasWon;
  final String? winnerId;
  final GameStatus status;
  final int buyingCountdown;
  final int playerCount;
  final int cardsSoldCount;
  final DateTime? startTime;
  final String statusStr;
  final String? broadcastMessage;
  final String? statusMessage;
  final List<String> pendingClaims;
  final bool isActionLoading;
  final DateTime? claimDeadline;
  final bool isAutoDaubEnabled;

  GameLoaded({
    required this.drawnNumbers,
    required this.markedCells,
    required this.userCards,
    this.blockedCardIds = const {},
    this.winners = const [],
    this.claimedCardIds = const [],
    this.rawClaimsData = const [],
    this.rawWinnersData = const [],
    this.winningCardNo,
    this.winningCardNumbers,
    this.sessionId = '',
    this.isPaused = false,
    this.gamePattern = 'Full House',
    this.gamePrice = 10.0,
    this.prizePool = 0,
    this.hasWon = false,
    this.winnerId,
    this.status = GameStatus.active,
    this.buyingCountdown = 0,
    this.playerCount = 0,
    this.cardsSoldCount = 0,
    this.startTime,
    this.statusStr = 'Playing',
    this.broadcastMessage,
    this.statusMessage,
    this.pendingClaims = const [],
    this.isActionLoading = false,
    this.claimDeadline,
    this.isAutoDaubEnabled = true,
  });

  List<int> get lastDrawnNumbers {
    if (drawnNumbers.isEmpty) return [];
    return drawnNumbers.reversed.take(10).toList();
  }

  @override
  List<Object?> get props => [
    drawnNumbers, markedCells, userCards, blockedCardIds, winners,
    claimedCardIds, rawClaimsData, rawWinnersData, winningCardNo,
    winningCardNumbers, sessionId, isPaused, gamePattern, gamePrice,
    prizePool, hasWon, winnerId, status, buyingCountdown, playerCount,
    cardsSoldCount, startTime, statusStr, broadcastMessage, statusMessage,
    pendingClaims, isActionLoading, claimDeadline, isAutoDaubEnabled,
  ];

  GameLoaded copyWith({
    List<int>? drawnNumbers,
    Map<String, Set<String>>? markedCells,
    List<BingoCard>? userCards,
    Set<String>? blockedCardIds,
    List<String>? winners,
    List<String>? claimedCardIds,
    List<Map<String, dynamic>>? rawClaimsData,
    List<Map<String, dynamic>>? rawWinnersData,
    int? winningCardNo,
    List<int>? winningCardNumbers,
    String? sessionId,
    bool? isPaused,
    String? gamePattern,
    double? gamePrice,
    double? prizePool,
    bool? hasWon,
    String? winnerId,
    GameStatus? status,
    int? buyingCountdown,
    int? playerCount,
    int? cardsSoldCount,
    DateTime? startTime,
    String? statusStr,
    Object? broadcastMessage = _sentinel,
    Object? statusMessage = _sentinel,
    List<String>? pendingClaims,
    bool? isActionLoading,
    Object? claimDeadline = _sentinel,
    bool? isAutoDaubEnabled,
  }) {
    return GameLoaded(
      drawnNumbers: drawnNumbers ?? this.drawnNumbers,
      markedCells: markedCells ?? this.markedCells,
      userCards: userCards ?? this.userCards,
      blockedCardIds: blockedCardIds ?? this.blockedCardIds,
      winners: winners ?? this.winners,
      claimedCardIds: claimedCardIds ?? this.claimedCardIds,
      rawClaimsData: rawClaimsData ?? this.rawClaimsData,
      rawWinnersData: rawWinnersData ?? this.rawWinnersData,
      winningCardNo: winningCardNo ?? this.winningCardNo,
      winningCardNumbers: winningCardNumbers ?? this.winningCardNumbers,
      sessionId: sessionId ?? this.sessionId,
      isPaused: isPaused ?? this.isPaused,
      gamePattern: gamePattern ?? this.gamePattern,
      gamePrice: gamePrice ?? this.gamePrice,
      prizePool: prizePool ?? this.prizePool,
      hasWon: hasWon ?? this.hasWon,
      winnerId: winnerId ?? this.winnerId,
      status: status ?? this.status,
      buyingCountdown: buyingCountdown ?? this.buyingCountdown,
      playerCount: playerCount ?? this.playerCount,
      cardsSoldCount: cardsSoldCount ?? this.cardsSoldCount,
      startTime: startTime ?? this.startTime,
      statusStr: statusStr ?? this.statusStr,
      broadcastMessage: broadcastMessage == _sentinel ? this.broadcastMessage : broadcastMessage as String?,
      statusMessage: statusMessage == _sentinel ? this.statusMessage : statusMessage as String?,
      pendingClaims: pendingClaims ?? this.pendingClaims,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      claimDeadline: claimDeadline == _sentinel ? this.claimDeadline : claimDeadline as DateTime?,
      isAutoDaubEnabled: isAutoDaubEnabled ?? this.isAutoDaubEnabled,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GAME CUBIT
// ─────────────────────────────────────────────────────────────────────────────

class GameCubit extends Cubit<GameState> {
  final BingoRepository _bingoRepository;
  final String userId;

  StreamSubscription? _gameSub;
  StreamSubscription? _winnersSub;
  String _winnersSessionId = '';
  StreamSubscription? _drawsSub;
  StreamSubscription? _connectivitySub;

  GameCubit({required BingoRepository bingoRepository, required this.userId})
      : _bingoRepository = bingoRepository,
        super(GameInitial()) {
    sl<AudioService>().init();
    _init();
    _subscribeConnectivity();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _init() async {
    try {
      final cards = await _bingoRepository.getUserCartelas(userId, kLiveGameId);
      if (isClosed) return;

      final initialSessionId = await _bingoRepository.getLiveSessionId();

      emit(GameLoaded(
        drawnNumbers: [],
        markedCells: {},
        userCards: cards,
        blockedCardIds: cards.where((c) => c.isBlocked).map((c) => c.id).toSet(),
        sessionId: initialSessionId,
        status: GameStatus.buying,
        buyingCountdown: kDefaultBuyingCountdown,
        playerCount: 0,
        cardsSoldCount: cards.length,
      ));

      if (initialSessionId.isNotEmpty) {
        _resubscribeDraws(initialSessionId);
        _resubscribeWinners(initialSessionId);
      }

      _gameSub = _bingoRepository.streamGame(kLiveGameId).listen((gameData) {
        if (state is! GameLoaded) return;
        final current = state as GameLoaded;

        final statusStr = gameData['status'] ?? 'active';
        GameStatus newStatus = GameStatus.active;
        switch (statusStr) {
          case 'buying':  newStatus = GameStatus.buying;  break;
          case 'won':     newStatus = GameStatus.won;     break;
          case 'paused':  newStatus = GameStatus.paused;  break;
          case 'waiting': newStatus = GameStatus.waiting; break;
          default:        newStatus = GameStatus.active;
        }

        final newSessionId = (gameData['sessionId'] ?? '').toString();
        final bool sessionChanged =
            newSessionId != current.sessionId && current.sessionId.isNotEmpty;

        if (newStatus == GameStatus.won && !current.hasWon && gameData['winnerId'] == userId) {
          AudioService().playWin();
        }

        if (sessionChanged && newSessionId.isNotEmpty) {
          _drawsSub?.cancel();
          _resubscribeDraws(newSessionId);
          _resubscribeWinners(newSessionId);
        }

        if (isClosed) return;

        final gameDocNumbers = sessionChanged
            ? <int>[]
            : List<int>.from(gameData['drawnNumbers'] ?? []);
        final mergedDrawnNumbers = gameDocNumbers.length > current.drawnNumbers.length
            ? gameDocNumbers
            : (sessionChanged ? <int>[] : null);

        Map<String, Set<String>>? fallbackAutoMarked;
        if (mergedDrawnNumbers != null &&
            mergedDrawnNumbers.length > current.drawnNumbers.length &&
            current.isAutoDaubEnabled) {
          final newNums = mergedDrawnNumbers.sublist(current.drawnNumbers.length).toSet();
          fallbackAutoMarked = _applyAutoDaub(current, newNums);
        }

        emit(current.copyWith(
          status: newStatus,
          isPaused: gameData['isPaused'] ?? false,
          sessionId: newSessionId,
          gamePattern: gameData['gamePattern'] ?? 'full_house',
          prizePool: (gameData['prizePool'] ?? 0).toDouble(),
          gamePrice: (gameData['cardPrice'] ?? 10).toDouble(),
          claimedCardIds: sessionChanged ? [] : List<String>.from(gameData['claims'] ?? []),
          cardsSoldCount: gameData['cardsSold'] ?? current.cardsSoldCount,
          playerCount: gameData['playersCount'] ?? current.playerCount,
          winnerId: sessionChanged ? null : gameData['winnerId'],
          winningCardNo: sessionChanged ? null : gameData['winningCardNo'],
          winningCardNumbers: sessionChanged
              ? null
              : (gameData['winningCardNumbers'] != null
                  ? List<int>.from(gameData['winningCardNumbers'])
                  : null),
          hasWon: sessionChanged
              ? false
              : (newStatus == GameStatus.won && gameData['winnerId'] == userId),
          winners: sessionChanged ? [] : null,
          rawWinnersData: sessionChanged ? [] : null,
          rawClaimsData: sessionChanged
              ? const []
              : ((gameData['pendingClaims'] as List?)
                      ?.map((c) => Map<String, dynamic>.from(c as Map))
                      .toList() ??
                  const []),
          startTime: gameData['createdAt'] != null
              ? (gameData['createdAt'] is DateTime
                  ? gameData['createdAt'] as DateTime
                  : DateTime.tryParse(gameData['createdAt'].toString()))
              : null,
          statusStr: statusStr.toUpperCase(),
          broadcastMessage: sessionChanged ? null : gameData['broadcastMessage'],
          statusMessage: sessionChanged ? "New game session started!" : gameData['statusMessage'],
          pendingClaims: sessionChanged
              ? []
              : ((gameData['pendingClaims'] as List?)
                      ?.map((c) => (c['cardNo'] ?? '').toString())
                      .toList() ??
                  []),
          claimDeadline: sessionChanged
              ? null
              : (gameData['claimDeadline'] == null
                  ? null
                  : (gameData['claimDeadline'] is DateTime
                      ? gameData['claimDeadline'] as DateTime
                      : (gameData['claimDeadline'] is int
                          ? DateTime.fromMillisecondsSinceEpoch(gameData['claimDeadline'] as int)
                          : DateTime.tryParse(gameData['claimDeadline'].toString())))),
          markedCells: sessionChanged ? {} : fallbackAutoMarked,
          blockedCardIds: sessionChanged ? {} : null,
          drawnNumbers: mergedDrawnNumbers,
          userCards: current.userCards.where((c) => c.sessionId == newSessionId).toList(),
        ));

        final bool gameEnded = newStatus == GameStatus.won || newStatus == GameStatus.waiting;
        final bool transitionedToBuying =
            newStatus == GameStatus.buying && current.status != GameStatus.buying;

        if (sessionChanged || gameEnded || transitionedToBuying) {
          if (!isClosed) refreshCards();
        }
      });
    } catch (e, stack) {                          // ← catch that matches the try in _init
      Log.e("GameCubit initialization failed", e, stack);
    }
  }                                               // ← _init closing brace (was missing!)

  // ─────────────────────────────────────────────────────────────────────────
  // WINNERS SUBSCRIPTION
  // ─────────────────────────────────────────────────────────────────────────

  void _resubscribeWinners(String sessionId) {
    if (_winnersSessionId == sessionId) return;
    _winnersSub?.cancel();
    _winnersSessionId = sessionId;

    _winnersSub = _bingoRepository.streamGameWinners(sessionId).listen((winnersList) {
      if (state is! GameLoaded || isClosed) return;
      final current = state as GameLoaded;
      final cardNumbers = winnersList.map((w) => w['cardNo'].toString()).toList();
      emit(current.copyWith(winners: cardNumbers, rawWinnersData: winnersList));
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RE-FETCH CARDS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> refreshCards() async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;
    try {
      final dbCards = await _bingoRepository.getUserCartelas(
        userId, kLiveGameId,
        sessionId: current.sessionId.isNotEmpty ? current.sessionId : null,
      );

      final activeDbCards = dbCards.where((c) => c.sessionId == current.sessionId).toList();
      final localPendingCards = current.userCards
          .where((c) => c.status == 'pending' && c.sessionId == current.sessionId)
          .toList();
      final combinedCards = [...activeDbCards, ...localPendingCards];
      final mergedBlocked = combinedCards.where((c) => c.isBlocked).map((c) => c.id).toSet();

      emit(current.copyWith(userCards: combinedCards, blockedCardIds: mergedBlocked));
    } catch (e, stack) {
      Log.e("Failed to refresh cards", e, stack);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MARK CELL (Local Only)
  // ─────────────────────────────────────────────────────────────────────────

  void markCell(String cardId, int row, int col) {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;

    final tappedCardIndex = current.userCards.indexWhere((c) => c.id == cardId);
    if (tappedCardIndex == -1) return;

    final tappedCard = current.userCards[tappedCardIndex];
    if (row == 2 && col == 2) return;

    final tappedNumber = tappedCard.numbers[row][col];
    final map = Map<String, Set<String>>.from(current.markedCells);
    final isCurrentlyMarked = (map[cardId] ?? {}).contains('$row-$col');
    final isMarking = !isCurrentlyMarked;

    for (var card in current.userCards) {
      final cells = Set<String>.from(map[card.id] ?? {});
      for (var r = 0; r < 5; r++) {
        for (var c = 0; c < 5; c++) {
          if (r == 2 && c == 2) continue;
          if (card.numbers[r][c] == tappedNumber) {
            final key = '$r-$c';
            if (isMarking) {
              cells.add(key);
            } else {
              cells.remove(key);
            }
          }
        }
      }
      map[card.id] = cells;
    }

    AudioService().playMark();
    emit(current.copyWith(markedCells: map));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUY CARD (local generation)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> buyCard({int count = 1}) async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;
    emit(current.copyWith(isActionLoading: true));
    try {
      final existingCardNos = current.userCards.map((c) => c.cardNo).toSet();
      final newCards = await sl<CardGeneratorService>().generateCards(
        count: count,
        existingCardNos: existingCardNos,
        gamePrice: current.gamePrice,
        sessionId: current.sessionId,
      );
      emit(current.copyWith(
        userCards: [...current.userCards, ...newCards],
        isActionLoading: false,
        statusMessage: count == 1
            ? "Card selected! Click Activate to purchase."
            : "$count cards selected! Activate them to play.",
      ));
    } catch (e, stack) {
      Log.e("Failed to select local card", e, stack);
      if (state is GameLoaded) {
        emit((state as GameLoaded).copyWith(
            isActionLoading: false, statusMessage: _friendlyError(e)));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REGISTER CARD
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> registerCard(String cardId) async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;
    emit(current.copyWith(isActionLoading: true));
    try {
      final card = current.userCards.firstWhere((c) => c.id == cardId);
      final List<int> flatNumbers = [];
      for (var row in card.numbers) {
        flatNumbers.addAll(row);
      }
      if (flatNumbers.length == 25) flatNumbers.removeAt(12);

      await _bingoRepository.registerCard(card.cardNo.toString(), flatNumbers);

      final updatedCards = current.userCards.map((c) {
        if (c.id == cardId) return c.copyWith(status: 'registered', sessionId: current.sessionId);
        return c;
      }).toList();
      emit(current.copyWith(userCards: updatedCards));

      await refreshCards();
      emit((state as GameLoaded).copyWith(
          isActionLoading: false, statusMessage: "Card registered successfully!"));
    } catch (e, stack) {
      Log.e("Failed to register card", e, stack);
      if (state is GameLoaded) {
        final updatedCards = (state as GameLoaded).userCards.where((c) => c.id != cardId).toList();
        emit((state as GameLoaded).copyWith(
            userCards: updatedCards,
            isActionLoading: false,
            statusMessage: _friendlyError(e, prefix: "Registration failed")));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REMOVE CARD
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> removeCard(String cardId) async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;

    if (current.isActionLoading) return;
    if (current.status != GameStatus.buying) {
      emit(current.copyWith(statusMessage: "Cannot discard cards after the game starts!"));
      return;
    }

    final card = current.userCards.firstWhere((c) => c.id == cardId);
    if (card.status == 'registered') {
      emit(current.copyWith(statusMessage: "Cannot remove an already activated card!"));
      return;
    }
    if (card.status == 'pending') {
      final updatedCards = current.userCards.where((c) => c.id != cardId).toList();
      emit(current.copyWith(userCards: updatedCards, statusMessage: "Card discarded."));
      return;
    }

    emit(current.copyWith(isActionLoading: true));
    try {
      await _bingoRepository.removeCard(cardId);
      await refreshCards();
      emit((state as GameLoaded).copyWith(
          isActionLoading: false, statusMessage: "Card removed successfully!"));
    } catch (e, stack) {
      Log.e("Failed to remove card", e, stack);
      if (state is GameLoaded) {
        emit((state as GameLoaded).copyWith(
            isActionLoading: false,
            statusMessage: _friendlyError(e, prefix: "Could not remove card")));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REGISTER ALL PENDING
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> registerAllPending() async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;

    final pendingCards = current.userCards.where((c) => c.status == 'pending').toList();
    if (pendingCards.isEmpty) return;

    emit(current.copyWith(
      isActionLoading: true,
      statusMessage: "Activating ${pendingCards.length} cards...",
    ));

    List<int> flatNumbers(BingoCard card) {
      final flat = card.numbers.expand((row) => row).toList();
      if (flat.length == 25) flat.removeAt(12);
      return flat;
    }

    final results = await Future.wait(
      pendingCards.map((card) => _bingoRepository
          .registerCard(card.cardNo.toString(), flatNumbers(card))
          .then((_) => null)
          .catchError((e) => e)),
    );

    final failedIndices = [
      for (var i = 0; i < results.length; i++)
        if (results[i] != null) i,
    ];
    final successCount = pendingCards.length - failedIndices.length;

    final failedIds = {for (var i in failedIndices) pendingCards[i].id};
    final updatedCards = current.userCards.map((c) {
      if (c.status == 'pending' && !failedIds.contains(c.id)) {
        return c.copyWith(status: 'registered', sessionId: current.sessionId);
      }
      return c;
    }).toList();
    emit(current.copyWith(userCards: updatedCards));

    await refreshCards();
    if (isClosed) return;

    if (failedIndices.isEmpty) {
      emit((state as GameLoaded).copyWith(
        isActionLoading: false,
        statusMessage: "All $successCount cards activated successfully!",
      ));
    } else {
      Log.e("registerAllPending: ${failedIndices.length} card(s) failed",
          results[failedIndices.first]);
      emit((state as GameLoaded).copyWith(
        isActionLoading: false,
        statusMessage: successCount > 0
            ? "$successCount activated, ${failedIndices.length} failed. Try again."
            : "Activation failed: ${results[failedIndices.first]}",
      ));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REMOVE ALL PENDING
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> removeAllPending() async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;

    if (current.status != GameStatus.buying) {
      emit(current.copyWith(statusMessage: "Cannot discard cards after the game starts!"));
      return;
    }

    final pendingCards = current.userCards.where((c) => c.status == 'pending').toList();
    if (pendingCards.isEmpty) return;

    final pendingIds = pendingCards.map((c) => c.id).toSet();
    final updatedCards = current.userCards.where((c) => !pendingIds.contains(c.id)).toList();
    emit(current.copyWith(
      userCards: updatedCards,
      statusMessage: "Pending cards discarded successfully!",
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CLAIM BINGO
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> claimBingo(String cardId) async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;

    emit(current.copyWith(
      isActionLoading: true,
      statusMessage: "Verifying BINGO claim...",
    ));

    try {
      final cardMarked = current.markedCells[cardId]?.toList() ?? <String>[];
      final bool? success = await _bingoRepository.claimBingo(
          kLiveGameId, cardId, markedCells: cardMarked);

      if (success == false) {
        AudioService().playError();
        final blocked = Set<String>.from(current.blockedCardIds)..add(cardId);
        await _bingoRepository.blockCard(userId, cardId);
        await refreshCards();
        if (isClosed) return;
        emit((state as GameLoaded).copyWith(
            isActionLoading: false,
            blockedCardIds: blocked,
            statusMessage: "Invalid claim! Card blocked."));
      } else if (success == true) {
        // Immediately add this card to claimedCardIds so the BINGO button
        // becomes disabled before the next Firestore snapshot arrives.
        // Without this the button stays enabled and a second tap fires
        // a duplicate claim request to the Cloud Function.
        final alreadyClaimed = List<String>.from(
            (state as GameLoaded).claimedCardIds)
          ..add(cardId);
        emit((state as GameLoaded).copyWith(
            isActionLoading: false,
            claimedCardIds: alreadyClaimed,
            statusMessage: "Bingo claimed! Waiting for other players..."));
      }
    } catch (e, stack) {
      Log.e("Failed to claim bingo", e, stack);
      if (state is GameLoaded) {
        emit((state as GameLoaded).copyWith(
            isActionLoading: false,
            statusMessage: _friendlyError(e, prefix: "Claim failed")));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CLAIM MULTIPLE BINGOS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> claimMultipleBingo(List<String> cardIds) async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;
    if (cardIds.isEmpty) return;

    emit(current.copyWith(
      isActionLoading: true,
      statusMessage: "Verifying ${cardIds.length} BINGO claims...",
    ));

    try {
      final Map<String, List<String>> markedCellsMap = {
        for (var id in cardIds)
          id: current.markedCells[id]?.toList() ?? <String>[],
      };

      final bool? success = await _bingoRepository.claimMultipleBingo(
          kLiveGameId, cardIds, markedCellsMap: markedCellsMap);

      if (success == false) {
        AudioService().playError();
        final blocked = Set<String>.from(current.blockedCardIds)..addAll(cardIds);
        await Future.wait(cardIds.map((id) => _bingoRepository.blockCard(userId, id)));
        await refreshCards();
        if (isClosed) return;
        emit((state as GameLoaded).copyWith(
            isActionLoading: false,
            blockedCardIds: blocked,
            statusMessage: "Invalid claims! Cards blocked."));
      } else if (success == true) {
        // Same as single-claim fix: optimistically add all cardIds to
        // claimedCardIds so every BINGO button disables immediately.
        final alreadyClaimed = List<String>.from(
            (state as GameLoaded).claimedCardIds)
          ..addAll(cardIds);
        emit((state as GameLoaded).copyWith(
            isActionLoading: false,
            claimedCardIds: alreadyClaimed,
            statusMessage: "${cardIds.length} Bingos claimed! Waiting for other players..."));
      }
    } catch (e, stack) {
      Log.e("Failed to claim multiple bingos", e, stack);
      if (state is GameLoaded) {
        emit((state as GameLoaded).copyWith(
            isActionLoading: false,
            statusMessage: _friendlyError(e, prefix: "Claims failed")));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CLEAR STATUS MESSAGE
  // ─────────────────────────────────────────────────────────────────────────

  void clearStatusMessage() {
    if (state is GameLoaded) {
      emit((state as GameLoaded).copyWith(statusMessage: null));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TOGGLE AUTO-DAUB
  // ─────────────────────────────────────────────────────────────────────────

  void toggleAutoDaub(bool enabled) {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;

    Map<String, Set<String>>? newMarkedCells;
    if (enabled) {
      final drawnSet = Set<int>.from(current.drawnNumbers);
      final map = Map<String, Set<String>>.from(current.markedCells);
      for (var card in current.userCards) {
        if (card.status != 'registered') continue;
        final cells = Set<String>.from(map[card.id] ?? {});
        for (var r = 0; r < 5; r++) {
          for (var c = 0; c < 5; c++) {
            if (r == 2 && c == 2) continue;
            if (drawnSet.contains(card.numbers[r][c])) cells.add('$r-$c');
          }
        }
        map[card.id] = cells;
      }
      newMarkedCells = map;
    }

    emit(current.copyWith(
      isAutoDaubEnabled: enabled,
      markedCells: newMarkedCells,
      statusMessage:
          enabled ? "Auto-Daub Assistant enabled!" : "Auto-Daub Assistant disabled.",
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONNECTIVITY
  // ─────────────────────────────────────────────────────────────────────────

  void _subscribeConnectivity() {
    _connectivitySub = ConnectivityService.instance.onlineStream
        .where((isOnline) => isOnline)
        .listen((_) => onAppResumed());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DRAWS SUBSCRIPTION
  // ─────────────────────────────────────────────────────────────────────────

  void _resubscribeDraws(String sessionId) {
    _drawsSub?.cancel();
    _drawsSub = _bingoRepository.streamGameDraws(sessionId).listen((allNumbers) {
      if (state is! GameLoaded || isClosed) return;
      final current = state as GameLoaded;

      if (allNumbers.length == current.drawnNumbers.length) return;

      if (current.drawnNumbers.isNotEmpty && allNumbers.length > current.drawnNumbers.length) {
        final newNumbers = allNumbers.sublist(current.drawnNumbers.length);
        for (final n in newNumbers) {
          if (current.status != GameStatus.paused) AudioService().callNumber(n);
        }
      }

      Map<String, Set<String>>? autoMarked;
      if (current.isAutoDaubEnabled && allNumbers.length > current.drawnNumbers.length) {
        final newSet = allNumbers.sublist(current.drawnNumbers.length).toSet();
        autoMarked = _applyAutoDaub(current, newSet);
      }

      emit(current.copyWith(drawnNumbers: allNumbers, markedCells: autoMarked));
    }, onError: (e) => Log.e('streamGameDraws error', e));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Map<String, Set<String>> _applyAutoDaub(GameLoaded current, Set<int> numbersToMark) {
    final map = Map<String, Set<String>>.from(current.markedCells);
    for (var card in current.userCards) {
      if (card.status != 'registered') continue;
      final cells = Set<String>.from(map[card.id] ?? {});
      for (var r = 0; r < 5; r++) {
        for (var col = 0; col < 5; col++) {
          if (r == 2 && col == 2) continue;
          if (numbersToMark.contains(card.numbers[r][col])) cells.add('$r-$col');
        }
      }
      map[card.id] = cells;
    }
    return map;
  }

  void onAppResumed() {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;
    if (current.sessionId.isNotEmpty) _resubscribeDraws(current.sessionId);
    refreshCards();
  }

  String _friendlyError(Object e, {String? prefix}) {
    String message;
    final s = e.toString().toLowerCase();
    if (s.contains('permission') || s.contains('permission-denied')) {
      message = 'Permission denied. Please sign in again.';
    } else if (s.contains('network') || s.contains('unavailable') || s.contains('deadline')) {
      message = 'Network error. Please check your connection.';
    } else if (s.contains('not-found') || s.contains('not found')) {
      message = 'Item not found. Please refresh and try again.';
    } else if (s.contains('unauthenticated')) {
      message = 'Session expired. Please sign in again.';
    } else if (s.contains('insufficient balance') || s.contains('insufficient')) {
      message = e.toString().replaceAll('Exception: ', '');
    } else {
      message = 'Something went wrong. Please try again.';
    }
    if (prefix != null) return '$prefix: $message';
    return message;
  }

  @override
  Future<void> close() {
    _gameSub?.cancel();
    _winnersSub?.cancel();
    _drawsSub?.cancel();
    _connectivitySub?.cancel();
    return super.close();
  }
}