import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:confetti/confetti.dart';
import 'package:animate_do/animate_do.dart';

import '../blocs/game_cubit.dart';
import '../blocs/wallet_cubit.dart';
import 'payment_page.dart';
import 'profile_page.dart';
import '../widgets/settings_drawer.dart';
import '../widgets/game/session_card_widget.dart';
import '../widgets/game/recent_numbers_widget.dart';
import '../widgets/game/live_board_widget.dart';
import '../widgets/game/cards_grid_widget.dart';
import '../widgets/game/horizontal_badge_list.dart';
import '../widgets/game/winning_card_dialog.dart';
import '../widgets/game/card_transparency_dialog.dart';
import 'package:bingo_mk/presentation/widgets/loading_widgets.dart';
import 'package:bingo_mk/core/l10n/app_strings.dart';
import 'package:bingo_mk/presentation/blocs/settings_cubit.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
class _C {
  static bool get _l => SettingsCubit.isLightModeGlobal;

  static Color get bg          => _l ? const Color(0xFFF2F4F7) : const Color(0xFF0E1321);
  static Color get bgDeep      => _l ? const Color(0xFFE4E7EC) : const Color(0xFF090E1C);
  static Color get surface     => _l ? const Color(0xFFFFFFFF) : const Color(0xFF161B2A);
  static Color get surfaceHigh => _l ? const Color(0xFFF9FAFB) : const Color(0xFF1A1F2E);
  static Color get surfaceTop  => _l ? const Color(0xFFF0F2F5) : const Color(0xFF252A39);
  static Color get divider     => _l ? const Color(0xFFEAECF0) : const Color(0xFF303444);

  static const gold        = Color(0xFFF1C100);
  static const goldLight   = Color(0xFFFFE8AE);
  static const goldFill    = Color(0x1AF1C100);
  static const goldBorder  = Color(0x40F1C100);

  static const blue        = Color(0xFF006BE3);
  static const blueLight   = Color(0xFFADC6FF);
  static const blueFill    = Color(0x1A006BE3);
  static const blueBorder  = Color(0x40006BE3);

  static const success     = Color(0xFF2A9D8F);
  static const danger      = Color(0xFFE63946);
  static const warning     = Color(0xFFF59E0B);
  static const pink        = Color(0xFFFFB2B8);

  static Color get textHigh    => _l ? const Color(0xFF101828) : const Color(0xFFDEE2F6);
  static Color get textMid     => _l ? const Color(0xFF475467) : const Color(0xFFD1C5AB);
  static Color get textLow     => _l ? const Color(0xFF667085) : const Color(0xFF9A9078);
}

class _T {
  static TextStyle get display => const TextStyle(
    fontFamily: 'Orbitron',
    letterSpacing: 0.05,
  ).copyWith(color: _C.textHigh);
  static TextStyle label({
    double size = 11,
    Color? color,
    double spacing = 0.8,
    FontWeight weight = FontWeight.w700,
  }) => TextStyle(
    fontFamily: 'Outfit',
    fontSize: size,
    fontWeight: weight,
    letterSpacing: spacing,
    color: color ?? _C.textMid,
  );
  static TextStyle body({
    double size = 13,
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) => TextStyle(
    fontFamily: 'Outfit',
    fontSize: size,
    fontWeight: weight,
    color: color ?? _C.textHigh,
  );
  static TextStyle number({double size = 20, Color? color}) => TextStyle(
    fontFamily: 'Orbitron',
    fontSize: size,
    fontWeight: FontWeight.w800,
    color: color ?? _C.textHigh,
  );
}

BoxDecoration _glassDeco({
  Color? bg,
  Color? border,
  double radius = 16,
  List<BoxShadow>? shadows,
}) => BoxDecoration(
  color: bg ?? _C.surface,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: border ?? Colors.white.withOpacity(0.08), width: 1),
  boxShadow: shadows,
);

// ─────────────────────────────────────────────────────────────────────────────
class GamePage extends StatefulWidget {
  final Function(int index)? onTabChanged;
  const GamePage({super.key, this.onTabChanged});
  @override State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late ConfettiController _confettiController;

