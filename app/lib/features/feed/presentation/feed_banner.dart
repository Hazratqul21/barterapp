import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../../auth/data/auth_repository.dart';
import '../../trade/data/trade_repository.dart';

/// The strip above the feed.
///
/// It says the one thing this particular person is missing, and it goes away
/// when they have done it — not a rotating advert, and never more than one at a
/// time. A marketplace has exactly two things it needs from a newcomer: a
/// listing, so the matcher has something to work with, and enough trust that a
/// stranger will answer them. So there are two messages and they are ranked:
/// nothing to trade is a harder stop than a low trust score.
///
/// A dismissal is remembered for the session only. This is a nudge, not a
/// notification, and a nudge that survives restarts becomes nagging.
class FeedBanner extends ConsumerStatefulWidget {
  const FeedBanner({super.key});

  @override
  ConsumerState<FeedBanner> createState() => _FeedBannerState();
}

enum _Nudge { createListing, verify }

class _FeedBannerState extends ConsumerState<FeedBanner> {
  final _dismissed = <_Nudge>{};

  _Nudge? _pick(Me? me, int listingCount) {
    if (me == null) return null;
    if (listingCount == 0) return _Nudge.createListing;
    if (me.trustScore < 60) return _Nudge.verify;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).value;
    final mine = ref.watch(myListingsProvider).value;

    // Nothing until both answers are in, so the strip never appears and then
    // changes its mind a moment later.
    final nudge = (me == null || mine == null) ? null : _pick(me, mine.length);
    final show = nudge != null && !_dismissed.contains(nudge);

    // Collapse rather than vanish. Posting a first listing satisfies the nudge,
    // and the strip used to disappear between one frame and the next — the feed
    // jumped upward at the exact moment the person was looking for confirmation
    // that their listing had gone up.
    return AnimatedSize(
      duration: M3Motion.medium4,
      curve: M3Motion.emphasized,
      alignment: Alignment.topCenter,
      child: show
          ? _strip(context, nudge)
          : const SizedBox(width: double.infinity),
    );
  }

  Widget _strip(BuildContext context, _Nudge nudge) {
    final l = L.of(context);

    final (title, body, action, route, icon, bgImage) = switch (nudge) {
      _Nudge.createListing => (
        l.bannerCreateTitle,
        l.bannerCreateBody,
        l.bannerCreateAction,
        '/create',
        Symbols.add_box_rounded,
        'assets/images/banner_create_listing.png',
      ),
      _Nudge.verify => (
        l.bannerVerifyTitle,
        l.bannerVerifyBody,
        l.bannerVerifyAction,
        '/settings/verify',
        Symbols.verified_user_rounded,
        'assets/images/banner_verify_profile.png',
      ),
    };

    return _Strip(
      icon: icon,
      title: title,
      body: body,
      action: action,
      bgImage: bgImage,
      onAction: () => context.push(route),
      onDismiss: () => setState(() => _dismissed.add(nudge)),
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.bgImage,
    required this.onAction,
    required this.onDismiss,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final String bgImage;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);

    return Padding(
          padding: const EdgeInsets.fromLTRB(Gap.x5, Gap.x5, Gap.x5, 0),
          child: ClipRRect(
            borderRadius: Radii.rLg,
            child: Container(
              decoration: BoxDecoration(color: p.giveSoft),
              child: Stack(
                children: [
                  // The dynamic background image
                  Positioned.fill(
                    child: Image.asset(
                      bgImage,
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(Gap.x4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(Gap.x2),
                          decoration: BoxDecoration(
                            color: p.give,
                            borderRadius: Radii.rSm,
                          ),
                          child: Icon(
                            icon,
                            size: Sizes.iconLg,
                            color: Colors.white,
                          ),
                        ),
                        Gap.w3,
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              Gap.h1,
                              Text(
                                body,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: p.inkSoft,
                                ),
                              ),
                              Gap.h2,
                              FilledButton(
                                onPressed: onAction,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, Sizes.buttonSm),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Gap.x4,
                                  ),
                                ),
                                child: Text(action),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(
                          flex: 3,
                        ), // Keeps text away from the right-side 3D art
                      ],
                    ),
                  ),
                  Positioned(
                    top: Gap.x1,
                    right: Gap.x1,
                    child: IconButton(
                      tooltip: l.bannerDismiss,
                      onPressed: onDismiss,
                      icon: const Icon(
                        Symbols.close_rounded,
                        size: Sizes.iconMd,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.surface.withValues(
                          alpha: 0.5,
                        ),
                        foregroundColor: theme.colorScheme.onSurface,
                        minimumSize: const Size(32, 32),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: M3Motion.medium3)
        .slideY(
          begin: -0.15,
          end: 0,
          duration: M3Motion.medium4,
          curve: M3Motion.emphasizedDecelerate,
        );
  }
}
