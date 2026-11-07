import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' show ColorPicker;
import '../models/models.dart';

import '../core/format.dart';
import '../controllers/checklist_controller.dart';
import '../controllers/organizer_controller.dart';
import '../controllers/project_controller.dart';
import '../controllers/rating_controller.dart';
import '../core/app_exception.dart';
import '../services/database_service.dart';
import '../widgets/alert.dart';

part 'checklist_form_page.dart';
part 'history_page.dart';
part 'home_page.dart';
part 'organizer_form_page.dart';
part 'project_detail_page.dart';
part 'project_form_page.dart';
part 'widgets.dart';

/// Route names accepted by [Page.showForm].
const organizerFormRoute = '/organizers/new';
const projectFormRoute = '/projects/new';
const checklistFormRoute = '/types/new';

const _unexpectedError = 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';

/// The whole app, sharing one open [db] between all pages.
Widget buildApp(DatabaseService db) => MaterialApp(
  title: 'FreeCheck',
  debugShowCheckedModeBanner: false,
  theme: appTheme(),
  locale: const Locale('th'),
  supportedLocales: const [Locale('th'), Locale('en')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: hostPage(() => HomePage(db: db)),
  routes: {
    organizerFormRoute: (_) => hostPage(() => OrganizerFormPage(db: db)),
    projectFormRoute: (_) => hostPage(() => ProjectFormPage(db: db)),
    checklistFormRoute: (_) => hostPage(() => ChecklistFormPage(db: db)),
  },
);

/// Wraps a page so the Navigator can show it, e.g. `hostPage(HomePage.new)`.
Widget hostPage(Page<Object?> Function() create) => _PageHost(create);

class _PageHost extends StatefulWidget {
  const _PageHost(this._create);

  final Page<Object?> Function() _create;

  // A page is the State of this host, so each page class can be built with
  // its own constructor arguments.
  @override
  // ignore: no_logic_in_create_state
  State<StatefulWidget> createState() => _create();
}

/// Base class of every screen. [D] is the data the screen shows.
abstract class Page<D> extends State<StatefulWidget> {
  Page({required DatabaseService db}) : _db = db;

  /// Shared by every page; opened once in `main`.
  final DatabaseService _db;
  late final _organizers = OrganizerController(_db);
  late final _projects = ProjectController(_db);
  late final _checklists = ChecklistController(_db);
  late final _ratings = RatingController(_db);

  /// Data currently on screen; `null` until the first [showData].
  D? data;

  /// Field errors from the last failed submit, shown under each input.
  Map<String, String> fieldErrors = const {};

  bool _loading = false;
  String? _loadError;

  Alert get _alert => Alert(context);

  /// Opens a form by route name and returns what it pops (the saved model).
  Future<Object?> showForm(String name) =>
      Navigator.of(context).pushNamed<Object?>(name);

  /// Puts [newData] on screen.
  void showData(D newData) {
    if (!mounted) return;
    setState(() {
      data = newData;
      _loading = false;
      _loadError = null;
    });
  }

  Future<void> _openPage(Page<Object?> Function() create) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => hostPage(create)));

  /// Loads data with [fetch] and shows it, or shows the error.
  Future<void> _load(Future<D> Function() fetch) async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      showData(await fetch());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e is AppException ? e.message : _unexpectedError;
      });
    }
  }

  /// Runs a user action; shows field errors and an error SnackBar on failure.
  /// Returns `null` when the action failed.
  Future<T?> _run<T>(Future<T> Function() action, {String? success}) async {
    setState(() {
      _loading = true;
      fieldErrors = const {};
    });
    try {
      final result = await action();
      if (mounted && success != null) _alert.showMessage(success);
      return result;
    } on AppException catch (e) {
      if (mounted) {
        setState(() => fieldErrors = e.fields ?? const {});
        _alert.showError(e.message);
      }
      return null;
    } catch (e) {
      // Unexpected database errors; validation errors are AppException.
      debugPrint('Unexpected error: $e');
      if (mounted) _alert.showError(_unexpectedError);
      return null;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Spinner, error with retry, or [builder] once data is there.
  Widget _buildLoaded(
    Widget Function(D data) builder, {
    required VoidCallback onRetry,
  }) {
    final current = data;
    if (current != null) return builder(current);
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _emptyCard(
            'โหลดข้อมูลไม่สำเร็จ',
            _loadError!,
            action: _softButton('ลองอีกครั้ง', onRetry),
          ),
        ),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }

  /// [_buildLoaded] inside a plain Scaffold, for screens whose layout needs
  /// the data.
  Widget _loadingScaffold({required VoidCallback onRetry}) => Scaffold(
    body: SafeArea(
      child: _buildLoaded((_) => const SizedBox.shrink(), onRetry: onRetry),
    ),
  );

  /// Asks before running [delete]; closes the screen once it succeeds.
  Future<void> _deleteFlow({
    required String title,
    required String message,
    required Future<void> Function() delete,
  }) async {
    final ok = await _confirm(
      context,
      title: title,
      message: message,
      confirmLabel: 'ลบ',
      destructive: true,
    );
    if (!ok) return;
    final deleted = await _run(() async {
      await delete();
      return true;
    }, success: 'ลบสำเร็จ');
    if ((deleted ?? false) && mounted) Navigator.pop(context, true);
  }

  /// Confirm payment, then offer to rate the organizer.
  /// Returns the updated project, or `null` when cancelled or failed.
  Future<Project?> _confirmPaymentFlow(Project project) async {
    final ok = await _confirm(
      context,
      title: 'ยืนยันการรับเงิน',
      message:
          'ได้รับเงิน ${formatBaht(project.wages)} จาก '
          '${project.organizer?.orgName ?? 'Organizer'} แล้วใช่หรือไม่',
      cancelLabel: 'ปิด',
    );
    if (!ok) return null;
    final paid = await _run(() => _projects.confirmPayment(project.projectId));
    if (paid == null || !mounted) return paid;

    final rate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: _green, size: 56),
        title: const Text('ยืนยันการรับเงินเรียบร้อยแล้ว'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ปิด'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ให้คะแนน Organizer'),
          ),
        ],
      ),
    );
    if ((rate ?? false) && mounted) await _rateFlow(paid);
    return paid;
  }

  /// Ask for a score and save it. Returns true when saved.
  Future<bool> _rateFlow(Project project) async {
    final score = await _showRatingDialog(
      context,
      orgName: project.organizer?.orgName ?? '',
    );
    if (score == null) return false;
    final rating = await _run(
      () => _ratings.saveRating(project.projectId, {'score': score}),
      success: 'บันทึกการประเมินเรียบร้อยแล้ว',
    );
    return rating != null;
  }
}
