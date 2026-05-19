import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/bingo_card.dart';
import '../../core/theme/app_theme.dart';

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
        child: const Text(
          'Invalid Bingo Card Data',
          style: TextStyle(
            color: AppColors.danger,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double cellSize = (availableWidth - (12 * 2) - (4 * 4)) / 5;
        final bool isCardDisabled = isBlocked || isWinner || card.status == 'claiming';

        // Pre-calculate status badge parameters inline to save vertical space
        String? badgeText;
        Color badgeColor = AppColors.accent;

        if (isBlocked) {
          badgeText = "BLOCKED";
          badgeColor = AppColors.danger;
        } else if (isWinner) {
          badgeText = "WINNER!";
          badgeColor = AppColors.success;
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
                      color: AppColors.darkCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 15,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Ultra Compact Transparent Top Bar
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              Text(
                                "CARD #${card.cardNo}",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (badgeText != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badgeColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    badgeText.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (onRemove != null)
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(
                                    Icons.cancel,
                                    size: 16,
                                    color: Colors.white70,
                                  ),
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

                        // Actions at the bottom
                        if (!isBlocked)
                          Builder(
                            builder: (context) {
                              final now = DateTime.now();
                              final bool isExpired =
                                  claimDeadline != null &&
                                  now.isAfter(claimDeadline!);
                              final bool isRegistered =
                                  card.status.toLowerCase().contains('reg') &&
                                  !isUnregistered;
                              final bool canClaim =
                                  isRegistered &&
                                  drawnNumbers.isNotEmpty &&
                                  !isExpired;

                              return Padding(
                                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 32,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (!isRegistered) {
                                        if (onRegister != null) {
                                          onRegister!();
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                "Registration is only allowed during the Buying Phase!",
                                              ),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                        return;
                                      }

                                      if (canClaim) {
                                        onBingoClaim!();
                                      } else {
                                        String msg =
                                            "Game hasn't started drawing numbers yet!";
                                        if (isExpired) {
                                          msg = "Bingo claim window has closed.";
                                        } else if (drawnNumbers.isEmpty)
                                          msg =
                                              "Wait for the first number to be drawn!";

                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(msg),
                                            behavior: SnackBarBehavior.floating,
                                            duration: const Duration(seconds: 5),
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isRegistered
                                          ? (canClaim
                                                ? AppColors.success
                                                : Colors.grey.withOpacity(0.2))
                                          : (onRegister == null
                                                ? Colors.grey.withOpacity(0.5)
                                                : AppColors.secondary),
                                      foregroundColor: isRegistered
                                          ? Colors.white
                                          : Colors.black,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: canClaim || !isRegistered ? 3 : 0,
                                    ),
                                    child: Text(
                                      !isRegistered
                                          ? "ACTIVATE"
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

  Widget _buildActionButton(String text, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: color == AppColors.secondary
              ? Colors.black
              : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          elevation: 4,
        ),
        child: Text(text, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _buildOverlay(String text, Color bgColor, Color labelColor) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: labelColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: labelColor.withOpacity(0.5), blurRadius: 20),
              ],
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
        ),
      ),
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
          height: cellSize * 0.8,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors[i].withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors[i].withOpacity(0.5), width: 1.5),
          ),
          child: Text(
            letters[i],
            style: TextStyle(
              color: colors[i],
              fontWeight: FontWeight.w900,
              fontSize: cellSize * 0.5,
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

            Color bgColor = Colors.white.withOpacity(0.05);
            Color textColor = Colors.white70;
            Color borderColor = Colors.white10;

            if (isFree) {
              bgColor = AppColors.success.withOpacity(0.2);
              textColor = AppColors.success;
              borderColor = AppColors.success;
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
                duration: const Duration(milliseconds: 250),
                width: cellSize,
                height: cellSize,
                margin: const EdgeInsets.symmetric(vertical: 1.5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bgColor,
                  border: Border.all(color: borderColor, width: 1.5),
                  boxShadow: [
                    if (isMarked && !isFree)
                      BoxShadow(
                        color: bgColor.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                  ],
                ),
                child: Text(
                  isFree ? 'F' : '$number',
                  style: TextStyle(
                    fontSize: cellSize * 0.45,
                    fontWeight: FontWeight.bold,
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
