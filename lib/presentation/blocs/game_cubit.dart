import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/bingo_card.dart';
import '../../domain/repositories/bingo_repository.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/service_locator.dart';
import '../../core/services/card_generator_service.dart';

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
    this.isAutoDaubEnabled = false,
  });

  List<int> get lastDrawnNumbers {
    if (drawnNumbers.isEmpty) return [];
    return drawnNumbers.reversed.take(10).toList();
  }

  @override
  List<Object?> get props => [
    drawnNumbers,
    markedCells,
    userCards,
    blockedCardIds,
    winners,
    claimedCardIds,
    rawClaimsData,
    rawWinnersData,
    winningCardNo,
    winningCardNumbers,
    sessionId,
    isPaused,
    gamePattern,
    gamePrice,
    prizePool,
    hasWon,
    winnerId,
    status,
    buyingCountdown,
    playerCount,
    cardsSoldCount,
    startTime,
    statusStr,
    broadcastMessage,
    statusMessage,
    pendingClaims,
    isActionLoading,
    claimDeadline,
    isAutoDaubEnabled,
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

class GameCubit extends Cubit<GameState> {
  final BingoRepository _bingoRepository;
  final String userId;

  StreamSubscription? _drawnNumbersSub;
  StreamSubscription? _gameSub;
  StreamSubscription? _winnersSub;

  GameCubit({required BingoRepository bingoRepository, required this.userId})
    : _bingoRepository = bingoRepository,
      super(GameInitial()) {
    sl<AudioService>().init();
    _init();
  }


  Future<void> _init() async {
    try {
      final cards = await _bingoRepository.getUserCartelas(userId, kLiveGameId);

      if (isClosed) return;
      emit(
        GameLoaded(
          drawnNumbers: [],
          markedCells: {},
          userCards: cards,
          status: GameStatus.buying,
          buyingCountdown: kDefaultBuyingCountdown,
          playerCount: 0,
          cardsSoldCount: cards.length,
        ),
      );

      /// LIVE DRAWN NUMBERS (from games/live)
      _drawnNumbersSub = _bingoRepository.streamDrawnNumbers(kLiveGameId).listen((numbers) {
        if (state is! GameLoaded) return;
        final current = state as GameLoaded;
        
        final isTerminal =
            current.status == GameStatus.won ||
            current.status == GameStatus.waiting;
            
        if (numbers.length > current.drawnNumbers.length) {
          final newNumber = numbers.last;
          if (current.status != GameStatus.paused) {
            AudioService().callNumber(newNumber);
          }
        }

        // AUTO-DAUB MECHANIC
        Map<String, Set<String>>? autoMarked;
        if (current.isAutoDaubEnabled) {
          final drawnSet = Set<int>.from(numbers);
          final map = Map<String, Set<String>>.from(current.markedCells);
          for (var card in current.userCards) {
            if (card.status != 'registered') continue;
            final cells = Set<String>.from(map[card.id] ?? {});
            for (var r = 0; r < 5; r++) {
              for (var c = 0; c < 5; c++) {
                if (r == 2 && c == 2) continue;
                if (drawnSet.contains(card.numbers[r][c])) {
                  cells.add('$r-$c');
                }
              }
            }
            map[card.id] = cells;
          }
          autoMarked = map;
        }

        if (isClosed) return;
        emit(
          current.copyWith(
            drawnNumbers: numbers,
            markedCells: autoMarked,
            status: isTerminal ? current.status : null,
          ),
        );
      });

      /// GAME SESSION DATA (from games/live)
      _gameSub = _bingoRepository.streamGame(kLiveGameId).listen((gameData) {
        if (state is! GameLoaded) return;
        final current = state as GameLoaded;

        final statusStr = gameData['status'] ?? 'active';
        GameStatus newStatus = GameStatus.active;

        switch (statusStr) {
          case 'buying':
            newStatus = GameStatus.buying;
            break;
          case 'won':
            newStatus = GameStatus.won;
            break;
          case 'paused':
            newStatus = GameStatus.paused;
            break;
          case 'waiting':
            newStatus = GameStatus.waiting;
            break;
          default:
            newStatus = GameStatus.active;
        }

        final newSessionId = (gameData['sessionId'] ?? '').toString();
        final bool sessionChanged =
            newSessionId != current.sessionId && current.sessionId.isNotEmpty;

        if (newStatus == GameStatus.won && !current.hasWon && gameData['winnerId'] == userId) {
          AudioService().playWin();
        }

        if (isClosed) return;
        emit(
          current.copyWith(
            status: newStatus,
            isPaused: gameData['isPaused'] ?? false,
            sessionId: newSessionId,
            gamePattern: gameData['gamePattern'] ?? 'full_house',
            prizePool: (gameData['prizePool'] ?? 0).toDouble(),
            gamePrice: (gameData['cardPrice'] ?? 10).toDouble(),
            claimedCardIds: List<String>.from(gameData['claims'] ?? []),
            cardsSoldCount: gameData['cardsSold'] ?? current.cardsSoldCount,
            playerCount: gameData['playersCount'] ?? current.playerCount,
            winnerId: gameData['winnerId'],
            winningCardNo: gameData['winningCardNo'],
            winningCardNumbers: gameData['winningCardNumbers'] != null
                ? List<int>.from(gameData['winningCardNumbers'])
                : null,
            hasWon: newStatus == GameStatus.won && gameData['winnerId'] == userId,
            startTime: gameData['createdAt'] != null
                ? (gameData['createdAt'] is DateTime
                    ? gameData['createdAt'] as DateTime
                    : DateTime.tryParse(gameData['createdAt'].toString()))
                : null,
            statusStr: statusStr.toUpperCase(),
            broadcastMessage: gameData['broadcastMessage'],
            statusMessage: sessionChanged ? "New game session started!" : gameData['statusMessage'],
            pendingClaims: (gameData['pendingClaims'] as List?)
                    ?.map((c) => (c['cardNo'] ?? '').toString())
                    .toList() ??
                [],
            rawClaimsData: (gameData['pendingClaims'] as List?)
                    ?.map((c) => Map<String, dynamic>.from(c as Map))
                    .toList() ??
                const [],
            claimDeadline: gameData['claimDeadline'] == null ? null : 
                (gameData['claimDeadline'] is DateTime
                    ? gameData['claimDeadline'] as DateTime
                    : (gameData['claimDeadline'] is int 
                        ? DateTime.fromMillisecondsSinceEpoch(gameData['claimDeadline'] as int)
                        : DateTime.tryParse(gameData['claimDeadline'].toString()))),
            markedCells: sessionChanged ? {} : null,
            blockedCardIds: sessionChanged ? {} : null,
            userCards: current.userCards
                .where((c) => c.sessionId == newSessionId)
                .toList(),
          ),
        );

        final bool gameEnded = newStatus == GameStatus.won || newStatus == GameStatus.waiting;
        final bool transitionedToBuying = newStatus == GameStatus.buying && current.status != GameStatus.buying;

        if (sessionChanged || gameEnded || transitionedToBuying) {
          if (!isClosed) refreshCards();
        }
      });

      /// REAL-TIME GAME WINNERS (from separate game_winners collection, isolated by sessionId!)
      _winnersSub = _bingoRepository.streamGameWinners().listen((winnersList) {
        if (state is! GameLoaded) return;
        final current = state as GameLoaded;

        // Strictly filter winners matching only the current session!
        final currentSessionWinners = winnersList
            .where((w) => w['sessionId'].toString() == current.sessionId)
            .toList();

        final cardNumbers = currentSessionWinners.map((w) => w['cardNo'].toString()).toList();

        if (isClosed) return;
        emit(current.copyWith(
          winners: cardNumbers,
          rawWinnersData: currentSessionWinners,
        ));
      });
    } catch (e, stack) {
      Log.e("GameCubit initialization failed", e, stack);
    }
  }

  /// RE-FETCH CARDS
  Future<void> refreshCards() async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;
    try {
      final dbCards = await _bingoRepository.getUserCartelas(userId, kLiveGameId);
      
      // Filter database cards to only keep cards that belong to the current active session
      final activeDbCards = dbCards.where((c) => c.sessionId == current.sessionId).toList();
      
      // Get all local-only pending cards from the current state that belong to the current active session
      final localPendingCards = current.userCards
          .where((c) => c.status == 'pending' && c.sessionId == current.sessionId)
          .toList();

      // Combine database cards with local pending cards
      final combinedCards = [...activeDbCards, ...localPendingCards];

      emit(current.copyWith(userCards: combinedCards));
    } catch (e, stack) {
      Log.e("Failed to refresh cards", e, stack);
    }
  }

  /// MARK CELL (Local Only)
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

  /// GET PENDING CARD (INSTANT local generation from data.json!)
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
        statusMessage: count == 1 ? "Card selected! Click Activate to purchase." : "$count cards selected! Activate them to play.",
      ));
    } catch (e, stack) {
      Log.e("Failed to select local card", e, stack);
      if (state is GameLoaded) {
        emit((state as GameLoaded).copyWith(
            isActionLoading: false, statusMessage: "Failed: ${e.toString()}"));
      }
    }
  }

  /// REGISTER PENDING CARD (Client sends local card numbers!)
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
      
      // Remove middle free space index 12 if sending original 24 numbers list
      if (flatNumbers.length == 25) {
        flatNumbers.removeAt(12);
      }

      await _bingoRepository.registerCard(cardId, flatNumbers);

      // Update local state first to prevent duplicate merging!
      final updatedCards = current.userCards.map((c) {
        if (c.id == cardId) {
          return c.copyWith(status: 'registered', sessionId: current.sessionId);
        }
        return c;
      }).toList();
      emit(current.copyWith(userCards: updatedCards));

      await refreshCards();
      emit((state as GameLoaded).copyWith(
          isActionLoading: false, statusMessage: "Card registered successfully!"));
    } catch (e, stack) {
      Log.e("Failed to register card", e, stack);
      if (state is GameLoaded) {
        // Remove this card locally since purchase/registration failed (e.g. duplicate or insufficient balance)
        final updatedCards = (state as GameLoaded).userCards.where((c) => c.id != cardId).toList();
        emit((state as GameLoaded).copyWith(
            userCards: updatedCards,
            isActionLoading: false,
            statusMessage: "Registration failed: ${e.toString()}"));
      }
    }
  }

  /// REMOVE PENDING CARD
  Future<void> removeCard(String cardId) async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;
    
    // Prevent race conditions: block remove actions while any network transaction is in progress!
    if (current.isActionLoading) return;

    // SECURE GUARD: Deletion/Discard is only allowed in the buying stage!
    if (current.status != GameStatus.buying) {
      emit(current.copyWith(statusMessage: "Cannot discard cards after the game starts!"));
      return;
    }

    final card = current.userCards.firstWhere((c) => c.id == cardId);
    
    // SECURE GUARD: Once a card is activated/registered, it can NEVER be removed!
    if (card.status == 'registered') {
      emit(current.copyWith(statusMessage: "Cannot remove an already activated card!"));
      return;
    }

    if (card.status == 'pending') {
      // Pending card is local only! Remove instantly with zero network cost!
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
            isActionLoading: false, statusMessage: "Failed to remove card: ${e.toString()}"));
      }
    }
  }

  /// ACTIVATE ALL PENDING CARDS (Bulk activation)
  Future<void> registerAllPending() async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;

    final pendingCards = current.userCards.where((c) => c.status == 'pending').toList();
    if (pendingCards.isEmpty) return;

    emit(current.copyWith(
      isActionLoading: true,
      statusMessage: "Activating ${pendingCards.length} cards...",
    ));

    try {
      for (var card in pendingCards) {
        final List<int> flatNumbers = [];
        for (var row in card.numbers) {
          flatNumbers.addAll(row);
        }
        if (flatNumbers.length == 25) {
          flatNumbers.removeAt(12);
        }
        await _bingoRepository.registerCard(card.id, flatNumbers);
      }

      // Clear the local pending status of these cards in-memory first to prevent duplicates!
      final updatedCards = current.userCards.map((c) {
        if (c.status == 'pending') {
          return c.copyWith(status: 'registered', sessionId: current.sessionId);
        }
        return c;
      }).toList();
      emit(current.copyWith(userCards: updatedCards));

      await refreshCards();
      emit((state as GameLoaded).copyWith(
        isActionLoading: false,
        statusMessage: "All pending cards activated successfully!",
      ));
    } catch (e, stack) {
      Log.e("Failed to register all cards", e, stack);
      await refreshCards();
      if (state is GameLoaded) {
        emit((state as GameLoaded).copyWith(
          isActionLoading: false,
          statusMessage: "Activation failed: ${e.toString()}",
        ));
      }
    }
  }

  /// DISCARD ALL PENDING CARDS (Bulk removal)
  Future<void> removeAllPending() async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;

    // SECURE GUARD: Discarding is only allowed in the buying stage!
    if (current.status != GameStatus.buying) {
      emit(current.copyWith(statusMessage: "Cannot discard cards after the game starts!"));
      return;
    }

    final pendingCards = current.userCards.where((c) => c.status == 'pending').toList();
    if (pendingCards.isEmpty) return;

    // All pending cards are local only! Discard them instantly in memory with zero network cost!
    final pendingIds = pendingCards.map((c) => c.id).toSet();
    final updatedCards = current.userCards.where((c) => !pendingIds.contains(c.id)).toList();
    
    emit(current.copyWith(
      userCards: updatedCards,
      statusMessage: "Pending cards discarded successfully!",
    ));
  }

  /// CLAIM BINGO VIA CLOUD FUNCTION
  Future<void> claimBingo(String cardId) async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;

    emit(current.copyWith(
      isActionLoading: true,
      statusMessage: "Verifying BINGO claim...",
    ));

    try {
      final cardMarked = current.markedCells[cardId]?.toList() ?? <String>[];
      final success = await _bingoRepository.claimBingo(kLiveGameId, cardId, markedCells: cardMarked);

      if (!success) {
        AudioService().playError();
        final blocked = Set<String>.from(current.blockedCardIds)..add(cardId);
        emit(current.copyWith(
            isActionLoading: false,
            blockedCardIds: blocked,
            statusMessage: "Invalid claim! Card blocked."));
      } else {
        emit(current.copyWith(
            isActionLoading: false,
            statusMessage: "Bingo claimed! Waiting for other players..."));
      }
    } catch (e, stack) {
      Log.e("Failed to claim bingo", e, stack);
      if (state is GameLoaded) {
        emit((state as GameLoaded).copyWith(
            isActionLoading: false,
            statusMessage: "Failed to claim bingo: ${e.toString()}"));
      }
    }
  }

  /// CLAIM MULTIPLE BINGOS VIA CLOUD FUNCTION
  Future<void> claimMultipleBingo(List<String> cardIds) async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;

    if (cardIds.isEmpty) return;

    emit(current.copyWith(
      isActionLoading: true,
      statusMessage: "Verifying ${cardIds.length} BINGO claims...",
    ));

    try {
      final Map<String, List<String>> markedCellsMap = {};
      for (var id in cardIds) {
        markedCellsMap[id] = current.markedCells[id]?.toList() ?? <String>[];
      }

      final success = await _bingoRepository.claimMultipleBingo(kLiveGameId, cardIds, markedCellsMap: markedCellsMap);

      if (!success) {
        AudioService().playError();
        final blocked = Set<String>.from(current.blockedCardIds)..addAll(cardIds);
        emit(current.copyWith(
            isActionLoading: false,
            blockedCardIds: blocked,
            statusMessage: "Invalid claims! Cards blocked."));
      } else {
        emit(current.copyWith(
            isActionLoading: false,
            statusMessage: "${cardIds.length} Bingos claimed! Waiting for other players..."));
      }
    } catch (e, stack) {
      Log.e("Failed to claim multiple bingos", e, stack);
      if (state is GameLoaded) {
        emit((state as GameLoaded).copyWith(
            isActionLoading: false,
            statusMessage: "Failed to claim bingos: ${e.toString()}"));
      }
    }
  }
  /// CLEAR STATUS MESSAGE
  void clearStatusMessage() {
    if (state is GameLoaded) {
      emit((state as GameLoaded).copyWith(statusMessage: null));
    }
  }

  /// TOGGLE AUTO-DAUB
  void toggleAutoDaub(bool enabled) {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;
    
    Map<String, Set<String>>? newMarkedCells;
    if (enabled) {
      // Auto-daub all numbers drawn so far!
      final drawnSet = Set<int>.from(current.drawnNumbers);
      final map = Map<String, Set<String>>.from(current.markedCells);
      for (var card in current.userCards) {
        if (card.status != 'registered') continue;
        final cells = Set<String>.from(map[card.id] ?? {});
        for (var r = 0; r < 5; r++) {
          for (var c = 0; c < 5; c++) {
            if (r == 2 && c == 2) continue;
            if (drawnSet.contains(card.numbers[r][c])) {
              cells.add('$r-$c');
            }
          }
        }
        map[card.id] = cells;
      }
      newMarkedCells = map;
    }
    
    emit(current.copyWith(
      isAutoDaubEnabled: enabled,
      markedCells: newMarkedCells,
      statusMessage: enabled ? "Auto-Daub Assistant enabled!" : "Auto-Daub Assistant disabled.",
    ));
  }

  @override
  Future<void> close() {
    _drawnNumbersSub?.cancel();
    _gameSub?.cancel();
    _winnersSub?.cancel();
    return super.close();
  }
}
