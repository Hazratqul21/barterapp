import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/data/auth_repository.dart';

class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key, required this.isOnboarding});

  final bool isOnboarding;

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  final _name = TextEditingController();
  final _handle = TextEditingController();
  final _avatarUrl = TextEditingController();

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isOnboarding) {
      final me = ref.read(meProvider).asData?.value;
      if (me != null) {
        _name.text = me.name;
        _handle.text = me.handle ?? '';
        _avatarUrl.text = me.avatarUrl ?? '';
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    _avatarUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final body = {
        'name': _name.text.trim(),
        'handle': _handle.text.trim(),
        'avatar_url': _avatarUrl.text.trim(),
      };
      
      await ref.read(authRepositoryProvider).updateProfile(body);
      ref.invalidate(meProvider);
      
      if (!mounted) return;
      if (widget.isOnboarding) {
        context.go('/home');
      } else {
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isOnboarding ? 'Complete Profile' : 'Edit Profile'),
        leading: widget.isOnboarding 
          ? null 
          : IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: context.pop,
            ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'About You',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _name,
                        enabled: !_busy,
                        decoration: const InputDecoration(labelText: 'Full Name'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _handle,
                        enabled: !_busy,
                        decoration: const InputDecoration(labelText: 'Handle (@username)'),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Avatar',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _avatarUrl,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Avatar URL',
                          hintText: 'https://...',
                        ),
                      ),
                      const SizedBox(height: 48),
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.2),
                              )
                            : const Text('Save Profile'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