  bool _expanded = false; // Default to compact mode to fit 4 cartelas
  bool _shownWinSnack = false;
  bool _shownDialog = false;
  String? _lastShownStatusMessage;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 10));
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<GameCubit>().onAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      // Only rebuild the page tree when the theme or language actually changes.
      // Without this, every SettingsState emit (e.g. any unrelated settings
      // toggle) forces the entire GamePage subtree to re-evaluate.
      buildWhen: (prev, next) =>
          prev.isLightMode != next.isLightMode ||
          prev.isAmharic != next.isAmharic,
      builder: (context, _) => BlocConsumer<GameCubit, GameState>(
      listener: (context, state) {
        if (state is GameLoaded) {
          final message = state.broadcastMessage;
          if (message != null && message.isNotEmpty) {
            if (message != _lastShownStatusMessage) {
              _lastShownStatusMessage = message;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  _styledSnack(
                    message,
                    message.contains('Failed') || message.contains('Invalid')
                        ? _C.danger
                        : _C.success,
                  ),
                );
              });
            }
          } else {
            _lastShownStatusMessage = null;
          }

          final statusMsg = state.statusMessage;
          if (statusMsg != null && statusMsg.contains('__INSUFFICIENT_BALANCE__')) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showInsufficientBalanceDialog(context);
            });
          } else if (statusMsg != null &&
              statusMsg.isNotEmpty &&
              statusMsg != _lastShownStatusMessage) {
            _lastShownStatusMessage = statusMsg;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                _styledSnack(
                  statusMsg,
                  (statusMsg.toLowerCase().contains('failed') ||
                          statusMsg.toLowerCase().contains('error') ||
                          statusMsg.toLowerCase().contains('insufficient'))
                      ? _C.danger
                      : _C.success,
                ),
              );
            });
          }

          if (state.status == GameStatus.won && state.hasWon) {
            _confettiController.play();
            if (!_shownWinSnack) {
              _shownWinSnack = true;
              ScaffoldMessenger.of(context).showSnackBar(
                _styledSnack(S.youWon, _C.success),
              );
            }
            if (!_shownDialog) {
              _shownDialog = true;
              showWinningCardDialog(context, state);
            }
          } else {
            _confettiController.stop();
            _shownWinSnack = false;
            _shownDialog = false;
          }
        }
      },
      builder: (context, state) {
        return Stack(
          children: [
            Scaffold(
              key: _scaffoldKey,
              backgroundColor: _C.bg,
              endDrawer: MultiBlocProvider(
                providers: [
                  BlocProvider.value(value: context.read<WalletCubit>()),
                  BlocProvider.value(value: context.read<GameCubit>()),
                ],
                child: SettingsDrawer(onClose: () => Navigator.pop(context)),
              ),
              appBar: _buildAppBar(context, state),
              body: state is GameLoaded
                  ? _buildBody(context, state)
                  : state is GameStreamError
                      ? _buildStreamErrorFallback(context, state)
                      : const GamePageSkeleton(),
              floatingActionButton: state is GameLoaded &&
                      state.status == GameStatus.buying
                  ? _BuyCardsButton(onTap: () => _showBuySheet(context, state))
                  : null,
            ),
            // Confetti
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Color(0xFFF1C100), Color(0xFFADC6FF),
                  Color(0xFFFFB2B8), Color(0xFF2A9D8F), Colors.white,
                ],
              ),
            ),
          ],
        );
      },
    ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, GameState state) {
    final bool autoDaub = state is GameLoaded && state.isAutoDaubEnabled;

    return AppBar(
      backgroundColor: _C.bgDeep,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _C.divider),
      ),
      leading: _AppBarAvatar(
        onTap: () {
          if (widget.onTabChanged != null) {
            widget.onTabChanged!(2);
          } else {
            final walletCubit = context.read<WalletCubit>();
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: walletCubit, child: const ProfilePage()),
            ));
          }
        },
      ),
      title: BlocBuilder<WalletCubit, WalletState>(
        builder: (context, ws) {
          final balance = ws is WalletLoaded ? ws.balance : 0.0;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _WalletBadge(
                balance: balance,
                onTap: () {
                  if (widget.onTabChanged != null) {
                    widget.onTabChanged!(1);
                  } else {
                    final walletCubit = context.read<WalletCubit>();
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: walletCubit, child: const PaymentPage()),
                    ));
                  }
                },
              ),
              if (!_expanded && state is GameLoaded) ...[
                const SizedBox(width: 8),
                _AppBarTimerWidget(state: state),
              ],
            ],
          );
        },
      ),
      actions: [
        IconButton(
          icon: Icon(
            _expanded ? Icons.grid_view_rounded : Icons.view_headline_rounded,
            color: _expanded ? _C.blueLight : _C.textMid,
            size: 20,
          ),
          onPressed: () => setState(() => _expanded = !_expanded),
          tooltip: _expanded ? "Compact View" : "Full Board View",
        ),
        IconButton(
          icon: Icon(Icons.tune_rounded, color: _C.textMid, size: 22),
          onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  /// Shown when [GameStreamError] is emitted — i.e. the Firestore stream died
  /// mid-game and connectivity resubscription could not recover it.
  /// Gives the player a clear explanation and a one-tap retry instead of
  /// leaving them staring at a frozen board indefinitely.
  Widget _buildStreamErrorFallback(BuildContext context, GameStreamError state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: _C.danger),
            const SizedBox(height: 16),
            Text(
              'Connection Lost',
              style: _T.body(size: 18, weight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              state.message,
              style: _T.body(size: 13, color: _C.textMid),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.read<GameCubit>().reconnect(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reconnect'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, GameLoaded state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Fixed Top Section
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Session info card
              if (_expanded)
                FadeInDown(
                  duration: const Duration(milliseconds: 400),
                  child: SessionCardWidget(state: state),
                ),

              // Claim timer if paused
              if (state.claimDeadline != null && state.status == GameStatus.paused) ...[
                const SizedBox(height: 8),
                _ClaimTimerWidget(deadline: state.claimDeadline!),
              ],

              const SizedBox(height: 8),

              // Number board
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _expanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: LiveBoardWidget(drawnNumbers: state.drawnNumbers),
                ),
                secondChild: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: RecentNumbersWidget(numbers: state.drawnNumbers),
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),

        // Scrollable Bottom Section
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<GameCubit>().refreshCards(),
            color: _C.gold,
            backgroundColor: _C.surface,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

            // Badge lists
            // In the won state, game_history may not yet be written by the CF,
            if (state.status != GameStatus.buying && state.winners.isNotEmpty)
              HorizontalBadgeList(
                icon: Icons.emoji_events_rounded,
                color: _C.gold,
                label: S.winners,
                items: state.winners,
                onItemTap: (item) => showCardTransparencyDialog(
                    context, item, state, isWinner: true),
              ),
            if (state.pendingClaims.isNotEmpty)
              HorizontalBadgeList(
                icon: Icons.hourglass_empty_rounded,
                color: _C.warning,
                label: S.pending,
                items: state.pendingClaims,
                onItemTap: (item) => showCardTransparencyDialog(
                    context, item, state, isWinner: false),
              ),
            if (state.claimedCardIds.isNotEmpty)
              HorizontalBadgeList(
                icon: Icons.assignment_turned_in_rounded,
                color: _C.blueLight,
                label: S.claims,
                items: state.claimedCardIds,
                onItemTap: (item) => showCardTransparencyDialog(
                    context, item, state, isWinner: false),
              ),
            // Blocked cards: merge all-player broadcast + user's own blocked IDs
            if (state.allBlockedCardNos.isNotEmpty || state.blockedCardIds.isNotEmpty)
              HorizontalBadgeList(
                icon: Icons.block_rounded,
                color: _C.danger,
                label: S.blocked,
                items: [
                  // Broadcast card numbers visible to all players
                  ...state.allBlockedCardNos.map((n) => '#$n'),
                  // User's own blocked card IDs not already shown by cardNo.
                  // Only show if the card belongs to the current session —
                  // guards against stale IDs during the session-change race.
                  ...state.blockedCardIds.where((id) {
                    final card = state.userCards
                        .where((c) => c.id == id)
                        .firstOrNull;
                    if (card == null) return false; // unknown card → skip
                    if (card.sessionId != state.sessionId) return false; // wrong session → skip
                    return !state.allBlockedCardNos.contains(card.cardNo);
                  }).map((id) {
                    final card = state.userCards
                        .where((c) => c.id == id)
                        .firstOrNull;
                    return card != null ? '#${card.cardNo}' : id;
                  }),
                ].toSet().toList(), // deduplicate
                onItemTap: (item) => showCardTransparencyDialog(
                    context,
                    item.startsWith('#') ? item.substring(1) : item,
                    state,
                    isBlocked: true),
              ),

            const SizedBox(height: 4),

            // Bingo cards
            CardsGridWidget(
              cards: state.userCards
              .where((c) => c.sessionId == state.sessionId)
              .toList(),
              markedCells: state.markedCells,
              blockedCards: state.blockedCardIds,
              drawnNumbers: state.drawnNumbers,
              status: state.status,
              winningCardNo: state.status == GameStatus.buying
                  ? null
                  : state.winningCardNo,
              claimDeadline: state.claimDeadline,
              claimedCardIds: state.claimedCardIds,
              favouriteCardNos: state.favouriteCardNos,
            ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  SnackBar _styledSnack(String msg, Color color) => SnackBar(
    content: Row(children: [
      Icon(
        color == _C.success
            ? Icons.check_circle_rounded
            : Icons.info_rounded,
        color: color,
        size: 18,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(msg, style: _T.body(size: 13, weight: FontWeight.w600)),
      ),
    ]),
    backgroundColor: _C.surfaceHigh,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    duration: const Duration(seconds: 4),
  );

  void _showInsufficientBalanceDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (ctx) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: _C.bgDeep,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 24)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFE63946), Color(0xFFD62828)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(children: [
                    const Icon(Icons.account_balance_wallet_rounded,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'Insufficient Balance',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ]),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    'You don\'t have enough balance to buy a card.\nDeposit funds to continue playing.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.5,
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
                // Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Row(children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white10,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Colors.white24),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(
                              color: Colors.white60,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              decoration: TextDecoration.none,
                            )),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (widget.onTabChanged != null) {
                            widget.onTabChanged!(1);
                          } else {
                            final walletCubit = context.read<WalletCubit>();
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => BlocProvider.value(
                                value: walletCubit,
                                child: const PaymentPage(),
                              ),
                            ));
                          }
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: _C.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Deposit',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              decoration: TextDecoration.none,
                            )),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBuySheet(BuildContext context, GameLoaded state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _BuySheet(state: state, gameCubit: context.read<GameCubit>()),
    );
  }
}

