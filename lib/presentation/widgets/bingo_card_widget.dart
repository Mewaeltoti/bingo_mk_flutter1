import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/bingo_card.dart';
import '../../core/theme/app_theme.dart';
import 'package:bingo_mk/core/l10n/app_strings.dart';
import 'package:bingo_mk/presentation/blocs/settings_cubit.dart';

class BingoCardWidget extends StatelessWidget {
  final BingoCard card;
  final Set<int> drawnNumbers;
  final Set<String> markedCells;
  final Function(int row, int col)? onMarkCell;
  final VoidCallback? onRegister;
  final VoidCallback? onRemove;
  final VoidCallback? onBingoClaim;
  final bool isBlocked;
  final bool isUnregistered;
  final String? label;
  final bool selected;
  final int? lastDrawn;
  final bool isWinner;
  final DateTime? claimDeadline;
  final bool isAlreadyClaimed;

  const BingoCardWidget({
    super.key,
    required this.card,
    this.drawnNumbers = const {},
    this.markedCells = const {},
    this.onMarkCell,
    this.onRegister,
    this.onRemove,
    this.onBingoClaim,
    this.isBlocked = false,
    this.isUnregistered = false,
    this.label,
    this.selected = false,
    this.lastDrawn,
    this.isWinner = false,
    this.claimDeadline,
    this.isAlreadyClaimed = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool validGrid =
        card.numbers.length == 5 &&
        card.numbers.every((row) => row.length == 5);
    if (!validGrid) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.danger),
        ),
        child: Text(
          S.invalidCardData,
          style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double cellSize = (availableWidth - (12 * 2) - (4 * 4)) / 5;

        // BUG FIX: isCardDisabled now correctly includes isBlocked and isWinner
        // so the entire card interaction is gated — not just the visual opacity.
        final bool isCardDisabled = isBlocked || isWinner || isAlreadyClaimed || card.status == 'claiming';

        String? badgeText;
        Color badgeColor = AppColors.accent;

        if (isBlocked) {
          badgeText = "BLOCKED";
          badgeColor = AppColors.danger;
        } else if (isWinner) {
          badgeText = "WINNER!";
          badgeColor = AppColors.success;
        } else if (isAlreadyClaimed) {
          badgeText = "CLAIMED";
          badgeColor = AppColors.accent;
        } else if (card.status == 'claiming') {
          badgeText = "CLAIMING";
          badgeColor = AppColors.secondary;
        } else if (isUnregistered) {
          badgeText = "PENDING";
          badgeColor = AppColors.danger;
        } else if (label != null) {
          badgeText = label;
        }

        return FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: availableWidth,
            child: Stack(
              children: [
                Opacity(
                  opacity: isCardDisabled ? 0.6 : 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: SettingsCubit.isLightModeGlobal ? const Color(0xFFFFFFFF) : AppColors.darkCard,
                      borderRadius: BorderRadius.circular(20),
                      // BUG FIX: blocked cards get a red border so the user
                      // immediately sees why the card is inactive.
                      border: Border.all(
                        color: isBlocked
                            ? AppColors.danger.withOpacity(0.5)
                            : isWinner
                                ? AppColors.success.withOpacity(0.5)
                                : SettingsCubit.isLightModeGlobal ? const Color(0xFFE4E7EC) : Colors.white10,
                        width: (isBlocked || isWinner) ? 1.5 : 1.0,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: SettingsCubit.isLightModeGlobal ? const Color(0x18000000) : Colors.black45,
                          blurRadius: 15,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: Row(
                            children: [
                              Text(
                                "CARD #${card.cardNo}",
                                style: const TextStyle(
                                  color: SettingsCubit.isLightModeGlobal ? const Color(0xFF667085) : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (badgeText != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isWinner
                                        ? const Color(0xFFF1C100)
                                        : badgeColor,
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: isWinner
                                        ? [BoxShadow(color: const Color(0xFFF1C100).withOpacity(0.6), blurRadius: 10, spreadRadius: 1)]
                                        : [],
                                  ),
                                  child: Text(
                                    isWinner ? '🏆 WINNER!' : badgeText.toUpperCase(),
                                    style: TextStyle(
                                      color: isWinner ? Colors.black : Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (onRemove != null)
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: Icon(Icons.cancel, size: 16, color: SettingsCubit.isLightModeGlobal ? const Color(0xFF667085) : Colors.white70),
                                  onPressed: onRemove,
                                ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Column(
                            children: [
                              _buildHeader(cellSize),
                              const SizedBox(height: 2),
                              _buildGrid(cellSize),
                            ],
                          ),
                        ),

                        // BUG FIX: show a clear BLOCKED banner instead of a
                        // misleading BINGO button when the card is blocked.
                        // Previously isBlocked was only handled via opacity —
                        // the button was still tappable and could fire claimBingo().
                        if (isBlocked)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                            child: SizedBox(
                              width: double.infinity,
                              height: 32,
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.danger.withOpacity(0.4),
                                  ),
                                ),
                                child: const Text(
                                  "INVALID CLAIM — BLOCKED",
                                  style: TextStyle(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Builder(
                            builder: (context) {
                              final now = DateTime.now();
                              final bool isExpired =
                                  claimDeadline != null && now.isAfter(claimDeadline!);
                              final bool isRegistered =
                                  card.status.toLowerCase().contains('reg') && !isUnregistered;
                              final bool canClaim =
                                  isRegistered &&
                                  drawnNumbers.isNotEmpty &&
                                  !isExpired &&
                                  !isAlreadyClaimed &&
                                  !isWinner &&
                                  onBingoClaim != null;

                              return Padding(
                                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 32,
                                  child: ElevatedButton(
                                    // BUG FIX: onPressed is null for winner/claimed cards
                                    // so Flutter marks the button as truly disabled —
                                    // not just visually grey but actually non-tappable.
                                    onPressed: isWinner || isAlreadyClaimed
                                        ? null
                                        : () {
                                            if (!isRegistered) {
                                              if (onRegister != null) {
                                                onRegister!();
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(S.buyingPhaseOnly),
                                                    behavior: SnackBarBehavior.floating,
                                                  ),
                                                );
                                              }
                                              return;
                                            }

                                            if (canClaim) {
                                              onBingoClaim!();
                                            } else {
                                              String msg = S.notStartedYet;
                                              if (isExpired) {
                                                msg = "Bingo claim window has closed.";
                                              } else if (drawnNumbers.isEmpty) {
                                                msg = "Wait for the first number to be drawn!";
                                              }
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(msg),
                                                  behavior: SnackBarBehavior.floating,
                                                  duration: const Duration(seconds: 3),
                                                ),
                                              );
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isWinner
                                          ? AppColors.success.withOpacity(0.3)
                                          : isAlreadyClaimed
                                              ? AppColors.accent.withOpacity(0.4)
                                              : isRegistered
                                                  ? (canClaim
                                                      ? AppColors.success
                                                      : Colors.grey.withOpacity(0.2))
                                                  : (onRegister == null
                                                      ? Colors.grey.withOpacity(0.5)
                                                      : AppColors.secondary),
                                      foregroundColor: isRegistered ? Colors.white : Colors.black,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: canClaim || !isRegistered ? 3 : 0,
                                    ),
                                    child: Text(
                                      !isRegistered
                                          ? "ACTIVATE"
                                          : isWinner
                                              ? "WINNER!"
                                              : isAlreadyClaimed
                                                  ? "CLAIMED"
                                                  : (isExpired ? "CLOSED" : "BINGO"),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: isRegistered ? 12 : 10,
                                        letterSpacing: isRegistered ? 1.2 : 0.6,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(double cellSize) {
    const letters = ['B', 'I', 'N', 'G', 'O'];
    final colors = [
      AppColors.accent,
      AppColors.danger,
      AppColors.success,
      const Color(0xFF8B5CF6),
      AppColors.secondary,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(5, (i) {
        return Container(
          width: cellSize,
          height: cellSize * 0.6,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors[i].withOpacity(0.06),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colors[i].withOpacity(0.3), width: 1.0),
          ),
          child: Text(
            letters[i],
            style: TextStyle(
              color: colors[i],
              fontWeight: FontWeight.w900,
              fontSize: cellSize * 0.35,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildGrid(double cellSize) {
    return Column(
      children: List.generate(5, (row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (col) {
            final number = card.numbers[row][col];
            final isFree = row == 2 && col == 2;
            final isMarked = isFree || markedCells.contains('$row-$col');

            final bool _lm = SettingsCubit.isLightModeGlobal;
            Color bgColor = _lm ? const Color(0xFFF0F2F5) : Colors.white.withOpacity(0.04);
            Color textColor = _lm ? const Color(0xFF344054) : Colors.white70;
            Color borderColor = _lm ? const Color(0xFFD0D5DD) : Colors.white.withOpacity(0.05);

            if (isFree) {
              bgColor = AppColors.danger.withOpacity(0.9);
              textColor = Colors.white;
              borderColor = AppColors.danger;
            } else if (isWinner && drawnNumbers.contains(number)) {
              bgColor = const Color(0xFFF1C100);
              textColor = Colors.black;
              borderColor = const Color(0xFFF1C100);
            } else if (isMarked) {
              bgColor = AppColors.danger;
              textColor = Colors.white;
              borderColor = AppColors.danger;
            }

            return GestureDetector(
              onTap: () {
                if (!isFree && onMarkCell != null) {
                  HapticFeedback.mediumImpact();
                  onMarkCell!(row, col);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: cellSize,
                height: cellSize,
                margin: const EdgeInsets.symmetric(vertical: 2.0),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: bgColor,
                  border: Border.all(color: borderColor, width: 1.0),
                  boxShadow: [
                    if (isMarked && !isFree)
                      BoxShadow(
                        color: bgColor.withOpacity(0.3),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                  ],
                ),
                child: Text(
                  isFree ? '★' : '$number',
                  style: TextStyle(
                    fontSize: cellSize * 0.40,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}