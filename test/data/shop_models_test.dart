import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/data/shop/shop_models.dart';
import 'package:kampuslink/data/sync/sync_results.dart';

void main() {
  test('wallet reads the server answer (XP balance, streak, items)', () {
    final w = Wallet.fromMap({
      'balance': 120,
      'xp_total': 620,
      'xp_spent': 500,
      'max_freezes': 2,
      'streak': {'current': 4, 'best': 9, 'freezes': 1, 'protected': true},
      'inventory': [
        {'item_id': 'theme_night', 'kind': 'theme', 'equipped': true},
      ],
    });
    expect(w.balance, 120);
    expect(w.streak, 4);
    expect(w.freezes, 1);
    expect(w.streakProtected, isTrue);
    expect(w.owns('theme_night'), isTrue);
    expect(w.equippedOfKind('theme'), 'theme_night');
    expect(w.owns('theme_forest'), isFalse);
  });

  test('colours: only #RRGGBB', () {
    expect(parseHexColor('#3B5BDB')?.toARGB32(), 0xFF3B5BDB);
    expect(parseHexColor('3B5BDB')?.toARGB32(), 0xFF3B5BDB);
    expect(parseHexColor('#FFF'), isNull);
    expect(parseHexColor(42), isNull);
  });

  test('sync results bus answers the op that was asked for', () async {
    final bus = SyncResultsBus();
    final waiter = bus.waitFor('op-1');
    bus.publish([
      {'op_id': 'other', 'status': 'applied'},
      {'op_id': 'op-1', 'status': 'applied'},
    ]);
    final r = await waiter;
    expect(r?['status'], 'applied');
    final none = await bus.waitFor(
      'op-2',
      timeout: const Duration(milliseconds: 50),
    );
    expect(none, isNull);
    bus.dispose();
  });
}
