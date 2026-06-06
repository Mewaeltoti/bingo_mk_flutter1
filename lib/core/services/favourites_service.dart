import 'package:shared_preferences/shared_preferences.dart';

/// Persists the set of favourite card IDs (Firestore document IDs) to
/// SharedPreferences so they survive app restarts.
///
/// Keys are per-user so favourites don't bleed across accounts.
/// Card IDs are used (not cardNos) because pending cards don't have a
/// cardNo assigned until they are registered — the Firestore ID is stable
/// from the moment the card is created.
class FavouritesService {
  static const String _prefix = 'fav_cards_';

  /// Returns the favourited card IDs for [userId].
  Future<Set<String>> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('$_prefix$userId') ?? []).toSet();
  }

  /// Toggles [cardId] in/out of the favourites list for [userId].
  /// Returns the updated set.
  Future<Set<String>> toggle(String userId, String cardId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix$userId';
    final current = (prefs.getStringList(key) ?? []).toSet();

    if (current.contains(cardId)) {
      current.remove(cardId);
    } else {
      current.add(cardId);
    }

    await prefs.setStringList(key, current.toList());
    return current;
  }
}
