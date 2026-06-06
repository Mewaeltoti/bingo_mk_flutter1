import 'package:shared_preferences/shared_preferences.dart';

/// Persists a set of favourite card numbers (cardNo integers) to
/// SharedPreferences so they survive app restarts.
///
/// Keys are per-user so favourites don't bleed across accounts.
/// Card numbers (not card IDs) are stored because a 'pending' card
/// keeps the same cardNo across sessions but gets a new Firestore ID
/// each time it is registered.
class FavouritesService {
  static const String _prefix = 'fav_cards_';

  /// Returns the favourited card numbers for [userId].
  Future<Set<int>> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('$_prefix$userId') ?? [];
    return raw.map((s) => int.tryParse(s)).whereType<int>().toSet();
  }

  /// Toggles [cardNo] in/out of the favourites list for [userId].
  /// Returns the updated set.
  Future<Set<int>> toggle(String userId, int cardNo) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix$userId';
    final current = (prefs.getStringList(key) ?? [])
        .map((s) => int.tryParse(s))
        .whereType<int>()
        .toSet();

    if (current.contains(cardNo)) {
      current.remove(cardNo);
    } else {
      current.add(cardNo);
    }

    await prefs.setStringList(key, current.map((n) => n.toString()).toList());
    return current;
  }
}
