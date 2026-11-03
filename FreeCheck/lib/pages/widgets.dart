part of 'page.dart';

// Design tokens and small building blocks shared by the pages.

const _primary = Color(0xFF6C5CE7);
const _indigo = Color(0xFF4338CA);
const _ink = Color(0xFF1E2140);
const _muted = Color(0xFF8A8FA8);
const _background = Color(0xFFF5F6FB);
const _track = Color(0xFFE6E8F0);
const _purpleSoft = Color(0xFFEEEBFF);
const _orange = Color(0xFFE0974B);
const _orangeSoft = Color(0xFFFFF1E3);
const _green = Color(0xFF3E9E6A);
const _greenSoft = Color(0xFFE8F7EE);
const _red = Color(0xFFD9636E);
const _redSoft = Color(0xFFFDEDEF);
const _greySoft = Color(0xFFEFF0F5);

/// Light theme matching the app design.
ThemeData appTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _primary,
    primary: _primary,
    surface: Colors.white,
    error: _red,
  );
  OutlineInputBorder border([Color? color, double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: color == null
            ? BorderSide.none
            : BorderSide(color: color, width: width),
      );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: _background,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: _muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: border(),
      enabledBorder: border(),
      disabledBorder: border(),
      focusedBorder: border(_primary, 1.5),
      errorBorder: border(_red),
      focusedErrorBorder: border(_red, 1.5),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      height: 72,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? _primary : _muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 13,
          color: states.contains(WidgetState.selected) ? _primary : _muted,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w400,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

typedef _StatusStyle = ({String label, Color color, Color soft});

_StatusStyle _statusStyle(ProjectStatus status) => switch (status) {
  ProjectStatus.inProgress => (
    label: 'กำลังทำ',
    color: _primary,
    soft: _purpleSoft,
  ),
  ProjectStatus.pending => (label: 'รอตรวจ', color: _orange, soft: _orangeSoft),
  ProjectStatus.submitted => (
    label: 'รอรับเงิน',
    color: _green,
    soft: _greenSoft,
  ),
  ProjectStatus.completed => (
    label: 'เสร็จสิ้น',
    color: _muted,
    soft: _greySoft,
  ),
};

/// Rounded pill; tappable when [onTap] is given.
Widget _pill(
  String label, {
  required Color color,
  required Color background,
  VoidCallback? onTap,
}) {
  return Material(
    color: background,
    shape: const StadiumBorder(),
    child: InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

Widget _statusChip(ProjectStatus status, {String? label}) {
  final style = _statusStyle(status);
  return _pill(
    label ?? style.label,
    color: style.color,
    background: style.soft,
  );
}

/// White rounded card.
Widget _surface({
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  VoidCallback? onTap,
  Color color = Colors.white,
  double radius = 20,
}) {
  return Material(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// Back arrow, large title and subtitle at the top of a screen.
Widget _header(
  BuildContext context, {
  required String title,
  String? subtitle,
  bool back = true,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          if (back)
            IconButton(
              tooltip: 'ย้อนกลับ',
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.chevron_left, size: 32, color: _ink),
            ),
          if (back) const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
      if (subtitle != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(color: _muted, fontSize: 14),
          ),
        ),
    ],
  );
}

/// Header + scrolling content + optional pinned [bottom] action.
Widget _screenBody(
  BuildContext context, {
  required String title,
  required List<Widget> children,
  String? subtitle,
  Widget? bottom,
  bool back = true,
  bool loading = false,
  RefreshCallback? onRefresh,
}) {
  Widget list = ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
    children: [
      _header(context, title: title, subtitle: subtitle, back: back),
      const SizedBox(height: 24),
      ...children,
    ],
  );
  if (onRefresh != null) {
    list = RefreshIndicator(onRefresh: onRefresh, child: list);
  }
  return Column(
    children: [
      SizedBox(
        height: 2,
        child: loading ? const LinearProgressIndicator(minHeight: 2) : null,
      ),
      Expanded(child: list),
      if (bottom != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: bottom,
        ),
    ],
  );
}

/// A full screen built with [_screenBody].
Widget _screen(
  BuildContext context, {
  required String title,
  required List<Widget> children,
  String? subtitle,
  Widget? bottom,
  bool loading = false,
  RefreshCallback? onRefresh,
}) {
  return Scaffold(
    body: SafeArea(
      child: _screenBody(
        context,
        title: title,
        subtitle: subtitle,
        bottom: bottom,
        loading: loading,
        onRefresh: onRefresh,
        children: children,
      ),
    ),
  );
}

Widget _primaryButton(
  String label,
  VoidCallback? onPressed, {
  Color color = _primary,
}) {
  return SizedBox(
    width: double.infinity,
    height: 56,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    ),
  );
}

