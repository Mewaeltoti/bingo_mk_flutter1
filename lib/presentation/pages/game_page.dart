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
import '../../domain/entities/bingo_card.dart';
import '../widgets/bingo_card_widget.dart';
import 'package:bingo_mk/presentation/widgets/loading_widgets.dart';

class GamePage extends StatefulWidget {
  final Function(int index)? onTabChanged;

  const GamePage({super.key, this.onTabChanged});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
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
          if (state.statusMessage != null && state.statusMessage!.isNotEmpty) {
            final message = state.statusMessage!;
            final isGenericLoopMsg =
                message.contains('drawn') ||
                message.contains('Waiting') ||
                message.contains('resumed') ||
                message.contains('Playing') ||
                message.contains('Verification');

            if (message != _lastShownStatusMessage && !isGenericLoopMsg) {
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
            context.read<GameCubit>().clearStatusMessage();
          } else {
            // Reset tracker if server message is cleared
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
              endDrawer: BlocProvider.value(
                value: context.read<WalletCubit>(),
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
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.12)),
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
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          FadeInUp(
                            duration: const Duration(milliseconds: 500),
                            child: SessionCardWidget(state: state),
                          ),

                          if (state.claimDeadline != null &&
                              state.status == GameStatus.paused)
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
                            FadeIn(
                              child: LiveBoardWidget(
                                drawnNumbers: state.drawnNumbers,
                              ),
                            ),
                          ] else
                            RecentNumbersWidget(numbers: state.drawnNumbers),

                          const SizedBox(height: 16),

                          if (state.status != GameStatus.buying &&
                              state.winners.isNotEmpty)
                            HorizontalBadgeList(
                              icon: Icons.check_circle,
                              color: AppColors.success,
                              label: "WINNERS:",
                              items: state.winners,
                              onItemTap: (item) => _showCardTransparencyDialog(
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
                              onItemTap: (item) => _showCardTransparencyDialog(
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
                            onItemTap: (item) => _showCardTransparencyDialog(
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
                            onItemTap: (item) => _showCardTransparencyDialog(
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
                        onPressed: () =>
                            _showBuyCartelaBottomSheet(context, state),
                        label: const Text(
                          "BUY CARDS",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        icon: const Icon(
                          Icons.add_shopping_cart,
                          color: Colors.black,
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

  void _showCardTransparencyDialog(
    BuildContext context,
    String item,
    GameLoaded state, {
    bool isWinner = false,
    bool isBlocked = false,
  }) {
    Map<String, dynamic>? found;
    List<int> numbersList = [];
    String cardNo = item;
    String phone = "ስልክ ቁጥር: 0910117997";

    if (isBlocked) {
      final userCard = state.userCards.firstWhere(
        (c) => c.id == item || c.cardNo.toString() == item,
        orElse: () => BingoCard(
          id: '',
          cardNo: int.tryParse(item) ?? 0,
          numbers: [],
          price: 10,
        ),
      );
      if (userCard.id.isNotEmpty) {
        numbersList = userCard.numbers.expand((row) => row).toList();
        cardNo = userCard.cardNo.toString();
        phone = "የእርስዎ የታገደ ካርቴላ";
      }
    } else {
      final searchList = isWinner ? state.rawWinnersData : state.rawClaimsData;
      for (var c in searchList) {
        if (c['cardNo']?.toString() == item || c['cardId'] == item) {
          found = c;
          break;
        }
      }
      if (found == null) {
        final altList = isWinner ? state.rawClaimsData : state.rawWinnersData;
        for (var c in altList) {
          if (c['cardNo']?.toString() == item || c['cardId'] == item) {
            found = c;
            break;
          }
        }
      }

      if (found != null) {
        cardNo = (found['cardNo'] ?? item).toString();
        final rawPhone = found['phone'] ?? '';
        phone = rawPhone.toString().isNotEmpty
            ? "ስልክ ቁጥር: $rawPhone"
            : "ስልክ ቁጥር: 0910117997";

        final rawNumbers = found['numbers'];
        if (rawNumbers is List) {
          for (var x in rawNumbers) {
            if (x is List) {
              numbersList.addAll(x.map((e) => int.tryParse(e.toString()) ?? 0));
            } else {
              numbersList.add(int.tryParse(x.toString()) ?? 0);
            }
          }
        }
      }
    }

    if (numbersList.length < 25) {
      final seed = int.tryParse(cardNo) ?? 12345;
      numbersList = List.generate(25, (index) {
        if (index == 12) return 0; // Center free space placeholder
        return ((seed + index) % 75) + 1;
      });
    }

    Set<String> markedCellSet = {};
    if (isBlocked) {
      markedCellSet =
          state.markedCells[cardNo] ?? state.markedCells[item] ?? {};
    } else if (found != null && found['markedCells'] != null) {
      markedCellSet = Set<String>.from(found['markedCells']);
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) {
        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 25,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFE63946), Color(0xFFD62828)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.credit_card,
                              color: Colors.white,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "ካርቴላ: $cardNo",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(
                      top: 16,
                      left: 16,
                      right: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildBingoLetterBlock("B", AppColors.accent),
                        _buildBingoLetterBlock("I", AppColors.danger),
                        _buildBingoLetterBlock("N", AppColors.success),
                        _buildBingoLetterBlock("G", const Color(0xFF8B5CF6)),
                        _buildBingoLetterBlock("O", AppColors.secondary),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: 25,
                      itemBuilder: (context, index) {
                        final row = index ~/ 5;
                        final col = index % 5;

                        if (row == 2 && col == 2) {
                          return Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.success.withOpacity(0.2),
                              border: Border.all(
                                color: AppColors.success,
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              "FREE",
                              style: TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          );
                        }

                        final numVal = numbersList[index];
                        final isUserMarked = markedCellSet.contains(
                          '$row-$col',
                        );

                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isUserMarked
                                ? AppColors.danger
                                : Colors.white.withOpacity(0.05),
                            border: Border.all(
                              color: isUserMarked
                                  ? AppColors.danger
                                  : Colors.white10,
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "$numVal",
                            style: TextStyle(
                              color: isUserMarked
                                  ? Colors.white
                                  : Colors.white70,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: SizedBox(
                      width: 120,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white10,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Colors.white24),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          "ዕድሉ",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBingoLetterBlock(String letter, Color color) {
    return Container(
      width: 44,
      height: 34,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 16,
          decoration: TextDecoration.none,
        ),
      ),
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
