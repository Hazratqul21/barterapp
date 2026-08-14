import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/photo_picker.dart';
import '../../../shared/models/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/auth_repository.dart';

class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key, required this.isOnboarding});
  final bool isOnboarding;

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _handle = TextEditingController();

  String? _region;
  String? _avatarUrl;
  bool _busy = false;
  bool _uploading = false;
  bool _loaded = false;

  @override
  void dispose() {
    _firstName.dispose(); _lastName.dispose(); _handle.dispose();
    super.dispose();
  }

  void _seed(Me me) {
    if (_loaded) return;
    _loaded = true;
    _firstName.text = me.firstName;
    _lastName.text = me.lastName;
    _handle.text = me.handle ?? '';
    _region = me.region;
    _avatarUrl = me.avatarUrl;
  }

  Future<void> _pickPhoto() async {
    HapticFeedback.lightImpact();
    setState(() => _uploading = true);
    try {
      final url = await pickAndUploadPhoto(context, ref);
      if (url != null) setState(() => _avatarUrl = url);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(context, e))));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).updateProfile({
        'first_name': _firstName.text.trim(),
        'last_name': _lastName.text.trim(),
        'handle': _handle.text.trim().isEmpty ? null : _handle.text.trim(),
        if (_region != null) 'region': _region,
        if (_avatarUrl != null) 'avatar_url': _avatarUrl,
      });
      ref.invalidate(meProvider);
      if (!mounted) return;
      widget.isOnboarding ? context.go('/home') : context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(context, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = palette(context);
    final theme = Theme.of(context);
    final meAsync = ref.watch(meProvider);
    final regionsAsync = ref.watch(regionsProvider);

    meAsync.whenData((me) { if (me != null) _seed(me); });

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.isOnboarding ? l.profileSetupTitle : l.profileEditTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        automaticallyImplyLeading: !widget.isOnboarding,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(Gap.x5, Gap.x3, Gap.x5, Gap.x10),
                children: [
                  if (widget.isOnboarding) ...[
                    Text(l.profileSetupLede, style: theme.textTheme.bodyLarge?.copyWith(color: p.inkSoft)),
                    Gap.h6,
                  ],

                  Center(
                    child: Column(
                      children: [
                        PhotoWell(url: _avatarUrl, busy: _uploading, circular: true, size: 96, onTap: _pickPhoto, onRemove: () => setState(() => _avatarUrl = null)),
                        Gap.h2,
                        TextButton(
                          onPressed: _uploading ? null : _pickPhoto,
                          child: Text(_uploading ? l.uploading : (_avatarUrl == null ? l.profilePhotoPick : l.profilePhotoChange)),
                        ),
                      ],
                    ),
                  ),
                  Gap.h6,

                  _M3Field(controller: _firstName, label: l.profileFirstName, icon: Symbols.person_rounded, enabled: !_busy, hint: l.profileRequired),
                  Gap.h3,
                  _M3Field(controller: _lastName, label: l.profileLastName, icon: Symbols.badge_rounded, enabled: !_busy, hint: l.profileRequired),
                  Gap.h3,

                  regionsAsync.when(
                    loading: () => const SkeletonBox(height: 64, radius: Radii.rMd),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (regions) => DropdownButtonFormField<String>(
                      initialValue: regions.contains(_region) ? _region : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l.profileRegion,
                        prefixIcon: const Icon(Symbols.location_on_rounded),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerLow,
                      ),
                      items: [for (final r in regions) DropdownMenuItem(value: r, child: Text(r))],
                      onChanged: _busy ? null : (v) => setState(() => _region = v),
                    ),
                  ),
                  Gap.h3,

                  _M3Field(controller: _handle, label: l.profileHandle, icon: Symbols.storefront_rounded, enabled: !_busy, helper: l.profileHandleHint),

                  Gap.h8,
                  FilledButton(
                    onPressed: _busy || _uploading ? null : _save,
                    child: _busy ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : Text(l.profileSave),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms),
            ),
          ),
        ),
      ),
    );
  }
}

class _M3Field extends StatelessWidget {
  const _M3Field({required this.controller, required this.label, required this.icon, required this.enabled, this.hint, this.helper});
  final TextEditingController controller; final String label; final IconData icon; final bool enabled; final String? hint; final String? helper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      enabled: enabled,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        helperText: helper,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerLow,
      ),
      validator: hint != null ? (v) => (v == null || v.trim().isEmpty) ? hint : null : null,
    );
  }
}
