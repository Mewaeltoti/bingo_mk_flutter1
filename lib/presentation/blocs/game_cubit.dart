import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/bingo_card.dart';
import '../../domain/repositories/bingo_repository.dart';
import '../../core/services/audio_service.dart';

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

  GameLoaded({
    required this.drawnNumbers,
    required this.markedCells,
    required this.userCards,
    this.blockedCardIds = const {},
    this.winners = const [],
    this.claimedCardIds = const [],
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
  ];

  GameLoaded copyWith({
    List<int>? drawnNumbers,
    Map<String, Set<String>>? markedCells,
    List<BingoCard>? userCards,
    Set<String>? blockedCardIds,
    List<String>? winners,
    List<String>? claimedCardIds,
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
    String? broadcastMessage,
    String? statusMessage,
    List<String>? pendingClaims,
    bool? isActionLoading,
  }) {
    return GameLoaded(
      drawnNumbers: drawnNumbers ?? this.drawnNumbers,
      markedCells: markedCells ?? this.markedCells,
      userCards: userCards ?? this.userCards,
      blockedCardIds: blockedCardIds ?? this.blockedCardIds,
      winners: winners ?? this.winners,
      claimedCardIds: claimedCardIds ?? this.claimedCardIds,
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
      broadcastMessage: broadcastMessage ?? this.broadcastMessage,
      statusMessage: statusMessage ?? this.statusMessage,
      pendingClaims: pendingClaims ?? this.pendingClaims,
      isActionLoading: isActionLoading ?? this.isActionLoading,
    );
  }
}

class GameCubit extends Cubit<GameState> {
  final BingoRepository _bingoRepository;
  final String userId;

  GameCubit({required BingoRepository bingoRepository, required this.userId})
    : _bingoRepository = bingoRepository,
      super(GameInitial()) {
    AudioService().init();
    _init();
  }

  Future<void> _init() async {
    // gameId is inherently 'live' now
    final cards = await _bingoRepository.getUserCartelas(userId, 'live');

    emit(
      GameLoaded(
        drawnNumbers: [],
        markedCells: {},
        userCards: cards,
        status: GameStatus.buying,
        buyingCountdown: 120,
        playerCount: 0,
        cardsSoldCount: cards.length,
      ),
    );

    /// LIVE DRAWN NUMBERS (from games/live)
    _bingoRepository.streamDrawnNumbers('live').listen((numbers) {
      if (state is! GameLoaded) return;
      final current = state as GameLoaded;
      // Never let the draw-numbers stream overwrite a terminal status
      final isTerminal =
          current.status == GameStatus.won ||
          current.status == GameStatus.waiting;
      // Trigger sound if new number drawn
      if (numbers.length > current.drawnNumbers.length) {
        final newNumber = numbers.last;
        AudioService().callNumber(newNumber);
        AudioService().playDraw();
      }

      emit(
        current.copyWith(
          drawnNumbers: numbers,
          status: isTerminal ? current.status : null,
        ),
      );
    });

    /// GAME SESSION DATA (from games/live)
    _bingoRepository.streamGame('live').listen((gameData) {
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

      emit(
        current.copyWith(
          status: newStatus,
          isPaused: gameData['isPaused'] ?? false,
          sessionId: newSessionId,
          gamePattern: gameData['gamePattern'] ?? 'full_house',
          prizePool: (gameData['prizePool'] ?? 0).toDouble(),
          gamePrice: (gameData['cardPrice'] ?? 10).toDouble(),
          winners: List<String>.from(gameData['winners'] ?? []),
          claimedCardIds: List<String>.from(gameData['claims'] ?? []),
          cardsSoldCount: gameData['cardsSold'] ?? current.cardsSoldCount,
          playerCount: gameData['playersCount'] ?? current.playerCount,
          winnerId: gameData['winnerId'] ?? current.winnerId,
          winningCardNo: gameData['winningCardNo'] ?? current.winningCardNo,
          winningCardNumbers: gameData['winningCardNumbers'] != null
              ? List<int>.from(gameData['winningCardNumbers'])
              : current.winningCardNumbers,
          hasWon: newStatus == GameStatus.won && gameData['winnerId'] == userId,
          startTime: gameData['createdAt'] != null
              ? (gameData['createdAt'] as dynamic).toDate()
              : null,
          statusStr: statusStr.toUpperCase(),
          broadcastMessage: gameData['broadcastMessage'],
          pendingClaims: (gameData['pendingClaims'] as List?)
                  ?.map((c) => (c['cardNo'] ?? '').toString())
                  .toList() ??
              [],
          markedCells: sessionChanged ? {} : null,
          blockedCardIds: sessionChanged ? {} : null,
          userCards: current.userCards
              .where((c) =>
                  c.sessionId == newSessionId ||
                  c.sessionId.isEmpty ||
                  c.status == 'pending')
              .toList(),
        ),
      );

      final bool gameEnded = newStatus == GameStatus.won || newStatus == GameStatus.waiting;

      if (sessionChanged || gameEnded) {
        refreshCards();
      }
    });
  }

