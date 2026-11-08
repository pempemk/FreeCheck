import 'package:flutter/material.dart' show FilledButton, TextField;
import 'package:flutter_test/flutter_test.dart';
import 'package:freecheck/pages/page.dart';
import 'package:freecheck/services/database_service.dart';

import 'seed.dart';
import 'support.dart';

void main() {
  late DatabaseService db;

  setUp(() async => db = await openTestDb());

  testWidgets('shows validation errors under the fields', (tester) async {
    await pumpPage(tester, () => OrganizerFormPage(db: db));

    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();

    expect(find.text('กรุณากรอกชื่อ Organizer'), findsOneWidget);
    expect(find.text('กรุณากรอกชื่อผู้ติดต่อ'), findsOneWidget);
    // Banner from Alert.showError.
    expect(find.text('ข้อมูลไม่ถูกต้อง'), findsOneWidget);
    expect(await db.select('organizers', {}), isEmpty);
  });

  testWidgets('saves a valid organizer to the database', (tester) async {
    await pumpPage(tester, () => OrganizerFormPage(db: db));

    await tester.enterText(find.byType(TextField).at(0), 'Nova Events');
    await tester.enterText(find.byType(TextField).at(1), 'ศิริพร');
    await tester.enterText(find.byType(TextField).at(2), '0812345678');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();

    final rows = await db.select('organizers', {});
    expect(rows.single['org_name'], 'Nova Events');
    expect(rows.single['rate'], 0);
    expect(find.text('บันทึกสำเร็จ'), findsOneWidget);
  });

  testWidgets('phone field keeps only up to 10 digits', (tester) async {
    await pumpPage(tester, () => OrganizerFormPage(db: db));

    await tester.enterText(find.byType(TextField).at(2), '08-1234-56789');
    await tester.pump();

    expect(find.text('0812345678'), findsOneWidget);
  });

  testWidgets('edits an existing organizer', (tester) async {
    final org = await Seed(db).organizers.createOrganizer({
      'org_name': 'Nova Events',
      'contact_name': 'ศิริพร',
      'color': '#6C5CE7',
    });
    await pumpPage(tester, () => OrganizerFormPage(db: db, organizer: org));

    expect(find.text('Nova Events'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Nova Studio');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();

    final rows = await db.select('organizers', {});
    expect(rows.single['org_name'], 'Nova Studio');
  });

  testWidgets('the error banner slides in at the top, away from buttons', (
    tester,
  ) async {
    await pumpPage(tester, () => OrganizerFormPage(db: db));

    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();

    final banner = tester.getRect(find.text('ข้อมูลไม่ถูกต้อง'));
    final button = tester.getRect(
      find.ancestor(
        of: find.text('บันทึก'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(banner.top, lessThan(120));
    expect(banner.bottom, lessThan(button.top));

    // It goes away on its own.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('ข้อมูลไม่ถูกต้อง'), findsNothing);
  });

  testWidgets('cannot delete an organizer that still has projects', (
    tester,
  ) async {
    final seed = Seed(db);
    final orgId = await seed.organizer('Nova Events');
    await seed.project('Website', orgId: orgId);
    final org = (await seed.organizers.getOrganizers()).single;
    await pumpPushed(tester, () => OrganizerFormPage(db: db, organizer: org));

    await tester.tap(find.byTooltip('ลบ Organizer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ลบ'));
    await tester.pumpAndSettle();

    expect(
      find.text('Organizer นี้ยังมีโปรเจกต์อยู่ ต้องลบโปรเจกต์ก่อน'),
      findsOneWidget,
    );
    expect(await db.select('organizers', {}), hasLength(1));
    expect(find.text('แก้ไข Organizer'), findsOneWidget);
  });

  testWidgets('deletes an organizer without projects', (tester) async {
    final orgId = await Seed(db).organizer('Nova Events');
    final org = (await Seed(
      db,
    ).organizers.getOrganizers()).firstWhere((o) => o.orgId == orgId);
    await pumpPushed(tester, () => OrganizerFormPage(db: db, organizer: org));

    await tester.tap(find.byTooltip('ลบ Organizer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ลบ'));
    await tester.pumpAndSettle();

    expect(await db.select('organizers', {}), isEmpty);
    expect(find.text('open'), findsOneWidget);
  });
}
