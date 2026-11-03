import 'package:flutter/material.dart' show Scrollable, TextField;
import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_tracker/pages/page.dart';
import 'package:freelance_tracker/services/database_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:freelance_tracker/models/models.dart';

import 'seed.dart';
import 'support.dart';

/// The page's main list (multi-line text fields scroll too).
final _page = find.byType(Scrollable).first;

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
    typeId = await seed.type('ออกแบบกราฟิก', [
      'รับบรีฟงาน',
      'ส่งร่างให้ลูกค้า',
    ]);
    await seed.type('งานถ่ายภาพ', ['ถ่ายภาพ']);
  });

  Future<int> project(String status) => seed.project(
    'ออกแบบโปสเตอร์ Event',
    orgId: orgId,
    typeId: typeId,
    done: 1,
    status: status,
  );

  testWidgets('in progress: checklist, progress and submit button', (
    tester,
  ) async {
    final id = await project('in_progress');
    await pumpPage(tester, () => ProjectDetailPage(projectId: id, db: db));

    expect(find.text('รายละเอียดโปรเจกต์'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('รับบรีฟงาน'), findsOneWidget);
    // Steps are grouped by type, and types can be added or removed.
    expect(find.text('ออกแบบกราฟิก'), findsOneWidget);
    expect(find.byTooltip('ลบ Checklist นี้ออกจากงาน'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('+ เพิ่ม Checklist'),
      200,
      scrollable: _page,
    );
    expect(find.text('ส่งงานให้ Organizer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ticking a step updates progress from the database', (
    tester,
  ) async {
    final id = await project('in_progress');
    await pumpPage(tester, () => ProjectDetailPage(projectId: id, db: db));

    await tester.scrollUntilVisible(
      find.text('ส่งร่างให้ลูกค้า'),
      200,
      scrollable: _page,
    );
    await tester.tap(find.text('ส่งร่างให้ลูกค้า'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('100%'), -200, scrollable: _page);

    expect(find.text('100%'), findsOneWidget);
    expect(await seed.checklists.getProgress(id), 100);
  });

  testWidgets('pending: "ต้องแก้ไข" saves the note and reopens the work', (
    tester,
  ) async {
    final id = await project('pending');
    await pumpPage(tester, () => ProjectDetailPage(projectId: id, db: db));

    expect(find.text('ติดตามการส่งงาน'), findsOneWidget);
    expect(find.text('ผ่านการตรวจ'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(TextField),
      200,
      scrollable: _page,
    );
    await tester.enterText(find.byType(TextField), 'แก้สีปุ่ม');
    await tester.ensureVisible(find.text('ต้องแก้ไข'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ต้องแก้ไข'));
    await tester.pumpAndSettle();

    final saved = await seed.projects.getProject(id);
    expect(saved.status, ProjectStatus.inProgress);
    expect(saved.note, 'แก้สีปุ่ม');
    expect(find.text('รายละเอียดโปรเจกต์'), findsOneWidget);
  });

  testWidgets('submitted: confirm payment button', (tester) async {
    final id = await project('submitted');
    await pumpPage(tester, () => ProjectDetailPage(projectId: id, db: db));

    expect(find.text('ยืนยันรับเงิน'), findsOneWidget);
    expect(find.text('ส่งงานให้ Organizer'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
