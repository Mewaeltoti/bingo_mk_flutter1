import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/bingo_card.dart';
import '../../blocs/game_cubit.dart';

void showCardTransparencyDialog(
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
      phone = "Blocked card";
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
    markedCellSet = state.markedCells[cardNo] ?? state.markedCells[item] ?? {};
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
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                      final isUserMarked = markedCellSet.contains('$row-$col');

                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isUserMarked ? AppColors.danger : Colors.white.withOpacity(0.05),
                          border: Border.all(
                            color: isUserMarked ? AppColors.danger : Colors.white10,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "$numVal",
                          style: TextStyle(
                            color: isUserMarked ? Colors.white : Colors.white70,
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
                        "Back",
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
