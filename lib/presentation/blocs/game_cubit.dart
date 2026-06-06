import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/bingo_card.dart';
import '../../domain/repositories/bingo_repository.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/service_locator.dart';
import '../../core/services/card_generator_service.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/favourites_service.dart';

const Object _sentinel = Object();

const String kLiveGameId = 'live';
const int kDefaultBuyingCountdown = 120;

enum GameStatus { buying, active, won, waiting, paused }

// ─────────────────────────────────────────────────────────────────────────────
// SUB-STATES
//
// GameLoaded previously had 26 props in a single flat class. This caused two
// problems:
//   1. Any server snapshot (drawn number, player count, status) triggered an
//      Equatable rebuild of the entire state including UI-only fields.
//   2. Every new feature added another prop to a class that was already hard
//      to read.
//
// Solution: split into two focused value objects that GameLoaded composes.
//
//   GameSessionState  — server-owned data (Firestore stream → cubit → UI)
//   GameUIState       — client-owned data (user interactions → cubit → UI)
//
// GameLoaded itself stays the public API: state.drawnNumbers, state.isActionLoading
// etc. all still work unchanged. The UI doesn't need to know about the split.
// ─────────────────────────────────────────────────────────────────────────────

/// All data that originates from Firestore / Cloud Functions.
/// Updated on every server snapshot. Isolated so that a drawn-number update
/// does not force Equatable to re-compare UI fields like markedCells.
class GameSessionState extends Equatable {
  final List<int> drawnNumbers;
  final List<BingoCard> userCards;
  final List<String> winners;
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
  final DateTime? claimDeadline;
  final List<int> allBlockedCardNos;

  const GameSessionState({
    required this.drawnNumbers,
    required this.userCards,
    this.winners = const [],
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
    this.claimDeadline,
    this.allBlockedCardNos = const [],
  });

  List<int> get lastDrawnNumbers {
    if (drawnNumbers.isEmpty) return [];
    return drawnNumbers.reversed.take(10).toList();
  }

  @override
  List<Object?> get props => [
    drawnNumbers, userCards, winners, rawClaimsData, rawWinnersData,
    winningCardNo, winningCardNumbers, sessionId, isPaused, gamePattern,
    gamePrice, prizePool, hasWon, winnerId, status, buyingCountdown,
    playerCount, cardsSoldCount, startTime, statusStr, broadcastMessage,
    statusMessage, pendingClaims, claimDeadline, allBlockedCardNos,
  ];

  GameSessionState copyWith({
    List<int>? drawnNumbers,
    List<BingoCard>? userCards,
    List<String>? winners,
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
    Object? claimDeadline = _sentinel,
    List<int>? allBlockedCardNos,
  }) {
    return GameSessionState(
      drawnNumbers: drawnNumbers ?? this.drawnNumbers,
      userCards: userCards ?? this.userCards,
      winners: winners ?? this.winners,
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
      claimDeadline: claimDeadline == _sentinel ? this.claimDeadline : claimDeadline as DateTime?,
      allBlockedCardNos: allBlockedCardNos ?? this.allBlockedCardNos,
    );
  }
}

/// All data that lives only on the client — user interactions, optimistic
/// updates, and display toggles. Never written to Firestore.
class GameUIState extends Equatable {
  final Map<String, Set<String>> markedCells;
  final Set<String> blockedCardIds;
  final List<String> claimedCardIds;
  final bool isActionLoading;
  final bool isAutoDaubEnabled;
  /// Card numbers the user has starred as favourites (persisted locally via
  /// FavouritesService). Favourited cards float to the top of the grid
  /// during the buying phase so the user can buy their lucky card faster.
  final Set<int> favouriteCardNos;

  const GameUIState({
    this.markedCells = const {},
    this.blockedCardIds = const {},
    this.claimedCardIds = const [],
    this.isActionLoading = false,
    this.isAutoDaubEnabled = true,
    this.favouriteCardNos = const {},
  });

  @override
  List<Object?> get props => [
    markedCells, blockedCardIds, claimedCardIds,
    isActionLoading, isAutoDaubEnabled, favouriteCardNos,
  ];

