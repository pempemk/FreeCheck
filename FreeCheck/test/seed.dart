import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:freecheck/controllers/checklist_controller.dart';
import 'package:freecheck/controllers/organizer_controller.dart';
import 'package:freecheck/controllers/project_controller.dart';
import 'package:freecheck/pages/page.dart';
import 'package:freecheck/services/database_service.dart';

import 'support.dart';

/// Sample data built through the controllers, like a user would.
class Seed {
  Seed(this.db)
    : organizers = OrganizerController(db),
      projects = ProjectController(db),
      checklists = ChecklistController(db);

  final DatabaseService db;
  final OrganizerController organizers;
  final ProjectController projects;
  final ChecklistController checklists;

  Future<int> organizer(String name, {String phone = '0812345678'}) async =>
      (await organizers.createOrganizer({
        'org_name': name,
        'contact_name': 'ศิริพร',
        'phone': phone,
        'color': '#6C5CE7',
      })).orgId;

  Future<int> type(String name, List<String> steps) async =>
      (await checklists.createChecklist({'name': name, 'steps': steps})).typeId;

  /// A project using [typeId]'s steps, the first [done] of them ticked,
  /// moved through [status] (in_progress, pending, submitted, completed).
  Future<int> project(
    String name, {
    required int orgId,
    int? typeId,
    int done = 0,
    String status = 'in_progress',
  }) async {
    final id = (await projects.createProject({
      'project_name': name,
      'org_id': orgId,
      'start_date': '2026-10-12',
      'deadline': '2099-12-18',
      'wages': 12000,
    })).projectId;
    if (typeId != null) {
      final items = await checklists.addChecklistToProject(id, {
        'type_id': typeId,
      });
      for (final item in items.take(done)) {
        await checklists.updateChecklist(id, item.checklistId, {});
      }
    }
    const order = ['in_progress', 'pending', 'submitted', 'completed'];
    if (status != 'in_progress') await readyToSubmit(db, id);
    final steps = [
      projects.submitProject,
      projects.passProject,
      projects.confirmPayment,
    ];
    for (var i = 0; i < order.indexOf(status); i++) {
      await steps[i](id);
    }
    return id;
  }
}

/// Shows [page] on a phone-sized screen with the app theme.
Future<void> pumpPage(
  WidgetTester tester,
  Page<Object?> Function() page,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: appTheme(), home: hostPage(page)));
  await tester.pumpAndSettle();
}

/// Opens [page] on top of a plain start screen (with an "open" button), so
/// tests can check that the page closes itself.
Future<void> pumpPushed(
  WidgetTester tester,
  Page<Object?> Function() page,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => hostPage(page))),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}