// ─── AppBar avatar ────────────────────────────────────────────────────────────
class _AppBarAvatar extends StatelessWidget {
  final VoidCallback onTap;
  const _AppBarAvatar({required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(10),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _C.surfaceHigh,
          shape: BoxShape.circle,
          border: Border.all(color: _C.divider),
        ),
        child: Icon(Icons.person_rounded, color: _C.textMid, size: 20),
      ),
    ),
  );
}

// ─── AppBar Timer ─────────────────────────────────────────────────────────────
class _AppBarTimerWidget extends StatefulWidget {
  final GameLoaded state;
  const _AppBarTimerWidget({required this.state});

  @override
  State<_AppBarTimerWidget> createState() => _AppBarTimerWidgetState();
}

class _AppBarTimerWidgetState extends State<_AppBarTimerWidget> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final isPaused = s.status == GameStatus.paused;
    final isBuying = s.status == GameStatus.buying;

    int? secs;
    String timerLabel = "";
    if (isBuying) {
      secs = s.buyingCountdown > 0
          ? s.buyingCountdown
          : (s.startTime != null
              ? s.startTime!.toLocal().add(const Duration(minutes: 2)).difference(DateTime.now()).inSeconds.clamp(0, 999)
              : null);
      timerLabel = "Ends";
    } else if (isPaused && s.claimDeadline != null) {
      secs = s.claimDeadline!.difference(DateTime.now()).inSeconds.clamp(0, 999);
      timerLabel = "Claim";
    }

    if (secs == null || secs <= 0) return const SizedBox.shrink();

    final isUrgent = secs <= 15;
    final color = isUrgent ? _C.danger : _C.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            '${secs}s',
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Wallet badge in AppBar ───────────────────────────────────────────────────
class _WalletBadge extends StatelessWidget {
  final double balance;
  final VoidCallback onTap;
  const _WalletBadge({required this.balance, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _C.goldFill,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.goldBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: _C.gold.withOpacity(0.12),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.account_balance_wallet_rounded,
            color: _C.gold, size: 15),
        const SizedBox(width: 7),
        Text(
          '${balance.toStringAsFixed(2)} ETB',
          style: _T.display.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: _C.goldLight,
          ),
        ),
      ]),
    ),
  );
}



