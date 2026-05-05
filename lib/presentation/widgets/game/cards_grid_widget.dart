import 'package:flutter/material.dart';
import '../../../domain/entities/bingo_card.dart';
import '../bingo_card_widget.dart';
import '../../blocs/game_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CardsGridWidget extends StatelessWidget {
  final List<BingoCard> cards;
  final Map<String, Set<String>> markedCells;
  final Set<String> blockedCards;
  final List<int> drawnNumbers;
  final GameStatus status;
  final int? winningCardNo;

  const CardsGridWidget({
    super.key,
    required this.cards,
    required this.markedCells,
    required this.blockedCards,
    required this.drawnNumbers,
    required this.status,
    this.winningCardNo,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Text(
            "You don't have any cards for this game.\nBuy some during the buying phase!",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    final drawnSet = Set<int>.from(drawnNumbers);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      padding: const EdgeInsets.only(bottom: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.62,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (_, i) {
        final card = cards[i];
        final isBlocked = blockedCards.contains(card.id);
        final isPending = card.status == 'pending';
        final isBuyingPhase = status == GameStatus.buying;
        final isUnregistered = isPending && !isBuyingPhase;

        return BingoCardWidget(
          card: card,
          drawnNumbers: drawnSet,
          markedCells: markedCells[card.id] ?? {},
          isBlocked: isBlocked,
          isUnregistered: isUnregistered,
          isWinner: winningCardNo != null && card.cardNo == winningCardNo,
          // Tapping a cell only works during active game on a registered card
          onMarkCell: (!isPending && !isBlocked)
              ? (r, c) => context.read<GameCubit>().markCell(card.id, r, c)
              : null,
          onRegister: (isPending && isBuyingPhase)
              ? () => context.read<GameCubit>().registerCard(card.id)
              : null,
          // BINGO button appears only for active, non-blocked, registered cards, and drawing has started
          onBingoClaim: (!isPending && !isBlocked && drawnNumbers.isNotEmpty)
              ? () => context.read<GameCubit>().claimBingo(card.id)
              : null,
          // Remove button for pending cards
          onRemove: (isPending && isBuyingPhase)
              ? () => context.read<GameCubit>().removeCard(card.id)
              : null,
        );
      },
    );
  }
}