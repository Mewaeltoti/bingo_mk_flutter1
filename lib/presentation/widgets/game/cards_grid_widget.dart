import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../../domain/entities/bingo_card.dart';
import '../bingo_card_widget.dart';
import '../../blocs/game_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';

class CardsGridWidget extends StatelessWidget {
  final List<BingoCard> cards;
  final Map<String, Set<String>> markedCells;
  final Set<String> blockedCards;
  final List<int> drawnNumbers;
  final GameStatus status;
  final int? winningCardNo;
  final DateTime? claimDeadline;

  const CardsGridWidget({
    super.key,
    required this.cards,
    required this.markedCells,
    required this.blockedCards,
    required this.drawnNumbers,
    required this.status,
    this.winningCardNo,
    this.claimDeadline,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return FadeIn(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Column(
              children: [
                Icon(Icons.style_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.2)),
                const SizedBox(height: 16),
                const Text(
                  "NO CARDS PURCHASED",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Buy some cards during the buying phase!",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final drawnSet = Set<int>.from(drawnNumbers);

    final List<BingoCard> sortedCards = List.from(cards);
    if (status != GameStatus.buying) {
      sortedCards.sort((a, b) {
        final matchA = _getMatchCount(a, drawnSet);
        final matchB = _getMatchCount(b, drawnSet);
        if (matchA != matchB) {
          return matchB.compareTo(matchA);
        }
        return a.cardNo.compareTo(b.cardNo);
      });
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedCards.length,
      padding: const EdgeInsets.only(bottom: 40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.58,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (_, i) {
        final card = sortedCards[i];
        final isBlocked = blockedCards.contains(card.id);
        final isPending = card.status == 'pending';
        final isBuyingPhase = status == GameStatus.buying;
        final isUnregistered = (isPending && !isBuyingPhase) || status == GameStatus.waiting;

        return FadeInUp(
          duration: Duration(milliseconds: 300 + (i * 100).clamp(0, 500)),
          child: BingoCardWidget(
            card: card,
            drawnNumbers: drawnSet,
            markedCells: markedCells[card.id] ?? {},
            isBlocked: isBlocked,
            isUnregistered: isUnregistered,
            isWinner: winningCardNo != null && card.cardNo == winningCardNo,
            onMarkCell: (!isPending && !isBlocked)
                ? (r, c) => context.read<GameCubit>().markCell(card.id, r, c)
                : null,
            onRegister: (status == GameStatus.buying)
                ? () => context.read<GameCubit>().registerCard(card.id)
                : null,
            onBingoClaim: () => context.read<GameCubit>().claimBingo(card.id),
            onRemove: () => context.read<GameCubit>().removeCard(card.id),
            claimDeadline: (status == GameStatus.paused) ? claimDeadline : null,
          ),
        );
      },
    );
  }

  int _getMatchCount(BingoCard card, Set<int> drawnSet) {
    int count = 0;
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 5; c++) {
        if (r == 2 && c == 2) continue;
        if (drawnSet.contains(card.numbers[r][c])) {
          count++;
        }
      }
    }
    return count;
  }
}