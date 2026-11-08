import 'package:flutter/material.dart' show TextField;
import 'package:flutter_test/flutter_test.dart';
import 'package:freecheck/pages/page.dart';
import 'package:freecheck/services/database_service.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'seed.dart';
import 'support.dart';

void main() {
  late DatabaseService db;
  late Seed seed;
  late int orgId;
  late int typeId;

  setUpAll(() => initializeDateFormatting('th'));

  setUp(() async {
    db = await openTestDb();
    seed = Seed(db);
    orgId = await seed.organizer('Nova Events');
    typeId = await seed.type('ออกแบบกราฟิก', ['รับบรีฟงาน', 'ส่งร่าง']);
    await seed.project('Poster', orgId: orgId, typeId: typeId);
    await seed.project(
      'Social Media',
      orgId: orgId,
      typeId: typeId,
      status: 'completed',
    );
    final other = await seed.organizer('Bloom Studio', phone: '0895551234');
    await seed.project('Photo', orgId: other);
  });

  testWidgets('organizer detail lists only its projects, done ones too', (
    tester,
  ) async {
    await pumpPage(tester, () => OrganizerDetailPage(orgId: orgId, db: db));

    expect(find.text('รายละเอียด Organizer'), findsOneWidget);
    expect(find.text('Nova Events'), findsOneWidget);
    expect(find.text('081-234-5678'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // project count
    await tester.scrollUntilVisible(find.text('Social Media'), 200);
    expect(find.text('Poster'), findsOneWidget);
    expect(find.text('Photo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('organizer pencil opens the edit form', (tester) async {
    await pumpPage(tester, () => OrganizerDetailPage(orgId: orgId, db: db));

    await tester.tap(find.byTooltip('แก้ไข Organizer'));
    await tester.pumpAndSettle();

    expect(find.text('แก้ไข Organizer'), findsWidgets);
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('checklist detail is read-only until the pencil is tapped', (
    tester,
  ) async {
    await pumpPage(tester, () => ChecklistDetailPage(typeId: typeId, db: db));

    expect(find.text('รายละเอียด Checklist'), findsOneWidget);
    expect(find.text('รับบรีฟงาน'), findsOneWidget);
    expect(find.text('2 ขั้นตอน • ใช้กับ 2 โปรเจกต์'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byTooltip('แก้ไข Checklist'));
    await tester.pumpAndSettle();

    expect(find.text('แก้ไข Checklist'), findsWidgets);
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('the projects tab includes completed work', (tester) async {
    await pumpPage(tester, () => HomePage(db: db));
    await tester.tap(find.text('โปรเจกต์'));
    await tester.pumpAndSettle();

    expect(find.text('ทั้งหมด 3'), findsOneWidget);
    await tester.ensureVisible(find.text('เสร็จสิ้น').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('เสร็จสิ้น').last);
    await tester.pumpAndSettle();

    expect(find.text('Social Media'), findsOneWidget);
    expect(find.text('Poster'), findsNothing);
  });

  testWidgets('tapping an organizer card opens its detail', (tester) async {
    await pumpPage(tester, () => HomePage(db: db));
    await tester.tap(find.text('ลูกค้า'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova Events'));
    await tester.pumpAndSettle();

    expect(find.text('รายละเอียด Organizer'), findsOneWidget);
  });
}
