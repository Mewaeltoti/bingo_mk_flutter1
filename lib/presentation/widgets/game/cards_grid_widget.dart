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
  final List<String> claimedCardIds;

  const CardsGridWidget({
    super.key,
    required this.cards,
    required this.markedCells,
    required this.blockedCards,
    required this.drawnNumbers,
    required this.status,
    this.winningCardNo,
    this.claimDeadline,
    this.claimedCardIds = const [],
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
        // BUG FIX: check isBlocked by BOTH blockedCards set (in-memory) AND
        // card.isBlocked (persisted flag from Firestore). Previously only
        // blockedCards set was checked, so freshly-loaded blocked cards
        // (where isBlocked=true in DB but not yet in the Set) were not blocked.
        final isBlocked = blockedCards.contains(card.id) || card.isBlocked;
        final isPending = card.status == 'pending';
        final isBuyingPhase = status == GameStatus.buying;
        final isUnregistered = (isPending && !isBuyingPhase) || status == GameStatus.waiting;
        final isAlreadyClaimed = claimedCardIds.contains(card.id);
        // BUG FIX: a card is a winner if its cardNo matches winningCardNo.
        // Previously this was also passed to CardsGridWidget from game_page,
        // but winningCardNo was null during 'active' status — now it correctly
        // shows WINNER badge as soon as the won state arrives.
        final isWinner = winningCardNo != null && card.cardNo == winningCardNo;

        final cardWidget = BingoCardWidget(
          key: ValueKey('card_${card.id}'),
          card: card,
          drawnNumbers: drawnSet,
          markedCells: markedCells[card.id] ?? {},
          isBlocked: isBlocked,
          isUnregistered: isUnregistered,
          isWinner: isWinner,
          isAlreadyClaimed: isAlreadyClaimed,
          onMarkCell: (!isPending && !isBlocked && !isWinner)
              ? (r, c) => context.read<GameCubit>().markCell(card.id, r, c)
              : null,
          onRegister: (status == GameStatus.buying && !isBlocked)
              ? () => context.read<GameCubit>().registerCard(card.id)
              : null,
          // BUG FIX: blocked and winner cards must NOT get an onBingoClaim
          // callback. Previously blocked cards still received the callback,
          // which meant the BINGO button could still fire claimBingo() on them
          // despite the visual opacity suggesting they were disabled.
          onBingoClaim: (isBlocked || isWinner || isAlreadyClaimed)
              ? null
              : () => context.read<GameCubit>().claimBingo(card.id),
          onRemove: () => context.read<GameCubit>().removeCard(card.id),
          claimDeadline: (status == GameStatus.paused) ? claimDeadline : null,
        );

        if (status == GameStatus.buying) {
          return FadeInUp(
            key: ValueKey('anim_${card.id}'),
            duration: Duration(milliseconds: 300 + (i * 100).clamp(0, 500)),
            child: cardWidget,
          );
        }

        return cardWidget;
      },
    );
  }
}