// ─── Claim timer ──────────────────────────────────────────────────────────────
class _ClaimTimerWidget extends StatefulWidget {
  final DateTime deadline;
  const _ClaimTimerWidget({required this.deadline});
  @override State<_ClaimTimerWidget> createState() => _ClaimTimerWidgetState();
}

class _ClaimTimerWidgetState extends State<_ClaimTimerWidget> {
  late Timer _timer;
  int _secs = 0;

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _update() {
    final diff = widget.deadline.difference(DateTime.now()).inSeconds;
    if (mounted) setState(() => _secs = diff.clamp(0, 60));
  }

  @override
  void dispose() { _timer.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_secs <= 0) return const SizedBox.shrink();
    final isUrgent = _secs <= 5;
    final color = isUrgent ? _C.danger : _C.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.12), blurRadius: 12),
        ],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.timer_rounded, color: color, size: 20),
        const SizedBox(width: 10),
        Text(
          S.claimWindow,
          style: _T.label(size: 12, color: color.withOpacity(0.8), spacing: 1.0),
        ),
        Text(
          '$_secs s',
          style: _T.number(size: 18, color: color),
        ),
      ]),
    );
  }
}

// ─── BUY CARDS button ─────────────────────────────────────────────────────────
class _BuyCardsButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BuyCardsButton({required this.onTap});
  @override
  Widget build(BuildContext context) => ZoomIn(
    child: Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF1C100), Color(0xFFFFD740)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _C.gold.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        backgroundColor: Colors.transparent,
        elevation: 0,
        hoverElevation: 0,
        focusElevation: 0,
        highlightElevation: 0,
        onPressed: onTap,
        label: Text(
          'BUY CARDS',
          style: _T.label(
              size: 13,
              color: const Color(0xFF3D2F00),
              spacing: 1.5,
              weight: FontWeight.w900),
        ),
        icon: const Icon(Icons.add_shopping_cart_rounded,
            color: Color(0xFF3D2F00), size: 18),
      ),
    ),
  );
}

