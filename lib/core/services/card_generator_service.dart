import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import '../../domain/entities/bingo_card.dart';
import 'logger_service.dart';

class CardGeneratorService {
  List<Map<String, dynamic>>? _cachedCards;

  Future<List<Map<String, dynamic>>> loadLocalCards() async {
    if (_cachedCards != null) return _cachedCards!;
    try {
      final String response = await rootBundle.loadString('assets/data.json');
      final List<dynamic> decoded = json.decode(response);
      _cachedCards = decoded.cast<Map<String, dynamic>>();
      return _cachedCards!;
    } catch (e) {
      Log.e("Error loading local cards: $e");
      return [];
    }
  }

  Future<List<BingoCard>> generateCards({
    required int count,
    required Set<int> existingCardNos,
    required double gamePrice,
    required String sessionId,
  }) async {
    final allCards = await loadLocalCards();
    if (allCards.isEmpty) {
      throw Exception("Local card database (data.json) is empty or could not be loaded.");
    }

    final availableCards = allCards.where((c) => !existingCardNos.contains(c['cartela_no'] as int)).toList();

    if (availableCards.isEmpty) {
      throw Exception("No more unique cards available to purchase.");
    }

    final random = Random();
    final List<BingoCard> newCards = [];

    for (int i = 0; i < count; i++) {
      if (availableCards.isEmpty) break;
      final randomIndex = random.nextInt(availableCards.length);
      final cardData = availableCards.removeAt(randomIndex);
      
      final cardId = cardData['cartela_no'].toString();
      final originalNumbers = List<int>.from(cardData['bingo_numbers']);
      final numbers25 = [...originalNumbers];

      if (numbers25.length == 24) {
        numbers25.insert(12, 0); // Standard free middle space at index 12
      }

      // Convert flat 25 numbers array to 5x5 matrix
      final List<List<int>> matrix = [];
      for (var r = 0; r < 5; r++) {
        matrix.add(numbers25.sublist(r * 5, (r + 1) * 5));
      }

      newCards.add(BingoCard(
        id: cardId,
        cardNo: int.parse(cardId),
        numbers: matrix,
        price: gamePrice,
        status: 'pending',
        sessionId: sessionId,
        createdAt: DateTime.now(),
      ));
    }

    return newCards;
  }
}
