import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/feed/presentation/feed_page.dart';
import '../../features/listing/presentation/listing_detail_page.dart';
import '../../features/profile/presentation/payments_page.dart';
import '../../features/profile/presentation/profile_edit_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/profile/presentation/settings_page.dart';
import '../../features/profile/presentation/verification_page.dart';
import '../../features/trade/presentation/chat_page.dart';
import '../../features/trade/presentation/create_listing_page.dart';
import '../../features/trade/presentation/inbox_page.dart';
import '../../features/trade/presentation/matches_page.dart';
import '../../features/trade/presentation/notifications_page.dart';
import '../../features/trade/presentation/offer_page.dart';
import '../../features/trade/presentation/trader_profile_page.dart';
import 'app_shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Routes mirror the URLs the web build exposes, so a listing link can be
/// pasted into a browser and a phone and land in the same place.
///
/// Tab screens live inside the shell; everything else is pushed on top of it,
/// which is what makes "back" return to wherever the user actually came from.
GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/listing/:id',
        parentNavigatorKey: _rootKey,
        builder: (context, state) =>
            ListingDetailPage(listingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat/:id',
        parentNavigatorKey: _rootKey,
        builder: (context, state) =>
            ChatPage(conversationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/offer/:listingId',
        parentNavigatorKey: _rootKey,
        builder: (context, state) =>
            OfferPage(listingId: state.pathParameters['listingId']!),
      ),
      GoRoute(
        path: '/trader/:id',
        parentNavigatorKey: _rootKey,
        builder: (context, state) =>
            TraderProfilePage(traderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/create',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const CreateListingPage(),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/settings/verify',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const VerificationPage(),
      ),
      GoRoute(
        path: '/settings/payments',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const PaymentsPage(),
      ),
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const ProfileEditPage(isOnboarding: true),
      ),
      GoRoute(
        path: '/settings/profile',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const ProfileEditPage(isOnboarding: false),
      ),
    ],
  );
}
