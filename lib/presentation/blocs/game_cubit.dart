import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/bingo_card.dart';
import '../../domain/repositories/bingo_repository.dart';
import '../../core/utils/bingo_engine.dart';

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
  final List<BingoCard> heldCards;
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

  GameLoaded({
    required this.drawnNumbers,
    required this.markedCells,
    required this.userCards,
    this.heldCards = const [],
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
  });

  List<int> get lastDrawnNumbers {
    if (drawnNumbers.isEmpty) return [];
    return drawnNumbers.reversed.take(5).toList();
  }

  @override
  List<Object?> get props => [
    drawnNumbers,
    markedCells,
    userCards,
    heldCards,
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
  ];

  GameLoaded copyWith({
    List<int>? drawnNumbers,
    Map<String, Set<String>>? markedCells,
    List<BingoCard>? userCards,
    List<BingoCard>? heldCards,
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
  }) {
    return GameLoaded(
      drawnNumbers: drawnNumbers ?? this.drawnNumbers,
      markedCells: markedCells ?? this.markedCells,
      userCards: userCards ?? this.userCards,
      heldCards: heldCards ?? this.heldCards,
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
    );
  }
}

class GameCubit extends Cubit<GameState> {
  final BingoRepository _bingoRepository;
  final String gameId;
  final String userId;

  GameCubit({
    required BingoRepository bingoRepository,
    required this.gameId,
    required this.userId,
  }) : _bingoRepository = bingoRepository,
       super(GameInitial()) {
    _init();
  }

  void _init() async {
    final cards = await _bingoRepository.getUserCartelas(userId, gameId);

    emit(
      GameLoaded(
        drawnNumbers: [],
        markedCells: {},
        userCards: cards,
        status: GameStatus.buying,
        buyingCountdown: 120, // 2 minutes mock
        playerCount: 12,
        cardsSoldCount: 45,
      ),
    );

    // Listen to live updates
    _bingoRepository.streamDrawnNumbers(gameId).listen((numbers) {
      if (state is GameLoaded) {
        final currentState = state as GameLoaded;
        final isStarting =
            numbers.isNotEmpty && currentState.drawnNumbers.isEmpty;

        emit(
          currentState.copyWith(
            drawnNumbers: numbers,
            status: numbers.isNotEmpty
                ? GameStatus.active
                : currentState.status,
            heldCards: isStarting
                ? []
                : currentState.heldCards, // Clear if game starts
          ),
        );
      }
    });

    _bingoRepository.streamGame(gameId).listen((gameData) {
      if (state is GameLoaded) {
        final currentState = state as GameLoaded;
        final statusStr = gameData['status'] ?? 'active';
        final GameStatus status = statusStr == 'buying'
            ? GameStatus.buying
            : statusStr == 'won'
            ? GameStatus.won
            : statusStr == 'paused'
            ? GameStatus.paused
            : GameStatus.active;

        emit(
          currentState.copyWith(
            status: status,
            isPaused: gameData['isPaused'] ?? false,
            sessionId: gameData['sessionId'] ?? '',
            gamePattern: gameData['pattern'] ?? 'Full House',
            prizePool: (gameData['prize'] ?? 250.0).toDouble(),
            winners: List<String>.from(gameData['winners'] ?? []),
          ),
        );
      }
    });
  }

  void markCell(String cardId, int row, int col) {
    if (state is GameLoaded) {
      final currentState = state as GameLoaded;
      final newMarkedMap = Map<String, Set<String>>.from(
        currentState.markedCells,
      );
      final cells = Set<String>.from(newMarkedMap[cardId] ?? {});

      final key = '$row-$col';
      if (cells.contains(key)) {
        cells.remove(key);
      } else {
        cells.add(key);
      }

      newMarkedMap[cardId] = cells;
      emit(currentState.copyWith(markedCells: newMarkedMap));
    }
  }

  void buyCard() async {
    final newCard = BingoEngine.generateCard(
      id: 'card_${DateTime.now().millisecondsSinceEpoch}',
    );
    holdCards([newCard]);
  }

  void holdCards(List<BingoCard> cards) {
    if (state is GameLoaded) {
      final currentState = state as GameLoaded;
      final existingIds = {
        ...currentState.userCards.map((c) => c.id),
        ...currentState.heldCards.map((c) => c.id),
      };

      final newUniqueCards = cards
          .where((c) => !existingIds.contains(c.id))
          .toList();
      if (newUniqueCards.isEmpty) return;

      final newHeld = List<BingoCard>.from(currentState.heldCards)
        ..addAll(newUniqueCards);
      emit(currentState.copyWith(heldCards: newHeld));
    }
  }

  void removeHeldCard(String cardId) {
    if (state is GameLoaded) {
      final currentState = state as GameLoaded;
      final newHeld = currentState.heldCards
          .where((c) => c.id != cardId)
          .toList();
      emit(currentState.copyWith(heldCards: newHeld));
    }
  }

  Future<void> registerCard(String cardId) async {
    if (state is GameLoaded) {
      final currentState = state as GameLoaded;

      // Balance check
      final balance = await _bingoRepository.getBalance(userId);
      if (balance < currentState.gamePrice) {
        throw Exception('Insufficient balance. Please deposit more ETB.');
      }

      final card = currentState.heldCards.firstWhere((c) => c.id == cardId);

      await _bingoRepository.buyCartelas(userId, [card]);

      final updatedUserCards = await _bingoRepository.getUserCartelas(
        userId,
        gameId,
      );
      final updatedHeldCards = currentState.heldCards
          .where((c) => c.id != cardId)
          .toList();

      emit(
        currentState.copyWith(
          userCards: updatedUserCards,
          heldCards: updatedHeldCards,
        ),
      );
    }
  }

  Future<void> claimBingo(String cardId) async {
    if (state is GameLoaded) {
      final currentState = state as GameLoaded;
      final card = currentState.userCards.firstWhere((c) => c.id == cardId);

      final isWin = BingoEngine.checkWin(
        card.numbers,
        currentState.drawnNumbers,
        currentState.gamePattern,
      );

      if (isWin) {
        // Handle win
        await _bingoRepository.createGame(gameId, {
          'winnerId': userId,
          'winnerName': 'User $userId', // In real app, fetch display name
          'status': 'won',
          'prize': currentState.prizePool,
        });
        emit(
          currentState.copyWith(
            hasWon: true,
            status: GameStatus.won,
            winnerId: userId,
          ),
        );
      } else {
        // False bingo - Block card
        final newBlocked = Set<String>.from(currentState.blockedCardIds)
          ..add(cardId);
        emit(currentState.copyWith(blockedCardIds: newBlocked));
        // You might also want to log this false bingo to the backend
      }
    }
  }
}
