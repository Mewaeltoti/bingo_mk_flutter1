import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:confetti/confetti.dart';
import 'package:animate_do/animate_do.dart';

import '../blocs/game_cubit.dart';
import '../widgets/settings_drawer.dart';
import '../../core/theme/app_theme.dart';

import '../widgets/game/session_card_widget.dart';
import '../widgets/game/recent_numbers_widget.dart';
import '../widgets/game/live_board_widget.dart';
import '../widgets/game/cards_grid_widget.dart';
import '../widgets/game/horizontal_badge_list.dart';
import '../../domain/entities/bingo_card.dart';
import '../widgets/bingo_card_widget.dart';
import 'package:bingo_mk/presentation/widgets/loading_widgets.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late ConfettiController _confettiController;

  bool _expanded = true;
  bool _shownWinSnack = false;
  bool _shownDialog = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 10),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _showWinningCardDialog(BuildContext context, GameLoaded state) {
    if (state.winningCardNo == null || state.winningCardNumbers == null) return;

    final grid = List.generate(
      5,
      (i) => state.winningCardNumbers!.sublist(i * 5, (i + 1) * 5),
    );

    final mockCard = BingoCard(
      id: state.winningCardNo.toString(),
      sessionId: state.sessionId,
      cardNo: state.winningCardNo!,
      numbers: grid,
      price: state.gamePrice,
      status: 'registered',
    );

    final winningMarks = <String>{};
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < 5; c++) {
        if (state.drawnNumbers.contains(grid[r][c])) {
          winningMarks.add('$r-$c');
        }
      }
    }

    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: ZoomIn(
            duration: const Duration(milliseconds: 500),
            child: BingoCardWidget(
              card: mockCard,
              drawnNumbers: state.drawnNumbers.toSet(),
              markedCells: winningMarks,
              label: "WINNING CARD",
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameCubit, GameState>(
      listener: (context, state) {
        if (state is GameLoaded) {
          if (state.statusMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.statusMessage!),
                backgroundColor: state.statusMessage!.contains('Failed') 
                    ? AppColors.danger 
                    : AppColors.success,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 5),
              ),
            );
            context.read<GameCubit>().clearStatusMessage();
          }

          if (state.status == GameStatus.won) {
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
              _showWinningCardDialog(context, state);
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
              endDrawer: SettingsDrawer(onClose: () => Navigator.pop(context)),
              appBar: AppBar(
                flexibleSpace: Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.headerGradient,
                  ),
                ),
                title: FadeInDown(
                  child: Text(
                    state is GameLoaded ? "TOTI BINGO" : "Bingo Live",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                  ),
                ],
              ),
              body: state is GameLoaded
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          FadeInUp(
                            duration: const Duration(milliseconds: 500),
                            child: SessionCardWidget(state: state),
                          ),
                          
                          if (state.claimDeadline != null && state.status == GameStatus.paused)
                            _ClaimTimerWidget(deadline: state.claimDeadline!),

                          const SizedBox(height: 10),

                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
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
                          ),

                          if (_expanded) ...[
                            const SizedBox(height: 8),
                            FadeIn(child: LiveBoardWidget(drawnNumbers: state.drawnNumbers)),
                          ] else
                            RecentNumbersWidget(numbers: state.drawnNumbers),

                          const SizedBox(height: 16),

                          HorizontalBadgeList(
                            icon: Icons.check_circle,
                            color: AppColors.success,
                            label: "WINNERS:",
                            items: state.winners,
                          ),

                          HorizontalBadgeList(
                            icon: Icons.assignment_turned_in,
                            color: AppColors.secondary,
                            label: "CLAIMS:",
                            items: state.claimedCardIds,
                          ),

                          HorizontalBadgeList(
                            icon: Icons.block,
                            color: AppColors.danger,
                            label: "BLOCKED:",
                            items: state.blockedCardIds.toList(),
                          ),

                          const SizedBox(height: 16),

                          CardsGridWidget(
                            cards: state.userCards,
                            markedCells: state.markedCells,
                            blockedCards: state.blockedCardIds,
                            drawnNumbers: state.drawnNumbers,
                            status: state.status,
                            winningCardNo: state.winningCardNo,
                            claimDeadline: state.claimDeadline,
                          ),

                          const SizedBox(height: 100),
                        ],
                      ),
                    )
                  : const GamePageSkeleton(),
              floatingActionButton:
                  (state is GameLoaded && state.status == GameStatus.buying)
                  ? ZoomIn(
                      child: FloatingActionButton.extended(
                        backgroundColor: AppColors.secondary,
                        onPressed: () => context.read<GameCubit>().buyCard(),
                        label: const Text("BUY CARD", style: TextStyle(fontWeight: FontWeight.bold)),
                        icon: const Icon(Icons.add_shopping_cart),
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
                colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ClaimTimerWidget extends StatefulWidget {
  final DateTime deadline;
  const _ClaimTimerWidget({required this.deadline});

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
    setState(() {
      _secondsLeft = diff.clamp(0, 20);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_secondsLeft <= 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.danger.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer, color: AppColors.danger, size: 20),
          const SizedBox(width: 12),
          Text(
            "BINGO CLAIMED! ",
            style: TextStyle(color: AppColors.danger.withOpacity(0.8), fontWeight: FontWeight.bold),
          ),
          Text(
            "$_secondsLeft SECONDS LEFT",
            style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
