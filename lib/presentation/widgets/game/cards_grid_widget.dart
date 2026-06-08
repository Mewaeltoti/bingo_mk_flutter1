import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../../domain/entities/bingo_card.dart';
import '../bingo_card_widget.dart';
import '../../blocs/game_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import 'package:bingo_mk/presentation/blocs/settings_cubit.dart';

class CardsGridWidget extends StatelessWidget {
  final List<BingoCard> cards;
  final Map<String, Set<String>> markedCells;
  final Set<String> blockedCards;
  final List<int> drawnNumbers;
  final GameStatus status;
  final int? winningCardNo;
  final DateTime? claimDeadline;
  final List<String> claimedCardIds;
  /// Card IDs the user has starred as lucky/favourite.
  /// During the buying phase these cards float to the top of the grid.
  final List<String> favouriteCardIds;

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
    this.favouriteCardIds = const [],
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
                Icon(Icons.style_outlined, size: 64, color: (SettingsCubit.isLightModeGlobal ? const Color(0xFF667085) : AppColors.textSecondary).withOpacity(0.3)),
                const SizedBox(height: 16),
                Text(
                  "NO CARDS PURCHASED",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: SettingsCubit.isLightModeGlobal ? const Color(0xFF475467) : AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Buy some cards during the buying phase!",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SettingsCubit.isLightModeGlobal ? const Color(0xFF475467) : AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final drawnSet = Set<int>.from(drawnNumbers);

    // During the buying phase, favourite cards float to the top so the user
    // can tap "Register" on their lucky card before others grab it.
    // In all other phases the order stays stable (server order).
    final List<BingoCard> sortedCards = List.from(cards);
    if (status == GameStatus.buying && favouriteCardIds.isNotEmpty) {
      sortedCards.sort((a, b) {
        final aFav = favouriteCardIds.contains(a.id) ? 0 : 1;
        final bFav = favouriteCardIds.contains(b.id) ? 0 : 1;
        return aFav.compareTo(bFav);
      });
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedCards.length,
      padding: const EdgeInsets.only(bottom: 40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.62,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (_, i) {
        final card = sortedCards[i];
        final isBlocked = blockedCards.contains(card.id) || card.isBlocked;
        final isPending = card.status == 'pending';
        final isBuyingPhase = status == GameStatus.buying;
        final isUnregistered = (isPending && !isBuyingPhase) || status == GameStatus.waiting;
        final isAlreadyClaimed = claimedCardIds.contains(card.id);
        final isFavourite = favouriteCardIds.contains(card.id);
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
          isFavourite: isFavourite,
          // Star is always shown — pending cards have no cardNo yet but the
          // user still wants to mark their lucky card before registering it.
          onToggleFavourite: () => context.read<GameCubit>().toggleFavourite(card.id),
          onMarkCell: (!isPending && !isBlocked && !isWinner)
              ? (r, c) => context.read<GameCubit>().markCell(card.id, r, c)
              : null,
          onRegister: (status == GameStatus.buying && !isBlocked)
              ? () => context.read<GameCubit>().registerCard(card.id)
              : null,
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