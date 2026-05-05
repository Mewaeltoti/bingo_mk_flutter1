import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:confetti/confetti.dart';

import '../blocs/game_cubit.dart';
import '../widgets/settings_drawer.dart';

import '../widgets/game/session_card_widget.dart';
import '../widgets/game/recent_numbers_widget.dart';
import '../widgets/game/live_board_widget.dart';
import '../widgets/game/cards_grid_widget.dart';
import '../../domain/entities/bingo_card.dart';
import '../widgets/bingo_card_widget.dart';
import '../widgets/loading_widgets.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late ConfettiController _confettiController;

  bool _expanded = false;
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
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFF5252),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.credit_card, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        "Card: ${state.winningCardNo}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (state.drawnNumbers.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        "Last: ${state.drawnNumbers.last}",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: BingoCardWidget(
                card: mockCard,
                drawnNumbers: state.drawnNumbers.toSet(),
                markedCells: winningMarks,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameCubit, GameState>(
      listener: (context, state) {
        if (state is GameLoaded) {
          if (state.status == GameStatus.won) {
            _confettiController.play();

            if (state.hasWon && !_shownWinSnack) {
              _shownWinSnack = true;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🎉 YOU WON!'),
                  backgroundColor: Colors.green,
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
              backgroundColor: const Color(0xFFF0F2F5),
              endDrawer: SettingsDrawer(onClose: () => Navigator.pop(context)),

              appBar: AppBar(
                flexibleSpace: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E88E5), Color(0xFF8E24AA)],
                    ),
                  ),
                ),
                title: const Text("Bingo Live"),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                  ),
                ],
              ),

              body: state is GameLoaded
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          // WIN BANNER
                          if (state.status == GameStatus.won)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: state.hasWon
                                    ? Colors.green
                                    : Colors.grey,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    state.hasWon ? "YOU WON!" : "GAME OVER",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  if (state.winners.isNotEmpty)
                                    Wrap(
                                      spacing: 6,
                                      children: state.winners
                                          .map(
                                            (e) =>
                                                Chip(label: Text(e.toString())),
                                          )
                                          .toList(),
                                    ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 10),

                          // TOGGLE
                          GestureDetector(
                            onTap: () => setState(() => _expanded = !_expanded),
                            child: Text(_expanded ? "Show Less" : "Show More"),
                          ),

                          const SizedBox(height: 10),

                          if (_expanded) ...[
                            SessionCardWidget(state: state),
                            const SizedBox(height: 10),
                            LiveBoardWidget(drawnNumbers: state.drawnNumbers),
                          ] else
                            RecentNumbersWidget(numbers: state.drawnNumbers),

                          const SizedBox(height: 10),

                          CardsGridWidget(
                            cards: state.userCards,
                            markedCells: state.markedCells,
                            blockedCards: state.blockedCardIds,
                            drawnNumbers: state.drawnNumbers,
                            status: state.status,
                            winningCardNo: state.winningCardNo,
                          ),

                          const SizedBox(height: 100),
                        ],
                      ),
                    )
                  : const GamePageSkeleton(),

              floatingActionButton:
                  (state is GameLoaded && state.status == GameStatus.buying)
                  ? FloatingActionButton(
                      onPressed: () => context.read<GameCubit>().buyCard(),
                      child: const Icon(Icons.add),
                    )
                  : null,
            ),

            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false, // ✅ FIXED
              ),
            ),
          ],
        );
      },
    );
  }
}
