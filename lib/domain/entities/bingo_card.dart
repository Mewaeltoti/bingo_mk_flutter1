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
      case BingoPattern.fullHouse: return 'Full House';
      case BingoPattern.singleLineH: return 'Single Line H';
      case BingoPattern.singleLineV: return 'Single Line V';
      case BingoPattern.singleLineD: return 'Single Line D';
      case BingoPattern.twoLines: return 'Two Lines';
      case BingoPattern.fourCorners: return 'Four Corners';
      case BingoPattern.xShape: return 'X Shape';
      case BingoPattern.tShape: return 'T Shape';
      case BingoPattern.lShape: return 'L Shape';
      case BingoPattern.cross: return 'Cross';
      case BingoPattern.frame: return 'Frame';
      case BingoPattern.postageStamp: return 'Postage Stamp';
      case BingoPattern.smallDiamond: return 'Small Diamond';
      case BingoPattern.arrowUp: return 'Arrow Up';
      case BingoPattern.pyramid: return 'Pyramid';
      case BingoPattern.uShape: return 'U Shape';
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

  BingoCard({
    required this.id,
    required this.numbers,
    required this.price,
  });
}
