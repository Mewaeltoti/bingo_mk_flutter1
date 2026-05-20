import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../../domain/entities/bingo_card.dart';
import '../../blocs/game_cubit.dart';
import '../bingo_card_widget.dart';

void showWinningCardDialog(BuildContext context, GameLoaded state) {
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
