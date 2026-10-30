import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';

/// The Play link never changes (open testing -> production keeps it).
/// The referrer shows in Play Console how many installs came from shares.
const playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.kampuslink.kampuslink'
    '&referrer=utm_source%3Dapp_share';
const webUrl = 'https://kampus-link.com';

/// The text sent: the intro in the app language and both links.
String shareMessage(String intro) =>
    '$intro\n\nAndroid: $playStoreUrl\nWeb: $webUrl';

/// Where the student can share (no extra package: url_launcher only).
List<({String label, IconData icon, Uri uri})> shareTargets(String text) => [
  (
    label: 'WhatsApp',
    icon: Icons.chat_rounded,
    uri: Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'),
  ),
  (
    label: 'Telegram',
    icon: Icons.send_rounded,
    uri: Uri.parse(
      'https://t.me/share/url?url=${Uri.encodeComponent(playStoreUrl)}'
      '&text=${Uri.encodeComponent(text)}',
    ),
  ),
  (
    label: 'Facebook',
    icon: Icons.facebook_rounded,
    uri: Uri.parse(
      'https://www.facebook.com/sharer/sharer.php'
      '?u=${Uri.encodeComponent(webUrl)}',
    ),
  ),
  (
    label: 'SMS',
    icon: Icons.sms_outlined,
    uri: Uri.parse('sms:?body=${Uri.encodeComponent(text)}'),
  ),
];

/// Profile row: a small menu (WhatsApp, Telegram, Facebook, SMS, copy).
class ShareAppTile extends StatelessWidget {
  const ShareAppTile({super.key});

  Future<void> _open(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final text = shareMessage(l10n.shareMessage);
    final messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in shareTargets(text))
              ListTile(
                leading: Icon(t.icon),
                title: Text(t.label),
                onTap: () async {
                  Navigator.of(sheet).pop();
                  await launchUrl(t.uri, mode: LaunchMode.externalApplication);
                },
              ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: Text(l10n.shareCopy),
              onTap: () async {
                Navigator.of(sheet).pop();
                await Clipboard.setData(ClipboardData(text: text));
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.shareCopied)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.share_outlined),
      title: Text(l10n.shareApp),
      subtitle: Text(l10n.shareAppHint),
      onTap: () => _open(context),
    );
  }
}
