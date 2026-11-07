import 'dart:async';

import 'package:flutter/material.dart';

/// Shows feedback as a banner that slides in from the top of the screen,
/// above everything else on the page.
class Alert {
  const Alert(this.context);

  final BuildContext context;

  /// Only one banner at a time; a new one replaces the old.
  static OverlayEntry? _current;

  void showMessage(String message) => _show(message, isError: false);

  void showError(String message) => _show(message, isError: true);

  void _show(String message, {required bool isError}) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    if (_current?.mounted ?? false) _current!.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _TopBanner(
        message: message,
        isError: isError,
        onDismissed: () {
          if (entry.mounted) entry.remove();
          if (_current == entry) _current = null;
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _TopBanner extends StatefulWidget {
  const _TopBanner({
    required this.message,
    required this.isError,
    required this.onDismissed,
  });

  final String message;
  final bool isError;
  final VoidCallback onDismissed;

  @override
  State<_TopBanner> createState() => _TopBannerState();
}

class _TopBannerState extends State<_TopBanner>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  late final _offset = Tween(
    begin: const Offset(0, -1.5),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(const Duration(seconds: 3), _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = widget.isError
        ? scheme.errorContainer
        : scheme.inverseSurface;
    final foreground = widget.isError
        ? scheme.onErrorContainer
        : scheme.onInverseSurface;

    return Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offset,
        child: GestureDetector(
          // Swipe up to dismiss.
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < 0) _dismiss();
          },
          child: Material(
            color: background,
            elevation: 6,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
              child: Row(
                children: [
                  Icon(
                    widget.isError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    color: foreground,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(color: foreground, fontSize: 15),
                    ),
                  ),
                  IconButton(
                    tooltip: 'ปิด',
                    onPressed: _dismiss,
                    icon: Icon(Icons.close_rounded, color: foreground),
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