Widget _softButton(String label, VoidCallback? onPressed) {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _purpleSoft,
        foregroundColor: _primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    ),
  );
}

Widget _fieldLabel(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(
    text,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: _ink,
    ),
  ),
);

Widget _sectionTitle(String title, {String? subtitle, Widget? trailing}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
      if (subtitle != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle, style: const TextStyle(color: _muted)),
        ),
    ],
  );
}

Widget _progressBar(num percent, Color color, {double height = 8}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: LinearProgressIndicator(
      value: (percent / 100).clamp(0, 1).toDouble(),
      minHeight: height,
      color: color,
      backgroundColor: _track,
    ),
  );
}

/// Project summary used by the dashboard and the project list.
Widget _projectCard(
  Project project, {
  required VoidCallback onTap,
  bool shortDate = false,
}) {
  final style = _statusStyle(project.status);
  final deadline = project.deadline;
  final overdue =
      deadline != null &&
      deadline.isBefore(DateUtils.dateOnly(DateTime.now())) &&
      project.status == ProjectStatus.inProgress;
  final due = deadline == null
      ? 'ไม่มีกำหนดส่ง'
      : shortDate
      ? 'ส่ง ${formatShortDate(deadline)}'
      : formatDate(deadline);

  return _surface(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: colorFromHex(project.organizer?.color),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.projectName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${project.organizer?.orgName ?? '-'} • $due',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: overdue ? _red : _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'ความคืบหน้า',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _muted, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${project.progress.round()}%',
                        style: TextStyle(
                          color: style.color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _progressBar(project.progress, style.color),
                ],
              ),
            ),
            const SizedBox(width: 20),
            _statusChip(project.status),
          ],
        ),
      ],
    ),
  );
}

/// Rounded square with the organizer's initial in its color.
Widget _organizerAvatar(Organizer organizer, {double size = 64}) {
  final name = organizer.orgName.trim();
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: colorFromHex(organizer.color),
      borderRadius: BorderRadius.circular(size / 4),
    ),
    child: Text(
      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
      style: TextStyle(
        color: Colors.white,
        fontSize: size * 0.42,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Card shown when a list is empty.
Widget _emptyCard(String title, String message, {Widget? action}) {
  return _surface(
    padding: const EdgeInsets.all(28),
    child: Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted),
        ),
        if (action != null) ...[const SizedBox(height: 16), action],
      ],
    ),
  );
}

/// Read-only star display.
Widget _stars(num score, {double size = 20}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          score >= i
              ? Icons.star_rounded
              : score >= i - 0.5
              ? Icons.star_half_rounded
              : Icons.star_outline_rounded,
          size: size,
          color: _orange,
        ),
    ],
  );
}

/// Error message shown under inputs that are not text fields.
Widget _fieldError(String? message) {
  if (message == null) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 6, left: 4),
    child: Text(message, style: const TextStyle(color: _red, fontSize: 12)),
  );
}

/// Dialog that asks for a 1–5 star score. Returns the score or `null`.
Future<int?> _showRatingDialog(
  BuildContext context, {
  required String orgName,
}) {
  return showDialog<int>(
    context: context,
    builder: (context) {
      var score = 0;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('ให้คะแนน Organizer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(orgName, style: const TextStyle(color: _muted)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      tooltip: '$i ดาว',
                      iconSize: 36,
                      onPressed: () => setState(() => score = i),
                      icon: Icon(
                        i <= score
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: _orange,
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: score == 0
                  ? null
                  : () => Navigator.pop(context, score),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      );
    },
  );
}

/// Yes/no confirmation dialog.
Future<bool> _confirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'ยืนยัน',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
