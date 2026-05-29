import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:confetti/confetti.dart';
import 'package:animate_do/animate_do.dart';

import '../blocs/game_cubit.dart';
import '../blocs/wallet_cubit.dart';
import 'payment_page.dart';
import 'profile_page.dart';
import '../widgets/settings_drawer.dart';
import '../../core/theme/app_theme.dart';

import '../widgets/game/session_card_widget.dart';
import '../widgets/game/recent_numbers_widget.dart';
import '../widgets/game/live_board_widget.dart';
import '../widgets/game/cards_grid_widget.dart';
import '../widgets/game/horizontal_badge_list.dart';
import '../widgets/game/winning_card_dialog.dart';
import '../widgets/game/card_transparency_dialog.dart';
import '../../domain/entities/bingo_card.dart';
import '../widgets/bingo_card_widget.dart';
import 'package:bingo_mk/presentation/widgets/loading_widgets.dart';

class GamePage extends StatefulWidget {
  final Function(int index)? onTabChanged;

  const GamePage({super.key, this.onTabChanged});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late ConfettiController _confettiController;

  bool _expanded = true;
  bool _shownWinSnack = false;
  bool _shownDialog = false;
  bool _showBulkPanel = true;
  String? _lastShownStatusMessage;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 10),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-subscribe draws and refresh cards if streams were dropped.
      final cubit = context.read<GameCubit>();
      cubit.onAppResumed();
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
    return BlocConsumer<GameCubit, GameState>(
      listener: (context, state) {
        if (state is GameLoaded) {
          // Only show snackbars for broadcastMessage (admin-sent messages)
          // NOT for statusMessage (internal DB draw-loop field).
          // Removing clearStatusMessage() here stops the double-emit
          // that was preventing the UI board from updating every draw tick.
          final message = state.broadcastMessage;
          if (message != null && message.isNotEmpty) {
            if (message != _lastShownStatusMessage) {
              _lastShownStatusMessage = message;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor:
                        message.contains('Failed') ||
                            message.contains('Invalid')
                        ? AppColors.danger
                        : AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    duration: const Duration(seconds: 4),
                  ),
                );
              });
            }
          } else {
            _lastShownStatusMessage = null;
          }

          if (state.status == GameStatus.won && state.hasWon) {
            _confettiController.play();
            if (state.hasWon && !_shownWinSnack) {
              _shownWinSnack = true;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🎉 YOU WON!'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 5),
                ),
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
              backgroundColor: AppColors.darkBackground,
              endDrawer: MultiBlocProvider(
                providers: [
                  BlocProvider.value(value: context.read<WalletCubit>()),
                  BlocProvider.value(value: context.read<GameCubit>()),
                ],
                child: SettingsDrawer(onClose: () => Navigator.pop(context)),
              ),
              appBar: AppBar(
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Material(
                    color: Colors.white.withOpacity(0.08),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        if (widget.onTabChanged != null) {
                          widget.onTabChanged!(2); // Switch to Profile tab
                        } else {
                          final walletCubit = BlocProvider.of<WalletCubit>(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BlocProvider.value(
                                value: walletCubit,
                                child: const ProfilePage(),
                              ),
                            ),
                          );
                        }
                      },
                      child: const Center(
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                flexibleSpace: Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.headerGradient,
                  ),
                ),
                title: BlocBuilder<WalletCubit, WalletState>(
                  builder: (context, walletState) {
                    double balance = 0;
                    if (walletState is WalletLoaded) {
                      balance = walletState.balance;
                    }
                    return FadeInDown(
                      child: InkWell(
                        onTap: () {
                          if (widget.onTabChanged != null) {
                            widget.onTabChanged!(1); // Switch to Wallet tab
                          } else {
                            final walletCubit = BlocProvider.of<WalletCubit>(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BlocProvider.value(
                                  value: walletCubit,
                                  child: const PaymentPage(),
                                ),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.secondary.withOpacity(0.35), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.secondary.withOpacity(0.08),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.account_balance_wallet, color: AppColors.secondary, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                "${balance.toStringAsFixed(2)} ETB",
                                style: const TextStyle(
                                  fontFamily: 'Orbitron',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                  ),
                ],
              ),
              body: state is GameLoaded
                  ? RefreshIndicator(
                      onRefresh: () async {
                        await context.read<GameCubit>().refreshCards();
                      },
                      color: AppColors.primary,
                      backgroundColor: AppColors.darkCard,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            if (_expanded)
                              FadeInUp(
                                duration: const Duration(milliseconds: 500),
                                child: SessionCardWidget(state: state),
                              ),

                            if (state.claimDeadline != null &&
                                state.status == GameStatus.paused)
                              _ClaimTimerWidget(deadline: state.claimDeadline!),

                            const SizedBox(height: 10),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Auto Daub Toggle on the left
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.brightness_auto,
                                      color: AppColors.secondary,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "AUTO-DAUB",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: () {
                                        context.read<GameCubit>().toggleAutoDaub(!state.isAutoDaubEnabled);
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        width: 42,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          color: state.isAutoDaubEnabled
                                              ? AppColors.secondary.withOpacity(0.18)
                                              : Colors.white.withOpacity(0.06),
                                          border: Border.all(
                                            color: state.isAutoDaubEnabled
                                                ? AppColors.secondary
                                                : Colors.white24,
                                            width: 1.2,
                                          ),
                                          boxShadow: state.isAutoDaubEnabled
                                              ? [
                                                  BoxShadow(
                                                    color: AppColors.secondary.withOpacity(0.2),
                                                    blurRadius: 6,
                                                    spreadRadius: 0.5,
                                                  )
                                                ]
                                              : [],
                                        ),
                                        child: AnimatedAlign(
                                          duration: const Duration(milliseconds: 180),
                                          alignment: state.isAutoDaubEnabled
                                              ? Alignment.centerRight
                                              : Alignment.centerLeft,
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: state.isAutoDaubEnabled
                                                  ? AppColors.secondary
                                                  : Colors.white54,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // Show Less/More Toggle on the right
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _expanded = !_expanded),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _expanded
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                        color: AppColors.secondary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _expanded ? "Show Less" : "Show More",
                                        style: const TextStyle(
                                          color: AppColors.secondary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            if (_expanded) ...[
                              const SizedBox(height: 8),
                              LiveBoardWidget(
                                drawnNumbers: state.drawnNumbers,
                              ),
                            ] else ...[
                              const SizedBox(height: 8),
                              RecentNumbersWidget(numbers: state.drawnNumbers),
                            ],

                            const SizedBox(height: 16),

                            if (state.status != GameStatus.buying &&
                                state.winners.isNotEmpty)
                              HorizontalBadgeList(
                                icon: Icons.check_circle,
                                color: AppColors.success,
                                label: "WINNERS:",
                                items: state.winners,
                                onItemTap: (item) => showCardTransparencyDialog(
                                  context,
                                  item,
                                  state,
                                  isWinner: true,
                                ),
                              ),

                            if (state.pendingClaims.isNotEmpty)
                              HorizontalBadgeList(
                                icon: Icons.hourglass_empty,
                                color: AppColors.warning,
                                label: "PENDING:",
                                items: state.pendingClaims,
                                onItemTap: (item) => showCardTransparencyDialog(
                                  context,
                                  item,
                                  state,
                                  isWinner: false,
                                ),
                              ),

                            HorizontalBadgeList(
                              icon: Icons.assignment_turned_in,
                              color: AppColors.secondary,
                              label: "CLAIMS:",
                              items: state.claimedCardIds,
                              onItemTap: (item) => showCardTransparencyDialog(
                                context,
                                item,
                                state,
                                isWinner: false,
                              ),
                            ),

                            HorizontalBadgeList(
                              icon: Icons.block,
                              color: AppColors.danger,
                              label: "BLOCKED:",
                              items: state.blockedCardIds.toList(),
                              onItemTap: (item) => showCardTransparencyDialog(
                                context,
                                item,
                                state,
                                isBlocked: true,
                              ),
                            ),

                            CardsGridWidget(
                              cards: state.userCards,
                              markedCells: state.markedCells,
                              blockedCards: state.blockedCardIds,
                              drawnNumbers: state.drawnNumbers,
                              status: state.status,
                              winningCardNo: state.status == GameStatus.buying ? null : state.winningCardNo,
                              claimDeadline: state.claimDeadline,
                              claimedCardIds: state.claimedCardIds,
                            ),

                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    )
                  : const GamePageSkeleton(),
              floatingActionButton:
                  (state is GameLoaded && state.status == GameStatus.buying)
                  ? ZoomIn(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.secondary, Color(0xFFFF9800)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.secondary.withOpacity(0.35),
                              blurRadius: 15,
                              spreadRadius: 1.5,
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
                          onPressed: () =>
                              _showBuyCartelaBottomSheet(context, state),
                          label: const Text(
                            "BUY CARDS",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              fontFamily: 'Orbitron',
                              letterSpacing: 1.1,
                              fontSize: 13,
                            ),
                          ),
                          icon: const Icon(
                            Icons.add_shopping_cart,
                            color: Colors.black,
                            size: 18,
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                ],
              ),
            ),
            // Paused overlay has been removed to avoid blocking the user's screen.
            // The claim countdown is rendered elegantly on the SessionCardWidget instead.
          ],
        );
      },
    );
  }

  Widget _buildPausedOverlay(GameLoaded state) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          color: Colors.black45,
          child: Center(
            child: FadeInDown(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.darkCard,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: AppColors.secondary.withOpacity(0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary.withOpacity(0.2),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.pause_circle_filled,
                          color: AppColors.secondary,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "GAME PAUSED",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "VERIFYING BINGO CLAIMS",
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (state.claimDeadline != null)
                          _ClaimTimerWidget(
                            deadline: state.claimDeadline!,
                            isOverlay: true,
                          ),
                        const SizedBox(height: 16),
                        Text(
                          state.statusMessage ?? "Waiting for other players...",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showBuyCartelaBottomSheet(BuildContext context, GameLoaded state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                "BUY CARTELAS",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "You can own a maximum of 25 cards per session.",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [1, 2, 5, 10, 25].map((count) {
                  final canBuy = (state.userCards.length + count) <= 25;
                  return InkWell(
                    onTap: canBuy
                        ? () {
                            Navigator.pop(ctx);
                            context.read<GameCubit>().buyCard(count: count);
                          }
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 80,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: canBuy
                            ? AppColors.secondary.withOpacity(0.1)
                            : Colors.white.withOpacity(0.02),
                        border: Border.all(
                          color: canBuy ? AppColors.secondary : Colors.white10,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "$count",
                            style: TextStyle(
                              color: canBuy
                                  ? AppColors.secondary
                                  : Colors.white38,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Orbitron',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            count == 1 ? "CARD" : "CARDS",
                            style: TextStyle(
                              color: canBuy ? Colors.white : Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }


}

class _ClaimTimerWidget extends StatefulWidget {
  final DateTime deadline;
  final bool isOverlay;
  const _ClaimTimerWidget({required this.deadline, this.isOverlay = false});

  @override
  State<_ClaimTimerWidget> createState() => _ClaimTimerWidgetState();
}

class _ClaimTimerWidgetState extends State<_ClaimTimerWidget> {
  late Timer _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    final diff = widget.deadline.difference(now).inSeconds;
    if (mounted) {
      setState(() {
        _secondsLeft = diff.clamp(0, 30); // Increased limit to 30 for safety
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_secondsLeft <= 0 && !widget.isOverlay) return const SizedBox.shrink();

    final color = _secondsLeft > 5 ? AppColors.secondary : AppColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                "$_secondsLeft",
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 32,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "SECONDS",
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (widget.isOverlay)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "UNTIL CLAIM WINDOW CLOSES",
                style: TextStyle(
                  color: color.withOpacity(0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}