  GameUIState copyWith({
    Map<String, Set<String>>? markedCells,
    Set<String>? blockedCardIds,
    List<String>? claimedCardIds,
    bool? isActionLoading,
    bool? isAutoDaubEnabled,
    Set<int>? favouriteCardNos,
  }) {
    return GameUIState(
      markedCells: markedCells ?? this.markedCells,
      blockedCardIds: blockedCardIds ?? this.blockedCardIds,
      claimedCardIds: claimedCardIds ?? this.claimedCardIds,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      isAutoDaubEnabled: isAutoDaubEnabled ?? this.isAutoDaubEnabled,
      favouriteCardNos: favouriteCardNos ?? this.favouriteCardNos,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP-LEVEL STATES
// ─────────────────────────────────────────────────────────────────────────────

abstract class GameState extends Equatable {
  @override
  List<Object?> get props => [];
}

class GameInitial extends GameState {}

class GameLoading extends GameState {}

/// Emitted when the Firestore stream dies mid-game (e.g. permission revoked,
/// network error that connectivity resubscription cannot recover from).
/// The UI should show a recovery prompt instead of freezing silently.
class GameStreamError extends GameState {
  final String message;
  GameStreamError(this.message);

  @override
  List<Object?> get props => [message];
}

/// The loaded state the rest of the app works with.
///
/// Composes [GameSessionState] and [GameUIState] but exposes every field as a
/// direct getter so all existing UI code (`state.drawnNumbers`,
/// `state.isActionLoading`, etc.) works without modification.
///
/// To update: use [copyWithSession] for server data, [copyWithUI] for
/// interaction data, or [copyWith] when both change in the same emit.
class GameLoaded extends GameState {
  final GameSessionState session;
  final GameUIState ui;

  GameLoaded({required this.session, required this.ui});

  // ── Server-owned field pass-throughs ────────────────────────────────────
  List<int>          get drawnNumbers      => session.drawnNumbers;
  List<BingoCard>    get userCards         => session.userCards;
  List<String>       get winners           => session.winners;
  List<Map<String, dynamic>> get rawClaimsData  => session.rawClaimsData;
  List<Map<String, dynamic>> get rawWinnersData => session.rawWinnersData;
  int?               get winningCardNo     => session.winningCardNo;
  List<int>?         get winningCardNumbers => session.winningCardNumbers;
  String             get sessionId         => session.sessionId;
  bool               get isPaused          => session.isPaused;
  String             get gamePattern       => session.gamePattern;
  double             get gamePrice         => session.gamePrice;
  double             get prizePool         => session.prizePool;
  bool               get hasWon            => session.hasWon;
  String?            get winnerId          => session.winnerId;
  GameStatus         get status            => session.status;
  int                get buyingCountdown   => session.buyingCountdown;
  int                get playerCount       => session.playerCount;
  int                get cardsSoldCount    => session.cardsSoldCount;
  DateTime?          get startTime         => session.startTime;
  String             get statusStr         => session.statusStr;
  String?            get broadcastMessage  => session.broadcastMessage;
  String?            get statusMessage     => session.statusMessage;
  List<String>       get pendingClaims     => session.pendingClaims;
  DateTime?          get claimDeadline     => session.claimDeadline;
  List<int>          get allBlockedCardNos => session.allBlockedCardNos;
  List<int>          get lastDrawnNumbers  => session.lastDrawnNumbers;

  // ── Client-owned field pass-throughs ────────────────────────────────────
  Map<String, Set<String>> get markedCells      => ui.markedCells;
  Set<String>              get blockedCardIds   => ui.blockedCardIds;
  List<String>             get claimedCardIds   => ui.claimedCardIds;
  bool                     get isActionLoading  => ui.isActionLoading;
  bool                     get isAutoDaubEnabled => ui.isAutoDaubEnabled;
  Set<int>                 get favouriteCardNos => ui.favouriteCardNos;

  @override
  List<Object?> get props => [session, ui];

  // ── Targeted copy helpers ────────────────────────────────────────────────

  /// Use when only server data changes (Firestore snapshot).
  GameLoaded copyWithSession(GameSessionState newSession) =>
      GameLoaded(session: newSession, ui: ui);

  /// Use when only UI/interaction state changes (user tap, toggle).
  GameLoaded copyWithUI(GameUIState newUI) =>
      GameLoaded(session: session, ui: newUI);

  /// Full copyWith — maps all 26 original props to the right sub-object.
  /// Keeps the original call sites working without modification.
  GameLoaded copyWith({
    // Session fields
    List<int>? drawnNumbers,
    List<BingoCard>? userCards,
    List<String>? winners,
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
    Object? claimDeadline = _sentinel,
    List<int>? allBlockedCardNos,
    // UI fields
    Map<String, Set<String>>? markedCells,
    Set<String>? blockedCardIds,
    List<String>? claimedCardIds,
    bool? isActionLoading,
    bool? isAutoDaubEnabled,
    Set<int>? favouriteCardNos,
  }) {
    return GameLoaded(
      session: session.copyWith(
        drawnNumbers: drawnNumbers,
        userCards: userCards,
        winners: winners,
        rawClaimsData: rawClaimsData,
        rawWinnersData: rawWinnersData,
        winningCardNo: winningCardNo,
        winningCardNumbers: winningCardNumbers,
        sessionId: sessionId,
        isPaused: isPaused,
        gamePattern: gamePattern,
        gamePrice: gamePrice,
        prizePool: prizePool,
        hasWon: hasWon,
        winnerId: winnerId,
        status: status,
        buyingCountdown: buyingCountdown,
        playerCount: playerCount,
        cardsSoldCount: cardsSoldCount,
        startTime: startTime,
        statusStr: statusStr,
        broadcastMessage: broadcastMessage,
        statusMessage: statusMessage,
        pendingClaims: pendingClaims,
        claimDeadline: claimDeadline,
        allBlockedCardNos: allBlockedCardNos,
      ),
      ui: ui.copyWith(
        markedCells: markedCells,
        blockedCardIds: blockedCardIds,
        claimedCardIds: claimedCardIds,
        isActionLoading: isActionLoading,
        isAutoDaubEnabled: isAutoDaubEnabled,
        favouriteCardNos: favouriteCardNos,
      ),
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
  // Track the last session ID for which we have already cleared stale
  // per-session fields (blockedCardNos, winners). When the session changes we
  // reset those fields to empty on the first snapshot; on every subsequent
  // snapshot in the SAME new session we must NOT re-read the stale Firestore
  // values that the CF may not have cleared yet.
  String _lastClearedSessionId = '';

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

  /// Public entry point for the error-fallback reconnect button.
  /// Resets state to loading and re-runs the full initialization sequence.
  Future<void> reconnect() async {
    emit(GameLoading());
    await _init();
  }

  Future<void> _init() async {
    try {
      final initialSessionId = await _bingoRepository.getLiveSessionId();
      final cards = await _bingoRepository.getUserCartelas(userId, kLiveGameId,
          sessionId: initialSessionId.isNotEmpty ? initialSessionId : null,
        );
      if (isClosed) return;

      emit(GameLoaded(
        session: GameSessionState(
          drawnNumbers: [],
          userCards: cards,
          sessionId: initialSessionId,
          status: GameStatus.buying,
          buyingCountdown: kDefaultBuyingCountdown,
          playerCount: 0,
          cardsSoldCount: cards.length,
        ),
        ui: GameUIState(
          blockedCardIds: cards.where((c) => c.isBlocked).map((c) => c.id).toSet(),
        ),
      ));

      // Load persisted favourite card numbers and reflect them in UI state.
      final favourites = await sl<FavouritesService>().load(userId);
      if (!isClosed && state is GameLoaded && favourites.isNotEmpty) {
        emit((state as GameLoaded).copyWithUI(
          (state as GameLoaded).ui.copyWith(favouriteCardNos: favourites),
        ));
      }

      if (initialSessionId.isNotEmpty) {
        _resubscribeDraws(initialSessionId);
        _resubscribeWinners(initialSessionId);
      }

      _gameSub = _bingoRepository.streamGame(kLiveGameId).listen((gameData) async {
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
        final bool gameEnded =
            newStatus == GameStatus.won || newStatus == GameStatus.waiting;

        if (newStatus == GameStatus.won && !current.hasWon && gameData['winnerId'] == userId) {
          AudioService().playWin();
        }

        if (sessionChanged && newSessionId.isNotEmpty) {
          _drawsSub?.cancel();
          _resubscribeDraws(newSessionId);
          _resubscribeWinners(newSessionId);
        }

        if (isClosed) return;

        if (sessionChanged && newSessionId.isNotEmpty) {
          _lastClearedSessionId = newSessionId;
        }
        if (gameEnded) {
          _lastClearedSessionId = newSessionId;
        }
        final bool suppressStaleBlocked = newSessionId == _lastClearedSessionId;

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

        final List<int> resolvedBlockedCardNos = suppressStaleBlocked
            ? []
            : List<int>.from(gameData['blockedCardNos'] ?? []);

        // Server-owned fields → update session sub-state only.
        final newSession = current.session.copyWith(
          status: newStatus,
          isPaused: gameData['isPaused'] ?? false,
          sessionId: newSessionId,
          gamePattern: gameData['gamePattern'] ?? 'full_house',
          prizePool: (gameData['prizePool'] ?? 0).toDouble(),
          gamePrice: (gameData['cardPrice'] ?? 10).toDouble(),
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
          winners: sessionChanged
              ? []
              : (newStatus == GameStatus.won && gameData['winningCardNo'] != null
                  ? [gameData['winningCardNo'].toString()]
                  : null),
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
          drawnNumbers: mergedDrawnNumbers,
          userCards: sessionChanged
              ? current.userCards.where((c) => c.sessionId == newSessionId || c.status == 'pending').toList()
              : null,
          allBlockedCardNos: resolvedBlockedCardNos,
        );

        // Client-owned fields → update UI sub-state only.
        final newUI = current.ui.copyWith(
          markedCells: sessionChanged ? {} : fallbackAutoMarked,
          blockedCardIds: (sessionChanged || gameEnded) ? {} : null,
          claimedCardIds: sessionChanged ? [] : null,
        );

        emit(GameLoaded(session: newSession, ui: newUI));

        final bool transitionedToBuying =
            newStatus == GameStatus.buying && current.status != GameStatus.buying;

        if (newStatus == GameStatus.active && newSessionId == _lastClearedSessionId) {
          _lastClearedSessionId = '';
        }

        if ((gameEnded && current.status != newStatus) || sessionChanged) {
          final sessionToDelete = current.sessionId;
          if (sessionToDelete.isNotEmpty) {
            await _bingoRepository
                .deleteCardsForSession(userId, sessionToDelete)
                .catchError((e) => Log.e('deleteCardsForSession error', e));
          }
        }

        if (sessionChanged || gameEnded || transitionedToBuying) {
          if (!isClosed) refreshCards();
        }
      }, onError: (Object e, StackTrace stack) {
        Log.e('GameCubit main stream error', e, stack);
        if (!isClosed) emit(GameStreamError('Connection lost. Please restart the game.'));
      });
    } catch (e, stack) {
      Log.e("GameCubit initialization failed", e, stack);
    }
  }

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
      // Winners come from the server → session sub-state.
      emit(current.copyWithSession(
        current.session.copyWith(winners: cardNumbers, rawWinnersData: winnersList),
      ));
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
          .where((c) => c.status == 'pending')
          .toList();
      final combinedCards = [...activeDbCards, ...localPendingCards].toList();
      final mergedBlocked = combinedCards
          .where((c) => c.isBlocked && c.sessionId == current.sessionId)
          .map((c) => c.id)
          .toSet();

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
    // markCell is UI-only → update only the UI sub-state.
    emit(current.copyWithUI(current.ui.copyWith(markedCells: map)));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUY CARD (local generation)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> buyCard({int count = 1}) async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;
    emit(current.copyWithUI(current.ui.copyWith(isActionLoading: true)));
    try {
      final existingCardNos = current.userCards.map((c) => c.cardNo).toSet();
      final newCards = await sl<CardGeneratorService>().generateCards(
        count: count,
        existingCardNos: existingCardNos,
        gamePrice: current.gamePrice,
        sessionId: current.sessionId,
      );
      // New cards go in session (userCards) but we also clear the loading flag (UI).
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
    emit(current.copyWithUI(current.ui.copyWith(isActionLoading: true)));
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
      emit(current.copyWithSession(current.session.copyWith(userCards: updatedCards)));

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

    emit(current.copyWithUI(current.ui.copyWith(isActionLoading: true)));
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
    emit(current.copyWithSession(current.session.copyWith(userCards: updatedCards)));

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
        final blockedCard = current.userCards.firstWhereOrNull((card) => card.id == cardId);
        if (blockedCard != null) {
          await _bingoRepository.broadcastBlockedCard(blockedCard.cardNo);
        }
        await refreshCards();
        if (isClosed) return;
        emit((state as GameLoaded).copyWith(
            isActionLoading: false,
            blockedCardIds: blocked,
            statusMessage: "Invalid claim! Card blocked."));
      } else if (success == true) {
        final alreadyClaimed = List<String>.from(
            (state as GameLoaded).claimedCardIds)
          ..add(cardId);
        // Optimistic UI update → UI sub-state only.
        emit((state as GameLoaded).copyWithUI(
          (state as GameLoaded).ui.copyWith(
            isActionLoading: false,
            claimedCardIds: alreadyClaimed,
          ),
        ));
        // Status message spans both → full copyWith.
        emit((state as GameLoaded).copyWith(
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
        final blockedCards = current.userCards.where((card) => cardIds.contains(card.id)).toList();
        await Future.wait(blockedCards.map((card) => _bingoRepository.broadcastBlockedCard(card.cardNo)));
        await refreshCards();
        if (isClosed) return;
        emit((state as GameLoaded).copyWith(
            isActionLoading: false,
            blockedCardIds: blocked,
            statusMessage: "Invalid claims! Cards blocked."));
      } else if (success == true) {
        final alreadyClaimed = List<String>.from(
            (state as GameLoaded).claimedCardIds)
          ..addAll(cardIds);
        emit((state as GameLoaded).copyWithUI(
          (state as GameLoaded).ui.copyWith(
            isActionLoading: false,
            claimedCardIds: alreadyClaimed,
          ),
        ));
        emit((state as GameLoaded).copyWith(
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

    // toggleAutoDaub is purely UI → UI sub-state + statusMessage via copyWith.
    emit(current.copyWith(
      isAutoDaubEnabled: enabled,
      markedCells: newMarkedCells,
      statusMessage: enabled ? "Auto-Daub Assistant enabled!" : "Auto-Daub Assistant disabled.",
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FAVOURITES
  // ─────────────────────────────────────────────────────────────────────────

  /// Toggles [cardNo] in or out of the user's local favourites list.
  ///
  /// Persisted via [FavouritesService] (SharedPreferences) so the list
  /// survives app restarts. The UI reflects the change immediately via
  /// an optimistic emit; the async persist runs in the background.
  Future<void> toggleFavourite(int cardNo) async {
    if (state is! GameLoaded) return;
    final current = state as GameLoaded;

    // Optimistic emit — update UI before the disk write completes.
    final updated = Set<int>.from(current.favouriteCardNos);
    if (updated.contains(cardNo)) {
      updated.remove(cardNo);
    } else {
      updated.add(cardNo);
    }
    emit(current.copyWithUI(current.ui.copyWith(favouriteCardNos: updated)));

    // Persist in the background; errors are non-fatal (preference only).
    try {
      await sl<FavouritesService>().toggle(userId, cardNo);
    } catch (e) {
      Log.e('toggleFavourite persist failed', e);
    }
  }
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

      // drawnNumbers comes from server → session; autoMarked is UI.
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
      message = '__INSUFFICIENT_BALANCE__';
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