// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bingo_mk/main.dart';
import 'package:bingo_mk/data/repositories/auth_repository_impl.dart';
import 'package:bingo_mk/data/repositories/bingo_repository_impl.dart';

void main() {
  testWidgets('Smoke test for BingoApp', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    final authRepository = AuthRepositoryImpl();
    final bingoRepository = BingoRepositoryImpl();

    await tester.pumpWidget(BingoApp(
      authRepository: authRepository,
      bingoRepository: bingoRepository,
    ));

    // Basic assertion to ensure app renders
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
