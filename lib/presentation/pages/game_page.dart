import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:confetti/confetti.dart';

import '../blocs/game_cubit.dart';
import '../widgets/settings_drawer.dart';

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

  bool _expanded = true; // Default to expanded to show the board
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
        backgroundColor: Colors.transparent,
        child: BingoCardWidget(
          card: mockCard,
          drawnNumbers: state.drawnNumbers.toSet(),
          markedCells: winningMarks,
          label: "WINNING CARD",
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
              backgroundColor: const Color(0xFFF8FAFC),
              endDrawer: SettingsDrawer(onClose: () => Navigator.pop(context)),
              appBar: AppBar(
                flexibleSpace: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                ),
                title: Text(
                  state is GameLoaded ? "TOTI BINGO" : "Bingo Live",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                actions: [
                  IconButton(icon: const Icon(Icons.undo), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.redo), onPressed: () {}),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                  ),
                  IconButton(icon: const Icon(Icons.apps), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
                ],
              ),
              body: state is GameLoaded
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          // Session Info Card
                          SessionCardWidget(state: state),

                          const SizedBox(height: 10),

                          // Toggle Show More/Less (Styled as in image)
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
                                    color: const Color(0xFFEF4444),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _expanded ? "Show Less" : "Show More",
                                    style: const TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          if (_expanded) ...[
                            const SizedBox(height: 8),
                            LiveBoardWidget(drawnNumbers: state.drawnNumbers),
                          ] else
                            RecentNumbersWidget(numbers: state.drawnNumbers),

                          const SizedBox(height: 12),

                          // Horizontal Status Badges (Winners, Blocked, etc.)
                          HorizontalBadgeList(
                            icon: Icons.check_circle,
                            color: const Color(0xFF10B981),
                            label: "WINNERS:",
                            items: state.winners,
                          ),

                          HorizontalBadgeList(
                            icon: Icons.assignment_turned_in,
                            color: const Color(0xFFF59E0B),
                            label: "BINGO CLAIMED CARDS:",
                            items: state.claimedCardIds,
                          ),

                          HorizontalBadgeList(
                            icon: Icons.block,
                            color: const Color(0xFFEF4444),
                            label: "BLOCKED:",
                            items: state.blockedCardIds.toList(),
                            onShowMore: () {},
                          ),

                          const SizedBox(height: 12),

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
                      backgroundColor: const Color(0xFFEF4444),
                      onPressed: () => context.read<GameCubit>().buyCard(),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 30,
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
              ),
            ),
          ],
        );
      },
    );
  }
}
