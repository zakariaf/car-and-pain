import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';

import 'attachment_providers.dart';
import 'attachment_viewer_screen.dart';

/// A record's attachment gallery (F8-T6): a thumbnail grid with an add tile,
/// plus first-class loading / empty / error states. Tapping a thumbnail opens
/// the full-screen viewer. RTL-aware (logical grid + Directional insets),
/// accessible (every tile is a labelled Semantics button), and type is encoded
/// redundantly — a per-kind icon + label, never colour alone.
class AttachmentGallery extends ConsumerWidget {
  const AttachmentGallery({
    required this.ownerType,
    required this.ownerId,
    this.onAdd,
    super.key,
  });

  final String ownerType;
  final String ownerId;

  /// Invoked when the add tile is tapped (opens the capture/import sheet).
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async =
        ref.watch(attachmentsForOwnerProvider((type: ownerType, id: ownerId)));

    return async.when(
      loading: () => const _GalleryFrame(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) =>
          _GalleryFrame(child: _Message(l10n.attachmentLoadError)),
      data: (items) {
        if (items.isEmpty) {
          return _GalleryFrame(child: _EmptyState(onAdd: onAdd));
        }
        return _GalleryFrame(
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: PulseTokens.s1,
            crossAxisSpacing: PulseTokens.s1,
            padding: const EdgeInsetsDirectional.all(PulseTokens.s1),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < items.length; i++)
                AttachmentThumbnail(
                  attachment: items[i],
                  onTap: () => _open(context, items, i),
                ),
              if (onAdd != null) _AddTile(onTap: onAdd!),
            ],
          ),
        );
      },
    );
  }

  void _open(BuildContext context, List<Attachment> items, int index) {
    Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            AttachmentViewerScreen(items: items, initialIndex: index),
      ),
    );
  }
}

class _GalleryFrame extends StatelessWidget {
  const _GalleryFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            const EdgeInsetsDirectional.symmetric(vertical: PulseTokens.s1),
        child: child,
      );
}

/// A single tile — an image thumbnail, or a redundant icon + label for
/// non-image kinds. Bytes (possibly sealed) are read via the service; a load
/// failure degrades to a placeholder, never a crash.
class AttachmentThumbnail extends ConsumerStatefulWidget {
  const AttachmentThumbnail({required this.attachment, this.onTap, super.key});

  final Attachment attachment;
  final VoidCallback? onTap;

  @override
  ConsumerState<AttachmentThumbnail> createState() =>
      _AttachmentThumbnailState();
}

class _AttachmentThumbnailState extends ConsumerState<AttachmentThumbnail> {
  Future<Uint8List?>? _thumb;

  @override
  void initState() {
    super.initState();
    if (widget.attachment.kind == AttachmentKind.image &&
        widget.attachment.hasThumbnail) {
      _thumb = _load();
    }
  }

  Future<Uint8List?> _load() async {
    final r = await ref.read(attachmentServiceProvider).readThumbnail(
          widget.attachment,
        );
    return switch (r) {
      Ok(:final value) => value,
      Err() => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pc = theme.extension<PulseColorsExt>()!.c;
    final att = widget.attachment;
    final kindLabel = l10n.attachmentKind(att.kind.name);
    final semantics = att.originalFilename ?? kindLabel;

    return Semantics(
      button: true,
      image: att.kind == AttachmentKind.image,
      label: semantics,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(PulseTokens.rSmall),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(PulseTokens.rSmall),
            child: ColoredBox(
              color: pc.surface2,
              child: _content(theme, pc, att, kindLabel),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(
    ThemeData theme,
    PulseColors pc,
    Attachment att,
    String kindLabel,
  ) {
    if (_thumb != null) {
      return FutureBuilder<Uint8List?>(
        future: _thumb,
        builder: (context, snap) {
          final bytes = snap.data;
          if (bytes == null) {
            return snap.connectionState == ConnectionState.done
                ? _icon(theme, pc, att, kindLabel) // load failed → icon
                : ColoredBox(color: pc.surface2);
          }
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            cacheWidth: 240,
            errorBuilder: (_, __, ___) => _icon(theme, pc, att, kindLabel),
          );
        },
      );
    }
    return _icon(theme, pc, att, kindLabel);
  }

  Widget _icon(
    ThemeData theme,
    PulseColors pc,
    Attachment att,
    String kindLabel,
  ) {
    final icon = switch (att.kind) {
      AttachmentKind.pdf => Icons.picture_as_pdf_outlined,
      AttachmentKind.video => Icons.videocam_outlined,
      AttachmentKind.image => Icons.image_outlined,
      AttachmentKind.other => Icons.insert_drive_file_outlined,
    };
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: pc.text2, size: 28),
        const SizedBox(height: PulseTokens.sHalf),
        Text(kindLabel, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pc = theme.extension<PulseColorsExt>()!.c;
    return Semantics(
      button: true,
      label: l10n.attachmentsAdd,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PulseTokens.rSmall),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PulseTokens.rSmall),
              border: Border.all(color: pc.hairlineStrong),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: pc.text2),
                const SizedBox(height: PulseTokens.sHalf),
                Text(l10n.attachmentsAdd, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onAdd});
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pc = theme.extension<PulseColorsExt>()!.c;
    return Column(
      children: [
        Icon(Icons.photo_library_outlined, color: pc.text3, size: 32),
        const SizedBox(height: PulseTokens.s1),
        Text(
          l10n.attachmentsEmpty,
          style: theme.textTheme.bodyMedium?.copyWith(color: pc.text2),
        ),
        if (onAdd != null) ...[
          const SizedBox(height: PulseTokens.s2),
          PulseButton(
            label: l10n.attachmentsAdd,
            icon: Icons.add,
            variant: PulseButtonVariant.ghost,
            onPressed: onAdd,
          ),
        ],
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(text, style: theme.textTheme.bodyMedium),
    );
  }
}
