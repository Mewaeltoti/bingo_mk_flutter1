import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/bingo_card.dart';
import '../../domain/repositories/bingo_repository.dart';

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

  GameLoaded({
    required this.drawnNumbers,
    required this.markedCells,
    required this.userCards,
    this.blockedCardIds = const {},
    this.winners = const [],
    this.sessionId = '',
    this.isPaused = false,
    this.gamePattern = 'Full House',
    this.gamePrice = 10.0,
    this.prizePool = 250.0,
    this.hasWon = false,
    this.winnerId,
    this.status = GameStatus.active,
    this.buyingCountdown = 0,
    this.playerCount = 0,
    this.cardsSoldCount = 0,
    this.startTime,
    this.statusStr = 'Playing',
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
  ];

  GameLoaded copyWith({
    List<int>? drawnNumbers,
    Map<String, Set<String>>? markedCells,
    List<BingoCard>? userCards,
    Set<String>? blockedCardIds,
    List<String>? winners,
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
  }) {
    return GameLoaded(
      drawnNumbers: drawnNumbers ?? this.drawnNumbers,
      markedCells: markedCells ?? this.markedCells,
      userCards: userCards ?? this.userCards,
      blockedCardIds: blockedCardIds ?? this.blockedCardIds,
      winners: winners ?? this.winners,
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
    );
  }
}

class GameCubit extends Cubit<GameState> {
  final BingoRepository _bingoRepository;
  final String userId;

  GameCubit({required BingoRepository bingoRepository, required this.userId})
    : _bingoRepository = bingoRepository,
      super(GameInitial()) {
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
        playerCount: 12,
        cardsSoldCount: cards.length,
      ),
    );

    /// LIVE DRAWN NUMBERS (from games/live)
    _bingoRepository.streamDrawnNumbers('live').listen((numbers) {
      if (state is! GameLoaded) return;
      final current = state as GameLoaded;
      // Never let the draw-numbers stream overwrite a terminal status
      final isTerminal = current.status == GameStatus.won ||
          current.status == GameStatus.waiting;
      emit(current.copyWith(drawnNumbers: numbers, status: isTerminal ? current.status : null));
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
      final bool sessionChanged = newSessionId != current.sessionId && current.sessionId.isNotEmpty;

      emit(
        current.copyWith(
          status: newStatus,
          isPaused: gameData['isPaused'] ?? false,
          sessionId: newSessionId,
          gamePattern: gameData['gamePattern'] ?? 'full_house',
          prizePool: (gameData['prizePool'] ?? 0).toDouble(),
          gamePrice: (gameData['cardPrice'] ?? 10).toDouble(),
          winners: List<String>.from(gameData['winners'] ?? []),
          cardsSoldCount: gameData['cardsSold'] ?? current.cardsSoldCount,
          winnerId: gameData['winnerId'] ?? current.winnerId,
          hasWon: newStatus == GameStatus.won && gameData['winnerId'] == userId,
          startTime: gameData['createdAt'] != null 
              ? (gameData['createdAt'] as dynamic).toDate() 
              : null,
          statusStr: statusStr.toUpperCase(),
          markedCells: sessionChanged ? {} : null,
          blockedCardIds: sessionChanged ? {} : null,
          userCards: current.userCards.where((c) => c.sessionId == newSessionId || c.sessionId.isEmpty).toList(),
        ),
      );
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
    final map = Map<String, Set<String>>.from(current.markedCells);
    final cells = Set<String>.from(map[cardId] ?? {});
    final key = '$row-$col';

    if (cells.contains(key)) {
      cells.remove(key);
    } else {
      cells.add(key);
    }

    map[cardId] = cells;
    emit(current.copyWith(markedCells: map));
  }

  /// GET PENDING CARD (Previously Buy)
  Future<void> buyCard() async {
    if (state is! GameLoaded) return;
    try {
      await _bingoRepository.buyCartelas(userId, []);
      await refreshCards();
    } catch (e) {
      print("Failed to buy card: $e");
    }
  }

  /// REGISTER PENDING CARD
  Future<void> registerCard(String cardId) async {
    if (state is! GameLoaded) return;
    try {
      await _bingoRepository.registerCard(cardId);
      await refreshCards();
    } catch (e) {
      print("Failed to register card: $e");
    }
  }

  /// REMOVE PENDING CARD
  Future<void> removeCard(String cardId) async {
    if (state is! GameLoaded) return;
    try {
      await _bingoRepository.removeCard(cardId);
      await refreshCards();
    } catch (e) {
      print("Failed to remove card: $e");
    }
  }

  /// CLAIM BINGO VIA CLOUD FUNCTION
  Future<void> claimBingo(String cardId) async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;

    final success = await _bingoRepository.claimBingo('live', cardId);

    if (!success) {
      final blocked = Set<String>.from(current.blockedCardIds)..add(cardId);
      emit(current.copyWith(blockedCardIds: blocked));
    }
  }
}
