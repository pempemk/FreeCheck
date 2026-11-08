import 'package:flutter_test/flutter_test.dart';
import 'package:freecheck/services/database_service.dart';

import '../support.dart';

void main() {
  late DatabaseService db;

  setUp(() async => db = await openTestDb());

  test('insert returns the id and select reads it back', () async {
    final id = await db.insert('types', {'name': 'A'}, idColumn: 'type_id');
    expect(await db.select('types', {'type_id': id}), [
      {'type_id': id, 'name': 'A'},
    ]);
    expect(await db.exists('types', {'name': 'A'}), isTrue);
    expect(await db.exists('types', {'name': 'B'}), isFalse);
  });

  test('where supports IN lists and IS NULL', () async {
    for (final name in ['A', 'B', 'C']) {
      await db.insert('types', {'name': name}, idColumn: 'type_id');
    }
    final rows = await db.select('types', {
      'name': ['A', 'C'],
    }, orderBy: 'name DESC');
    expect([for (final r in rows) r['name']], ['C', 'A']);
    expect(await db.select('types', {'name': <String>[]}), isEmpty);
  });

  test('update and delete only touch matching rows', () async {
    final a = await db.insert('types', {'name': 'A'}, idColumn: 'type_id');
    await db.insert('types', {'name': 'B'}, idColumn: 'type_id');
    await db.update('types', {'type_id': a}, {'name': 'A2'});
    await db.delete('types', {'name': 'B'});
    expect(await db.select('types', {}), [
      {'type_id': a, 'name': 'A2'},
    ]);
  });

  test('transaction rolls back every statement when one fails', () async {
    await expectLater(
      db.transaction((tx) async {
        await tx.insert('types', {'name': 'A'}, idColumn: 'type_id');
        throw StateError('boom');
      }),
      throwsStateError,
    );
    expect(await db.exists('types', {'name': 'A'}), isFalse);
  });

  test('rejects identifiers that are not plain names', () {
    expect(() => db.select('types; DROP TABLE types', {}), throwsArgumentError);
    expect(
      () => db.select('types', {'name = name OR 1': 1}),
      throwsArgumentError,
    );
    expect(
      () => db.select('types', {}, orderBy: 'name; DROP TABLE types'),
      throwsArgumentError,
    );
  });

  test('values are parameters, never SQL', () async {
    const evil = "x'); DROP TABLE types; --";
    await db.insert('types', {'name': evil}, idColumn: 'type_id');
    expect(await db.exists('types', {'name': evil}), isTrue);
  });
}
