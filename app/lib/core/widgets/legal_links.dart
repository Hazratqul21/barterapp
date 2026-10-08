import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';

const privacyPolicyUrl = String.fromEnvironment(
  'PRIVACY_POLICY_URL',
  defaultValue: 'https://barterapp.uz/privacy',
);
const termsOfUseUrl = String.fromEnvironment(
  'TERMS_URL',
  defaultValue: 'https://barterapp.uz/terms',
);

Future<void> openLegalLink(BuildContext context, String url) async {
  var opened = false;
  try {
    opened = await launchUrl(Uri.parse(url));
  } catch (_) {
    // Keep the user in the app with actionable feedback if no browser exists.
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(L.of(context).errorGeneric)));
  }
}

class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        TextButton(
          onPressed: () => openLegalLink(context, privacyPolicyUrl),
          child: Text(l.legalPrivacy),
        ),
        TextButton(
          onPressed: () => openLegalLink(context, termsOfUseUrl),
          child: Text(l.legalTerms),
        ),
      ],
    );
  }
}
