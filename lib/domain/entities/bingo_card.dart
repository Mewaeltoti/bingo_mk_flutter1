enum BingoPattern {
  fullHouse,
  singleLineH,
  singleLineV,
  singleLineD,
  twoLines,
  fourCorners,
  xShape,
  tShape,
  lShape,
  cross,
  frame,
  postageStamp,
  smallDiamond,
  arrowUp,
  pyramid,
  uShape,
}

extension BingoPatternExtension on BingoPattern {
  String get name {
    switch (this) {
      case BingoPattern.fullHouse: return 'ሙሉ ካርቴላ';
      case BingoPattern.singleLineH: return 'ኣግዳሚ መስመር';
      case BingoPattern.singleLineV: return 'ነበርቲ መስመር';
      case BingoPattern.singleLineD: return 'ዳያጎናል መስመር';
      case BingoPattern.twoLines: return 'ክልተ መስመራት';
      case BingoPattern.fourCorners: return 'ኣርባዕተ ጫፋት';
      case BingoPattern.xShape: return 'ቅርጽ X';
      case BingoPattern.tShape: return 'ቅርጽ T';
      case BingoPattern.lShape: return 'ቅርጽ L';
      case BingoPattern.cross: return 'መስቀል';
      case BingoPattern.frame: return 'ፍሬም';
      case BingoPattern.postageStamp: return 'ስታምፕ 2x2';
      case BingoPattern.smallDiamond: return 'ንኡሽ ዳይመንድ';
      case BingoPattern.arrowUp: return 'ላዕሊ ዝወጽእ ቀስት';
      case BingoPattern.pyramid: return 'ፒራሚድ';
      case BingoPattern.uShape: return 'ቅርጽ U';
    }
  }

  String get description {
    switch (this) {
      case BingoPattern.fullHouse: return 'All numbers marked';
      case BingoPattern.singleLineH: return 'Any horizontal line';
      case BingoPattern.singleLineV: return 'Any vertical line';
      case BingoPattern.singleLineD: return 'Any diagonal line';
      case BingoPattern.twoLines: return 'Any two complete lines';
      case BingoPattern.fourCorners: return 'All four corner cells';
      case BingoPattern.xShape: return 'Both diagonals';
      case BingoPattern.tShape: return 'First row + middle column';
      case BingoPattern.lShape: return 'First column + last row';
      case BingoPattern.cross: return 'Middle row + middle column';
      case BingoPattern.frame: return 'All border cells';
      case BingoPattern.postageStamp: return 'Any 2x2 corner block';
      case BingoPattern.smallDiamond: return 'Diamond in center';
      case BingoPattern.arrowUp: return 'Arrow pointing up';
      case BingoPattern.pyramid: return 'Triangle from top center';
      case BingoPattern.uShape: return 'First col + last col + last row';
    }
  }
}

class BingoCard {
  final String id;
  final List<List<int>> numbers;
  final double price;
  final String status; // 'pending' or 'registered'
  final int cardNo;
  final String sessionId;
  final DateTime? createdAt;
  final bool isBlocked;

  BingoCard({
    required this.id,
    required this.numbers,
    required this.price,
    this.status = 'registered',
    this.cardNo = 0,
    this.sessionId = '',
    this.createdAt,
    this.isBlocked = false,
  });

  BingoCard copyWith({
    String? id,
    List<List<int>>? numbers,
    double? price,
    String? status,
    int? cardNo,
    String? sessionId,
    DateTime? createdAt,
    bool? isBlocked,
  }) {
    return BingoCard(
      id: id ?? this.id,
      numbers: numbers ?? this.numbers,
      price: price ?? this.price,
      status: status ?? this.status,
      cardNo: cardNo ?? this.cardNo,
      sessionId: sessionId ?? this.sessionId,
      createdAt: createdAt ?? this.createdAt,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }
}