import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/models.dart';
import '../../features/auth/presentation/sign_in_page.dart';
import '../../features/feed/presentation/feed_page.dart';
import '../../features/listing/presentation/listing_detail_page.dart';
import '../../features/onboarding/presentation/intro_page.dart';
import '../../features/onboarding/presentation/splash_page.dart';
import '../../features/profile/presentation/payments_page.dart';
import '../../features/profile/presentation/profile_edit_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/profile/presentation/settings_page.dart';
import '../../features/profile/presentation/verification_page.dart';
import '../../features/profile/presentation/favorites_page.dart';
import '../../features/profile/presentation/notification_settings_page.dart';
import '../../features/profile/presentation/blocked_users_page.dart';
import '../../features/trade/presentation/chat_page.dart';
import '../../features/trade/presentation/create_listing_page.dart';
import '../../features/trade/presentation/inbox_page.dart';
import '../../features/trade/presentation/matches_page.dart';
import '../../features/trade/presentation/notifications_page.dart';
import '../../features/trade/presentation/offer_page.dart';
import '../../features/trade/presentation/trader_profile_page.dart';
import '../design/design_catalog_page.dart';
import 'app_shell.dart';
import 'transitions.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Routes mirror the URLs the web build exposes, so a listing link can be
/// pasted into a browser and a phone and land in the same place.
///
/// Tab screens live inside the shell; everything else is pushed on top of it,
/// which is what makes "back" return to wherever the user actually came from.
GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    errorPageBuilder: (context, state) => MaterialPage(
      key: state.pageKey,
      child: Scaffold(
        appBar: AppBar(title: const Text('404')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.explore_off_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'Sahifa topilmadi',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                state.uri.toString(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => GoRouter.of(context).go('/'),
                child: const Text('Bosh sahifaga'),
              ),
            ],
          ),
        ),
      ),
    ),
    routes: [
      // Outside the shell: no tab bar should be visible while the app is still
      // deciding where the person belongs.
      GoRoute(
        path: '/',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) =>
            fadePage(key: state.pageKey, child: const SplashPage()),
      ),
      GoRoute(
        path: '/intro',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) =>
            fadePage(key: state.pageKey, child: const IntroPage()),
      ),
      // The profile and every signed-out prompt push here. The route was
      // missing entirely, so "Kirish" landed on go_router's error page.
      // Design tokens catalog — debug builds only, never in a release.
      if (kDebugMode)
        GoRoute(
          path: '/dev/design',
          parentNavigatorKey: _rootKey,
          pageBuilder: (context, state) =>
              forwardPage(key: state.pageKey, child: const DesignCatalogPage()),
        ),
      GoRoute(
        path: '/signin',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) =>
            risingPage(key: state.pageKey, child: const SignInPage()),
      ),
      StatefulShellRoute(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        navigatorContainerBuilder: (context, navigationShell, children) {
          // Provide children to the AppShell or just manage it here?
          // Since AppShell expects just `navigationShell`, we actually don't need
          // to manage the children here if we just want `AppShell` to receive
          // the animated child. But wait, `AppShell` takes `navigationShell`.
          // We can just create an AnimatedBranchContainer here.
          return AnimatedBranchContainer(
            currentIndex: navigationShell.currentIndex,
            children: children,
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const FeedPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/matches',
                builder: (context, state) => const MatchesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inbox',
                builder: (context, state) => const InboxPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      // Reached from the profile, pushed over the tabs — see the note in
      // `app_shell.dart` for why it is not a destination of its own.
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) =>
            forwardPage(key: state.pageKey, child: const SettingsPage()),
      ),
      GoRoute(
        path: '/listing/:id',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => heroPage(
          key: state.pageKey,
          child: ListingDetailPage(listingId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/chat/:id',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => forwardPage(
          key: state.pageKey,
          child: ChatPage(conversationId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/offer/:listingId',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => risingPage(
          key: state.pageKey,
          child: OfferPage(listingId: state.pathParameters['listingId']!),
        ),
      ),
      GoRoute(
        path: '/trader/:id',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => forwardPage(
          key: state.pageKey,
          child: TraderProfilePage(traderId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/create',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => risingPage(
          key: state.pageKey,
          child: CreateListingPage(
            listingToEdit: state.extra as ListingDetail?,
          ),
        ),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) =>
            forwardPage(key: state.pageKey, child: const NotificationsPage()),
      ),
      GoRoute(
        path: '/settings/verify',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) =>
            forwardPage(key: state.pageKey, child: const VerificationPage()),
      ),
      GoRoute(
        path: '/settings/payments',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) =>
            forwardPage(key: state.pageKey, child: const PaymentsPage()),
      ),
      GoRoute(
        path: '/settings/blocks',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) =>
            forwardPage(key: state.pageKey, child: const BlockedUsersPage()),
      ),
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => risingPage(
          key: state.pageKey,
          child: const ProfileEditPage(isOnboarding: true),
        ),
      ),
      GoRoute(
        path: '/settings/profile',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => forwardPage(
          key: state.pageKey,
          child: const ProfileEditPage(isOnboarding: false),
        ),
      ),
      GoRoute(
        path: '/profile/favorites',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) =>
            forwardPage(key: state.pageKey, child: const FavoritesPage()),
      ),
      GoRoute(
        path: '/profile/notification-settings',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) => forwardPage(
          key: state.pageKey,
          child: const NotificationSettingsPage(),
        ),
      ),
    ],
  );
}

class AnimatedBranchContainer extends StatelessWidget {
  const AnimatedBranchContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Retain every mounted navigator and its scroll/form state. Inactive
    // branches must not run decorative animation tickers in the background.
    return IndexedStack(
      index: currentIndex,
      children: [
        for (var i = 0; i < children.length; i++)
          TickerMode(enabled: i == currentIndex, child: children[i]),
      ],
    );
  }
}