  /// RE-FETCH CARDS
  Future<void> refreshCards() async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;
    final cards = await _bingoRepository.getUserCartelas(userId, 'live');
    emit(current.copyWith(userCards: cards));
  }

  /// MARK CELL (Local Only)
  void markCell(String cardId, int row, int col) {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;

    // Find the tapped card to get the number
    final tappedCardIndex = current.userCards.indexWhere((c) => c.id == cardId);
    if (tappedCardIndex == -1) return;

    final tappedCard = current.userCards[tappedCardIndex];
    if (row == 2 && col == 2) return; // Free space, usually auto-marked

    final tappedNumber = tappedCard.numbers[row][col];
    final map = Map<String, Set<String>>.from(current.markedCells);

    // Determine if we are marking or unmarking based on the tapped cell
    final isCurrentlyMarked = (map[cardId] ?? {}).contains('$row-$col');
    final isMarking = !isCurrentlyMarked;

    // Iterate through all user cards to find this number
    for (var card in current.userCards) {
      // Sync across all cards (or just registered ones, but syncing all is fine)
      final cells = Set<String>.from(map[card.id] ?? {});

      for (var r = 0; r < 5; r++) {
        for (var c = 0; c < 5; c++) {
          if (r == 2 && c == 2) continue; // Skip free space
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

  /// GET PENDING CARD (Previously Buy)
  Future<void> buyCard({int count = 1}) async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;
    emit(current.copyWith(isActionLoading: true));
    try {
      await _bingoRepository.buyCartelas(userId, count: count);
      await refreshCards();
    } catch (e) {
      print("Failed to buy card: $e");
    } finally {
      if (state is GameLoaded) {
        emit((state as GameLoaded).copyWith(
            isActionLoading: false, statusMessage: "Cards purchased successfully!"));
      }
    }
  }

  /// REGISTER PENDING CARD
  Future<void> registerCard(String cardId) async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;
    emit(current.copyWith(isActionLoading: true));
    try {
      await _bingoRepository.registerCard(cardId);
      await refreshCards();
    } catch (e) {
      print("Failed to register card: $e");
    } finally {
      if (state is GameLoaded) {
        emit((state as GameLoaded).copyWith(
            isActionLoading: false, statusMessage: "Card registered successfully!"));
      }
    }
  }

  /// REMOVE PENDING CARD
  Future<void> removeCard(String cardId) async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;
    emit(current.copyWith(isActionLoading: true));
    try {
      await _bingoRepository.removeCard(cardId);
      await refreshCards();
    } catch (e) {
      print("Failed to remove card: $e");
    } finally {
      if (state is GameLoaded) {
        emit((state as GameLoaded).copyWith(
            isActionLoading: false, statusMessage: "Card removed successfully!"));
      }
    }
  }

  /// CLAIM BINGO VIA CLOUD FUNCTION
  Future<void> claimBingo(String cardId) async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;
    emit(current.copyWith(isActionLoading: true));

    try {
      final success = await _bingoRepository.claimBingo('live', cardId);

      if (!success) {
        AudioService().playError();
        final blocked = Set<String>.from(current.blockedCardIds)..add(cardId);
        emit(current.copyWith(
            blockedCardIds: blocked, statusMessage: "Invalid claim! Card blocked."));
      } else {
        emit(current.copyWith(
            statusMessage: "Bingo claimed! Waiting for admin verification..."));
      }
    } catch (e) {
      print("Failed to claim bingo: $e");
    } finally {
      if (state is GameLoaded) {
        emit((state as GameLoaded).copyWith(isActionLoading: false));
      }
    }
  }
}
