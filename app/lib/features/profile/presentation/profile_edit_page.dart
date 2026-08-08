import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/photo_picker.dart';
import '../../../shared/models/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/data/auth_repository.dart';

/// Who you are, in the three fields the rest of the app reads off you.
///
/// This screen used to send `{"name": ...}`. `MeUpdate` has `first_name` and
/// `last_name` and no `name` at all, and Pydantic drops unknown fields without
/// complaining — so the request succeeded, the name was silently discarded, and
/// every new account stayed nameless on every card in the product.
class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key, required this.isOnboarding});

  /// True right after a first sign-in, where there is nothing to go back to.
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
    _firstName.dispose();
    _lastName.dispose();
    _handle.dispose();
    super.dispose();
  }

  /// Fill the form from the server copy once it arrives.
  ///
  /// Done in `build` off the provider rather than in `initState`: at first
  /// sign-in `meProvider` has not resolved yet, so reading it there returned
  /// nothing and editing an existing profile started from blank fields.
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
    setState(() => _uploading = true);
    try {
      final url = await pickAndUploadPhoto(context, ref);
      if (!mounted) return;
      if (url != null) setState(() => _avatarUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(errorMessage(context, e))));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).updateProfile({
        'first_name': _firstName.text.trim(),
        'last_name': _lastName.text.trim(),
        // Null clears it; an empty string would fail the server's length check.
        'handle': _handle.text.trim().isEmpty ? null : _handle.text.trim(),
        if (_region != null) 'region': _region,
        if (_avatarUrl != null) 'avatar_url': _avatarUrl,
      });
      ref.invalidate(meProvider);
      if (!mounted) return;
      widget.isOnboarding ? context.go('/home') : context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(errorMessage(context, e))));
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

    meAsync.whenData((me) {
      if (me != null) _seed(me);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isOnboarding ? l.profileSetupTitle : l.profileEditTitle,
        ),
        // Nothing to go back to on a first sign-in — the account has no name
        // yet, and a nameless trader cannot be seen on any card.
        automaticallyImplyLeading: !widget.isOnboarding,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Gap.x5,
                  Gap.x5,
                  Gap.x5,
                  Gap.x10,
                ),
                children: [
                  if (widget.isOnboarding) ...[
                    Text(
                      l.profileSetupLede,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: p.inkSoft,
                      ),
                    ),
                    Gap.h6,
                  ],

                  // Not wrapped in a Center: inside a ListView that hands the
                  // child an unbounded height, and the Column then stretched
                  // instead of hugging the avatar.
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      PhotoWell(
                        url: _avatarUrl,
                        busy: _uploading,
                        circular: true,
                        size: Sizes.avatarXl,
                        onTap: _pickPhoto,
                        onRemove: () => setState(() => _avatarUrl = null),
                      ),
                      Gap.h2,
                      TextButton(
                        onPressed: _uploading ? null : _pickPhoto,
                        child: Text(
                          _uploading
                              ? l.uploading
                              : (_avatarUrl == null
                                    ? l.profilePhotoPick
                                    : l.profilePhotoChange),
                        ),
                      ),
                    ],
                  ),
                  Gap.h5,

                  TextFormField(
                    controller: _firstName,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.givenName],
                    decoration: InputDecoration(labelText: l.profileFirstName),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? l.profileRequired : null,
                  ),
                  Gap.h3,
                  TextFormField(
                    controller: _lastName,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.familyName],
                    decoration: InputDecoration(labelText: l.profileLastName),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? l.profileRequired : null,
                  ),
                  Gap.h3,

                  regionsAsync.when(
                    loading: () => const SkeletonBox(height: Sizes.buttonLg),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (regions) => DropdownButtonFormField<String>(
                      initialValue: regions.contains(_region) ? _region : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l.profileRegion,
                        helperText: l.profileRegionHint,
                        prefixIcon: const Icon(Symbols.location_on_rounded),
                      ),
                      items: [
                        for (final r in regions)
                          DropdownMenuItem(value: r, child: Text(r)),
                      ],
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _region = v),
                    ),
                  ),
                  Gap.h3,

                  TextFormField(
                    controller: _handle,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: l.profileHandle,
                      helperText: l.profileHandleHint,
                      prefixIcon: const Icon(Symbols.storefront_rounded),
                    ),
                  ),

                  Gap.h8,
                  FilledButton(
                    onPressed: _busy || _uploading
                        ? null
                        : () {
                            HapticFeedback.lightImpact();
                            _save();
                          },
                    child: _busy
                        ? const SizedBox(
                            width: Sizes.iconLg,
                            height: Sizes.iconLg,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Text(l.profileSave),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
