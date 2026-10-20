import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';

const privacyPolicyUrl = String.fromEnvironment(
  'PRIVACY_POLICY_URL',
  defaultValue: 'https://mab.uz/privacy',
);
const termsOfUseUrl = String.fromEnvironment(
  'TERMS_URL',
  defaultValue: 'https://mab.uz/terms',
);
const publicOfferUrl = String.fromEnvironment(
  'OFFER_URL',
  defaultValue: 'https://mab.uz/offer',
);

/// The documents are edited in the admin panel in three languages; the page
/// picks one from `?lang=`, so the reader sees the app's language, not the
/// browser's.
Uri legalUri(String url, String languageCode) {
  final uri = Uri.parse(url);
  return uri.replace(
    queryParameters: {...uri.queryParameters, 'lang': languageCode},
  );
}

Future<void> openLegalLink(BuildContext context, String url) async {
  var opened = false;
  try {
    opened = await launchUrl(
      legalUri(url, Localizations.localeOf(context).languageCode),
    );
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
