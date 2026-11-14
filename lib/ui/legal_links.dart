import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../l10n/app_localizations.dart';

const privacyUrl = 'https://site.kampus-link.com/privacy';
const termsUrl = 'https://site.kampus-link.com/terms';

Future<void> openLegalPage(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// "By continuing, you accept..." + Terms / Privacy buttons (sign-in step).
class LegalLinksLine extends StatelessWidget {
  const LegalLinksLine({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final small = Theme.of(context).textTheme.bodySmall;
    return Column(
      children: [
        Text(
          l10n.legalAgree,
          textAlign: TextAlign.center,
          style: small?.copyWith(color: kc.textSecondary),
        ),
        const SizedBox(height: KSpace.xs),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: KSpace.sm,
          children: [
            TextButton(
              onPressed: () => openLegalPage(termsUrl),
              child: Text(l10n.legalTerms),
            ),
            TextButton(
              onPressed: () => openLegalPage(privacyUrl),
              child: Text(l10n.legalPrivacy),
            ),
          ],
        ),
      ],
    );
  }
}
