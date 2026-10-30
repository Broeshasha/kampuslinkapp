import 'package:flutter_test/flutter_test.dart';
import 'package:kampuslink/features/profile/share_app.dart';

void main() {
  test('the share text has the intro, the Play link and the web link', () {
    final text = shareMessage('Join me!');
    expect(text, startsWith('Join me!'));
    expect(
      text,
      contains(
        'https://play.google.com/store/apps/details?id=com.kampuslink.kampuslink',
      ),
    );
    expect(text, contains('https://kampus-link.com'));
  });

  test('WhatsApp, Telegram, Facebook and SMS carry the links', () {
    final targets = shareTargets(shareMessage('Join me!'));
    expect(targets.map((t) => t.label), [
      'WhatsApp',
      'Telegram',
      'Facebook',
      'SMS',
    ]);
    final whatsapp = targets.first.uri.toString();
    expect(whatsapp, startsWith('https://wa.me/?text='));
    expect(Uri.decodeComponent(whatsapp), contains('kampus-link.com'));
  });
}
