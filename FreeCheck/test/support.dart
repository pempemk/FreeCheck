import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
