import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../features/trade/data/trade_repository.dart';
import '../../l10n/app_localizations.dart';
import 'common.dart';

/// Take a photo — or pick one — and hand back the URL the server stored it at.
///
/// Listings and avatars used to be URL text fields, which works for a seeded
/// demo and for nobody else: the person with a spare laptop photographs it,
/// they do not host it somewhere first.
///
/// Returns null when the picker is dismissed. Throws whatever the upload threw,
/// so the caller can show it the same way it shows any other failure.
Future<String?> pickAndUploadPhoto(
  BuildContext context,
  WidgetRef ref, {
  void Function(int sent, int total)? onProgress,
}) async {
  final source = await _chooseSource(context);
  if (source == null) return null;

  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: source,
    // A first pass on the device: the upload is smaller and quicker, and the
    // server re-encodes whatever arrives anyway.
    maxWidth: 2000,
    maxHeight: 2000,
    imageQuality: 88,
  );
  if (file == null) return null;

  final bytes = await file.readAsBytes();
  return ref
      .read(tradeRepositoryProvider)
      .uploadPhoto(
        bytes: bytes,
        filename: file.name,
        onProgress: onProgress,
      );
}

/// Camera or gallery. Skipped on the web, which has neither distinction nor a
/// camera worth offering — the file dialog covers both.
Future<ImageSource?> _chooseSource(BuildContext context) async {
  if (kIsWeb) return ImageSource.gallery;

  final l = L.of(context);
  return showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Symbols.photo_camera_rounded),
            title: Text(l.photoCamera),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Symbols.photo_library_rounded),
            title: Text(l.photoGallery),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
}

/// A square that shows the chosen photo, or invites one.
class PhotoWell extends StatelessWidget {
  const PhotoWell({
    super.key,
    required this.url,
    required this.onTap,
    this.busy = false,
    this.size = 96,
    this.circular = false,
    this.onRemove,
  });

  final String? url;
  final VoidCallback? onTap;
  final bool busy;
  final double size;

  /// Avatars are round; listing photos are not.
  final bool circular;

  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final p = palette(context);
    final scheme = Theme.of(context).colorScheme;
    final radius = circular
        ? BorderRadius.circular(size)
        : BorderRadius.circular(16);
    final hasPhoto = url != null && url!.isNotEmpty;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: p.sunken,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: busy ? null : onTap,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: hasPhoto ? Colors.transparent : p.hair,
                    width: 1.5,
                  ),
                ),
                child: busy
                    ? Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: p.give,
                          ),
                        ),
                      )
                    : hasPhoto
                    ? RemoteImage(url: url, semanticLabel: '')
                    : Icon(
                        Symbols.add_a_photo_rounded,
                        color: p.inkFaint,
                        size: size * 0.3,
                      ),
              ),
            ),
          ),
          if (hasPhoto && !busy && onRemove != null)
            Positioned(
              top: -6,
              right: -6,
              child: Material(
                color: scheme.surfaceContainerLowest,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Symbols.close_rounded,
                      size: 16,
                      color: p.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
