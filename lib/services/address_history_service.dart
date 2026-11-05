// address_history_service.dart
// Saves and loads the last N delivery addresses the user has used,
// persisted locally via shared_preferences.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/geo_models.dart';

class AddressHistoryService {
  static const _key      = 'address_history_v1';
  static const _maxItems = 5; // keep the 5 most-recent addresses

  // ── Load ──────────────────────────────────────────────────────────────────
  static Future<List<PickedAddress>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) {
      try {
        return PickedAddress.fromJson(
            jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    })
        .whereType<PickedAddress>()
        .toList();
  }

  // ── Save (prepend + dedupe + cap) ─────────────────────────────────────────
  static Future<void> add(PickedAddress address) async {
    if (address.isEmpty) return;

    final prefs   = await SharedPreferences.getInstance();
    final current = await load();

    // Remove any existing entry with the same address string (dedupe)
    final deduped = current
        .where((a) =>
    a.address.trim().toLowerCase() !=
        address.address.trim().toLowerCase())
        .toList();

    // Prepend the new entry and cap to _maxItems
    final updated = [address, ...deduped].take(_maxItems).toList();

    await prefs.setStringList(
      _key,
      updated.map((a) => jsonEncode(a.toJson())).toList(),
    );
  }

  // ── Clear all ─────────────────────────────────────────────────────────────
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}