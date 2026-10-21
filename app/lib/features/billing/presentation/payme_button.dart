import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/haptics.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../data/billing_repository.dart';

const paymeTeal = BrandColors.paymeTeal;

/// "[payme] orqali to‘lash" — the logo is the brand, the words are ours, and
/// their order follows the language (Uzbek puts the verb after).
class PaymeButton extends StatelessWidget {
  const PaymeButton({super.key, required this.onPressed, this.busy = false});

  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final style = Theme.of(context).textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: BrandColors.paymeInk,
    );
    final logo = Image.asset(
      'assets/brand/payme.png',
      height: 22,
      semanticLabel: 'Payme',
      filterQuality: FilterQuality.medium,
    );
    return Semantics(
      container: true,
      button: true,
      label: [
        l.billingPayBefore,
        'Payme',
        l.billingPayAfter,
      ].where((s) => s.isNotEmpty).join(' '),
      excludeSemantics: true,
      child: OutlinedButton(
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          minimumSize: const Size.fromHeight(Sizes.buttonLg),
          side: const BorderSide(color: paymeTeal, width: 1.5),
          shape: const RoundedRectangleBorder(borderRadius: Radii.rMd),
        ),
        child: busy
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: paymeTeal,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (l.billingPayBefore.isNotEmpty) ...[
                    Flexible(child: Text(l.billingPayBefore, style: style)),
                    Gap.w2,
                  ],
                  logo,
                  if (l.billingPayAfter.isNotEmpty) ...[
                    Gap.w2,
                    Flexible(child: Text(l.billingPayAfter, style: style)),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Opens the Payme page in the browser — card details go there, never into
/// the app.
Future<bool> openCheckout(String url) async {
  final uri = Uri.tryParse(url);
  // Only Payme's own pages. The link comes from our server, but a wrong
  // setting there must not turn the pay button into a redirect to anywhere.
  if (uri == null || uri.scheme != 'https' || !paymeHosts.contains(uri.host)) {
    return false;
  }
  return launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_self',
  );
}

const paymeHosts = {'checkout.paycom.uz', 'test.paycom.uz'};

/// The browser hand-off, as a provider so tests can stand in for it.
final checkoutLauncherProvider = Provider<Future<bool> Function(String url)>(
  (ref) => openCheckout,
);

/// Creates the order, hands the person to Payme and opens the screen that
/// waits for the result. One function so every entry point — plans, boost,
/// the quota wall — pays the same way.
Future<void> startPayment(
  BuildContext context,
  WidgetRef ref, {
  required Tariff tariff,
  String? listingId,
}) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  Haptics.light();
  try {
    final order = await ref
        .read(billingRepositoryProvider)
        .createOrder(tariff.code, listingId: listingId);
    final url = order.checkoutUrl;
    if (url == null) {
      messenger.showSnackBar(SnackBar(content: Text(l.billingUnavailable)));
      return;
    }
    // The waiting screen goes up first: on the web `_self` leaves the app,
    // and Payme brings the person back to /payments/return.
    router.push('/payments/order/${order.id}');
    if (!await ref.read(checkoutLauncherProvider)(url)) {
      messenger.showSnackBar(SnackBar(content: Text(l.billingOpenFailed)));
    }
  } on ApiException catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(e.statusCode == 503 ? l.billingUnavailable : e.message),
      ),
    );
  } catch (e) {
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(context, e))));
    }
  }
}
