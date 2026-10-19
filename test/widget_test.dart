import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/main.dart';

void main() {
  testWidgets('purged shell shows the KampusLink splash', (tester) async {
    await tester.pumpWidget(const KampusLinkApp());
    expect(find.text('KampusLink'), findsOneWidget);
  });
}
