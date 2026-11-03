import 'package:flutter/material.dart' show TextField;
import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_tracker/pages/page.dart';
import 'package:freelance_tracker/services/database_service.dart';

import 'seed.dart';
import 'support.dart';

void main() {
  late DatabaseService db;

  setUp(() async => db = await openTestDb());

  testWidgets('shows validation errors under the fields', (tester) async {
    await pumpPage(tester, () => OrganizerFormPage(db: db));

    await tester.tap(find.text('บันทึก Organizer'));
    await tester.pumpAndSettle();

    expect(find.text('กรุณากรอกชื่อ Organizer'), findsOneWidget);
    expect(find.text('กรุณากรอกชื่อผู้ติดต่อ'), findsOneWidget);
    // SnackBar from Alert.showError.
    expect(find.text('ข้อมูลไม่ถูกต้อง'), findsOneWidget);
    expect(await db.select('organizers', {}), isEmpty);
  });

  testWidgets('saves a valid organizer to the database', (tester) async {
    await pumpPage(tester, () => OrganizerFormPage(db: db));

    await tester.enterText(find.byType(TextField).at(0), 'Nova Events');
    await tester.enterText(find.byType(TextField).at(1), 'ศิริพร');
    await tester.enterText(find.byType(TextField).at(2), '0812345678');
    await tester.tap(find.text('บันทึก Organizer'));
    await tester.pumpAndSettle();

    final rows = await db.select('organizers', {});
    expect(rows.single['org_name'], 'Nova Events');
    expect(rows.single['rate'], 0);
  });
}