// ─── Buy sheet ────────────────────────────────────────────────────────────────
class _BuySheet extends StatelessWidget {
  final GameLoaded state;
  final GameCubit gameCubit;
  const _BuySheet({required this.state, required this.gameCubit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 36),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: _C.divider),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle bar
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: _C.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Title
        Text(S.buyCartelas,
            style: _T.display.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _C.goldLight)),
        const SizedBox(height: 6),
        Text(
          'Max 25 cards per session — ${state.userCards.length} owned',
          style: _T.label(size: 11, color: _C.textLow, spacing: 0.3),
        ),

        const SizedBox(height: 24),

        // Card count grid
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [1, 2, 5, 10, 25].map((count) {
            final canBuy = (state.userCards.length + count) <= 25;
            return _CardCountChip(
              count: count,
              price: state.gamePrice,
              canBuy: canBuy,
              onTap: canBuy
                  ? () {
                      Navigator.pop(context);
                      gameCubit.buyCard(count: count);
                    }
                  : null,
            );
          }).toList(),
        ),

        const SizedBox(height: 8),
      ]),
    );
  }
}

class _CardCountChip extends StatelessWidget {
  final int count;
  final double price;
  final bool canBuy;
  final VoidCallback? onTap;
  const _CardCountChip({
    required this.count,
    required this.price,
    required this.canBuy,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = canBuy ? _C.gold : Colors.white.withOpacity(0.08);
    final bgColor = canBuy ? _C.goldFill : Colors.white.withOpacity(0.03);
    final numColor = canBuy ? _C.gold : _C.textLow;
    final textColor = canBuy ? _C.textHigh : _C.textLow;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 84,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: canBuy
              ? [BoxShadow(color: _C.gold.withOpacity(0.15), blurRadius: 10)]
              : [],
        ),
        child: Column(children: [
          Text(
            '$count',
            style: _T.number(size: 26, color: numColor),
          ),
          const SizedBox(height: 4),
          Text(
            count == 1 ? S.card : S.cards,
            style: _T.label(size: 9, color: textColor, spacing: 0.8),
          ),
          const SizedBox(height: 4),
          Text(
            '${(price * count).toInt()} ETB',
            style: _T.label(
                size: 10,
                color: canBuy ? _C.gold.withOpacity(0.7) : _C.textLow,
                spacing: 0.3),
          ),
        ]),
      ),
    );
  }
}