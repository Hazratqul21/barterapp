import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/models.dart';
import '../../trade/data/trade_repository.dart';
import '../../../core/theme/haptics.dart';

final blockedUsersProvider = FutureProvider.autoDispose<List<TraderBrief>>((
  ref,
) {
  return ref.watch(tradeRepositoryProvider).getBlockedUsers();
});

class BlockedUsersPage extends ConsumerWidget {
  const BlockedUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final asyncUsers = ref.watch(blockedUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.blockedTitle),
        backgroundColor: Colors.transparent,
      ),
      body: asyncUsers.when(
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Text(
                l.blockedEmpty,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(Gap.x4),
            itemCount: users.length,
            separatorBuilder: (context, index) => Gap.h4,
            itemBuilder: (context, index) {
              final u = users[index];
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: Radii.rMd,
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                tileColor: theme.colorScheme.surfaceContainerLow,
                leading: CircleAvatar(
                  backgroundImage: u.avatarUrl != null
                      ? NetworkImage(u.avatarUrl!)
                      : null,
                  child: u.avatarUrl == null ? const Icon(Icons.person) : null,
                ),
                title: Text(u.name, style: theme.textTheme.titleMedium),
                trailing: TextButton(
                  onPressed: () async {
                    Haptics.light();
                    try {
                      await ref.read(tradeRepositoryProvider).unblockUser(u.id);
                      ref.invalidate(blockedUsersProvider);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(l.errorGeneric)));
                      }
                    }
                  },
                  child: Text(l.blockedUnblock),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(
            l.errorGeneric,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      ),
    );
  }
}
