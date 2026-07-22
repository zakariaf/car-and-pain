import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';

import 'attachment_providers.dart';

/// Full-screen attachment viewer (F8-T6): swipe between a record's attachments,
/// pinch-zoom images. Immersive (black, no PULSE chrome). RTL-aware — the swipe
/// direction follows the reading direction while the logical index is preserved;
/// zooming an image locks paging so a pan never turns into a page turn. Non-image
/// kinds show an accessible localized fallback with an open-externally hook.
class AttachmentViewerScreen extends ConsumerStatefulWidget {
  const AttachmentViewerScreen({
    required this.items,
    this.initialIndex = 0,
    super.key,
  });

  final List<Attachment> items;
  final int initialIndex;

  @override
  ConsumerState<AttachmentViewerScreen> createState() =>
      _AttachmentViewerScreenState();
}

class _AttachmentViewerScreenState
    extends ConsumerState<AttachmentViewerScreen> {
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);
  final TransformationController _transform = TransformationController();
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
  }

  @override
  void dispose() {
    _transform
      ..removeListener(_onTransform)
      ..dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onTransform() {
    final scale = _transform.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.01;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  void _onPageChanged() {
    // Reset zoom when the (non-zoomed) page settles.
    _transform.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              reverse: rtl, // swipe follows the reading direction
              physics: _zoomed
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              onPageChanged: (_) => _onPageChanged(),
              itemCount: widget.items.length,
              itemBuilder: (context, i) => _Page(
                attachment: widget.items[i],
                transform: _transform,
              ),
            ),
            const PositionedDirectional(
              top: PulseTokens.s1,
              start: PulseTokens.s1,
              child: _CloseButton(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).closeButtonTooltip,
      child: Material(
        color: Colors.black38,
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(Icons.adaptive.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

class _Page extends ConsumerStatefulWidget {
  const _Page({required this.attachment, required this.transform});

  final Attachment attachment;
  final TransformationController transform;

  @override
  ConsumerState<_Page> createState() => _PageState();
}

class _PageState extends ConsumerState<_Page> {
  Future<Result<Uint8List, Failure>>? _bytes;

  @override
  void initState() {
    super.initState();
    // Read ONCE — not per build — so a zoom/rebuild doesn't re-read + re-decrypt
    // the full-res image (which would flash a spinner and tear down the gesture).
    if (widget.attachment.kind == AttachmentKind.image) {
      _bytes = ref.read(attachmentServiceProvider).readBytes(widget.attachment);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attachment = widget.attachment;
    if (attachment.kind != AttachmentKind.image) {
      return _Fallback(attachment: attachment);
    }
    return FutureBuilder<Result<Uint8List, Failure>>(
      future: _bytes,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        final result = snap.data!;
        return switch (result) {
          Ok(:final value) => InteractiveViewer(
              transformationController: widget.transform,
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: Image.memory(
                  value,
                  errorBuilder: (_, __, ___) =>
                      _Fallback(attachment: attachment),
                ),
              ),
            ),
          Err() => _Fallback(attachment: attachment),
        };
      },
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.attachment});
  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final icon = switch (attachment.kind) {
      AttachmentKind.pdf => Icons.picture_as_pdf_outlined,
      AttachmentKind.video => Icons.videocam_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 56),
            const SizedBox(height: 12),
            Text(
              l10n.attachmentUnsupported,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () {}, // wired to share_plus open-externally on device
              icon: const Icon(Icons.open_in_new),
              label: Text(l10n.attachmentOpenExternally),
            ),
          ],
        ),
      ),
    );
  }
}
