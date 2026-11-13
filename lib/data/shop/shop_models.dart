import 'package:flutter/painting.dart' show Color;

Map<String, dynamic> asMap(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};
List<Object?> asList(Object? v) => v is List ? v : const <Object?>[];
int asInt(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

/// "#RRGGBB" -> Color; null when the text is not a colour.
Color? parseHexColor(Object? v) {
  if (v is! String) return null;
  final hex = v.trim().replaceFirst('#', '');
  if (hex.length != 6) return null;
  final n = int.tryParse(hex, radix: 16);
  return n == null ? null : Color(0xFF000000 | n);
}

class InventoryItem {
  const InventoryItem({
    required this.itemId,
    required this.kind,
    required this.equipped,
    this.payload = const <String, dynamic>{},
  });

  final String itemId;
  final String kind;
  final bool equipped;

  /// The look of the item (colours, style...), straight from the shop row.
  final Map<String, dynamic> payload;
}

/// get_wallet(): everything is decided by the server; the phone only shows it.
class Wallet {
  const Wallet({
    this.balance = 0,
    this.maxFreezes = 0,
    this.streak = 0,
    this.bestStreak = 0,
    this.freezes = 0,
    this.streakProtected = false,
    this.studiedToday = false,
    this.freezeUsedToday = false,
    this.inventory = const <InventoryItem>[],
  });

  factory Wallet.fromMap(Map<String, dynamic> m) {
    final s = asMap(m['streak']);
    return Wallet(
      balance: asInt(m['balance']),
      maxFreezes: asInt(m['max_freezes']),
      streak: asInt(s['current']),
      bestStreak: asInt(s['best']),
      freezes: asInt(s['freezes']),
      streakProtected: s['protected'] == true,
      studiedToday: s['studied_today'] == true,
      freezeUsedToday: s['freeze_used_today'] == true,
      inventory: [
        for (final e in asList(m['inventory']))
          if (e is Map)
            InventoryItem(
              itemId: '${e['item_id']}',
              kind: '${e['kind']}',
              equipped: e['equipped'] == true,
              payload: asMap(e['payload']),
            ),
      ],
    );
  }

  /// Spendable XP: lifetime XP minus what the shop took.
  final int balance, maxFreezes;
  final int streak, bestStreak, freezes;
  final bool streakProtected, studiedToday, freezeUsedToday;
  final List<InventoryItem> inventory;

  bool owns(String itemId) => inventory.any((i) => i.itemId == itemId);
  bool isEquipped(String itemId) =>
      inventory.any((i) => i.itemId == itemId && i.equipped);

  /// The payload of the equipped item of [kind] (null = none equipped).
  Map<String, dynamic>? equippedPayload(String kind) {
    for (final i in inventory) {
      if (i.kind == kind && i.equipped) return i.payload;
    }
    return null;
  }

  String? equippedOfKind(String kind) {
    for (final i in inventory) {
      if (i.kind == kind && i.equipped) return i.itemId;
    }
    return null;
  }
}

/// One row of kl_shop_items.
class ShopItem {
  const ShopItem({
    required this.id,
    required this.kind,
    required this.price,
    required this.name,
    required this.desc,
    required this.payload,
    required this.sort,
  });

  factory ShopItem.fromMap(Map<String, dynamic> m) => ShopItem(
    id: '${m['id']}',
    kind: '${m['kind']}',
    price: asInt(m['price']),
    name: m['name_i18n'],
    desc: m['desc_i18n'],
    payload: asMap(m['payload']),
    sort: asInt(m['sort']),
  );

  final String id;
  final String kind;
  final int price;
  final Object? name;
  final Object? desc;
  final Map<String, dynamic> payload;
  final int sort;

  bool get isFreeze => kind == 'streak_freeze';
}
