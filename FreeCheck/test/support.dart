import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_tracker/controllers/checklist_controller.dart';
import 'package:freelance_tracker/core/app_exception.dart';
import 'package:freelance_tracker/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A fresh, empty SQLite database with the app schema.
///
/// sqflite reuses an open database per path, so each test gets its own
/// file in a new temporary folder. The no-isolate factory runs SQLite
/// synchronously, so it also works inside widget tests.
Future<DatabaseService> openTestDb() {
  final dir = Directory.systemTemp.createTempSync('freelance_test_');
  addTearDown(() => dir.deleteSync(recursive: true));
  return DatabaseService.open(
    factory: databaseFactoryFfiNoIsolate,
    path: '${dir.path}/test.db',
  );
}

Matcher throwsAppException(int statusCode, {String? field}) => throwsA(
  isA<AppException>()
      .having((e) => e.statusCode, 'statusCode', statusCode)
      .having(
        (e) => field == null || (e.fields?.containsKey(field) ?? false),
        'has field $field',
        isTrue,
      ),
);

var _readyTypes = 0;

/// Gives the project a checklist (if it has none) and ticks every step, so
/// it can be submitted.
Future<void> readyToSubmit(DatabaseService db, int projectId) async {
  final checklists = ChecklistController(db);
  var items = await checklists.getProjectChecklists(projectId);
  if (items.isEmpty) {
    final type = await checklists.createChecklist({
      'name': 'ready ${_readyTypes++}',
      'steps': ['done'],
    });
    items = await checklists.addChecklistToProject(projectId, {
      'type_id': type.typeId,
    });
  }
  for (final item in items.where((i) => !i.completed)) {
    await checklists.updateChecklist(projectId, item.checklistId, {});
  }
}
