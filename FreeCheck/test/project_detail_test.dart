import 'package:flutter/material.dart'
    show FilledButton, Scrollable, TextButton, TextField;
import 'package:flutter_test/flutter_test.dart';
import 'package:freecheck/models/models.dart';
import 'package:freecheck/pages/page.dart';
import 'package:freecheck/services/database_connector.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'seed.dart';
import 'support.dart';

/// The page's main list (multi-line text fields scroll too).
final _page = find.byType(Scrollable).first;

Finder _filled(String label) => find.widgetWithText(FilledButton, label);

void main() {
  late DatabaseConnector db;
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

  Future<int> project(String status, {int done = 1, bool checklist = true}) =>
      seed.project(
        'ออกแบบโปสเตอร์ Event',
        orgId: orgId,
        typeId: checklist ? typeId : null,
        done: done,
        status: status,
      );

  Future<ProjectStatus> statusOf(int id) async =>
      (await seed.projects.getProject(id)).status;

  testWidgets('in progress: checklist, progress and submit button', (
    tester,
  ) async {
    final id = await project('in_progress');
    await pumpPage(tester, () => ProjectDetailPage(projectId: id, db: db));

    expect(find.text('รายละเอียดโปรเจกต์'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('รับบรีฟงาน'),
      200,
      scrollable: _page,
    );
    expect(find.text('ออกแบบกราฟิก'), findsOneWidget);
    expect(find.byTooltip('ลบ Checklist นี้ออกจากงาน'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('เปลี่ยน Checklist'),
      200,
      scrollable: _page,
    );
    expect(find.text('ส่งงาน'), findsOneWidget);
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

  testWidgets('"ส่งงาน" stays disabled until the checklist is 100%', (
    tester,
  ) async {
    final id = await project('in_progress');
    await pumpPage(tester, () => ProjectDetailPage(projectId: id, db: db));

    expect(find.text('ทำ Checklist ให้ครบ 100% ก่อนส่งงาน'), findsOneWidget);
    expect(tester.widget<FilledButton>(_filled('ส่งงาน')).onPressed, isNull);

    await tester.scrollUntilVisible(
      find.text('ส่งร่างให้ลูกค้า'),
      200,
      scrollable: _page,
    );
    await tester.tap(find.text('ส่งร่างให้ลูกค้า'));
    await tester.pumpAndSettle();

    expect(find.text('ทำ Checklist ให้ครบ 100% ก่อนส่งงาน'), findsNothing);
    expect(tester.widget<FilledButton>(_filled('ส่งงาน')).onPressed, isNotNull);
  });

  testWidgets('UC-06: "ส่งงาน" saves at once and shows "ผ่าน" / "ไม่ผ่าน"', (
    tester,
  ) async {
    final id = await project('in_progress', done: 2);
    await pumpPage(tester, () => ProjectDetailPage(projectId: id, db: db));

    await tester.tap(_filled('ส่งงาน'));
    await tester.pumpAndSettle();

    expect(await statusOf(id), ProjectStatus.pending);
    expect((await seed.projects.getProject(id)).submittedAt, isNotNull);
    expect(find.text('ผ่าน'), findsOneWidget);
    expect(find.text('ไม่ผ่าน'), findsOneWidget);
  });

  testWidgets('UC-07: "ไม่ผ่าน" reopens the work, then "บันทึก" saves the '
      'revision details', (tester) async {
    final id = await project('pending');
    await pumpPage(tester, () => ProjectDetailPage(projectId: id, db: db));

    await tester.tap(find.text('ไม่ผ่าน'));
    await tester.pumpAndSettle();

    // Status changes before the details are written.
    expect(await statusOf(id), ProjectStatus.inProgress);
    expect(find.text('รายละเอียดการแก้ไข'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'แก้สีปุ่ม');
    await tester.tap(_filled('บันทึก'));
    await tester.pumpAndSettle();

    expect((await seed.projects.getProject(id)).note, 'แก้สีปุ่ม');
    expect(find.text('บันทึกสำเร็จ'), findsOneWidget);
    expect(find.text('รายละเอียดโปรเจกต์'), findsOneWidget);
  });

  testWidgets('UC-08/09: "ผ่าน" opens the payment window; it can be closed '
      'and reopened with "ยืนยันรับเงิน"', (tester) async {
    final id = await project('pending');
    await pumpPushed(tester, () => ProjectDetailPage(projectId: id, db: db));

    await tester.tap(find.text('ผ่าน'));
    await tester.pumpAndSettle();

    expect(await statusOf(id), ProjectStatus.submitted);
    expect(_filled('ยืนยัน'), findsOneWidget);

    // Not paid yet: close the window.
    await tester.tap(find.widgetWithText(TextButton, 'ปิด'));
    await tester.pumpAndSettle();
    expect(await statusOf(id), ProjectStatus.submitted);

    await tester.tap(_filled('ยืนยันรับเงิน'));
    await tester.pumpAndSettle();
    await tester.tap(_filled('ยืนยัน'));
    await tester.pumpAndSettle();

    expect(await statusOf(id), ProjectStatus.completed);
    expect(find.text('ยืนยันการรับเงินเรียบร้อยแล้ว'), findsOneWidget);
    expect(_filled('ให้คะแนน Organizer'), findsOneWidget);

    // UC-10 from the success window.
    await tester.tap(_filled('ให้คะแนน Organizer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('5 ดาว'));
    await tester.pump();
    await tester.tap(_filled('บันทึกคะแนน'));
    await tester.pumpAndSettle();

    expect((await seed.projects.getProject(id)).rating!.score, 5);
    expect(find.text('บันทึกการประเมินเรียบร้อยแล้ว'), findsOneWidget);
    // The project left the detail page (it now lives in the history).
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('UC-04: tapping a type only selects it; "บันทึก" ties it to the '
      'project', (tester) async {
    final id = await project('in_progress', checklist: false);
    await pumpPage(tester, () => ProjectDetailPage(projectId: id, db: db));

    await tester.scrollUntilVisible(
      find.text('เลือก Checklist'),
      200,
      scrollable: _page,
    );
    await tester.tap(find.text('เลือก Checklist'));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(_filled('บันทึก')).onPressed, isNull);
    await tester.tap(find.text('งานถ่ายภาพ'));
    await tester.pumpAndSettle();
    expect(await seed.checklists.getProjectChecklists(id), isEmpty);

    await tester.tap(_filled('บันทึก'));
    await tester.pumpAndSettle();

    final items = await seed.checklists.getProjectChecklists(id);
    expect([for (final i in items) i.checklist!.name], ['ถ่ายภาพ']);
    expect(find.text('บันทึกสำเร็จ'), findsOneWidget);
  });

  testWidgets('"เปลี่ยน Checklist" replaces the old one after "บันทึก"', (
    tester,
  ) async {
    final id = await project('in_progress');
    await pumpPage(tester, () => ProjectDetailPage(projectId: id, db: db));

    await tester.scrollUntilVisible(
      find.text('เปลี่ยน Checklist'),
      200,
      scrollable: _page,
    );
    await tester.tap(find.text('เปลี่ยน Checklist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('งานถ่ายภาพ'));
    await tester.pumpAndSettle();
    await tester.tap(_filled('บันทึก'));
    await tester.pumpAndSettle();

    final items = await seed.checklists.getProjectChecklists(id);
    expect([for (final i in items) i.checklist!.name], ['ถ่ายภาพ']);
    expect(items.single.completed, isFalse);
  });

  testWidgets('submitted: "ยืนยันรับเงิน" and no "ส่งงาน"', (tester) async {
    final id = await project('submitted');
    await pumpPage(tester, () => ProjectDetailPage(projectId: id, db: db));

    expect(find.text('ยืนยันรับเงิน'), findsOneWidget);
    expect(find.text('ส่งงาน'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed without a rating shows "ให้คะแนน"', (tester) async {
    final id = await project('completed');
    await pumpPage(tester, () => ProjectDetailPage(projectId: id, db: db));

    expect(_filled('ให้คะแนน'), findsOneWidget);
  });

  testWidgets('edit button opens the project form filled in', (tester) async {
    final id = await project('in_progress');
    await pumpPage(tester, () => ProjectDetailPage(projectId: id, db: db));

    await tester.tap(find.byTooltip('แก้ไขโปรเจกต์'));
    await tester.pumpAndSettle();

    expect(find.text('แก้ไขโปรเจกต์'), findsWidgets);
    expect(find.text('ออกแบบโปสเตอร์ Event'), findsOneWidget);
    expect(_filled('บันทึก'), findsOneWidget);
  });

  testWidgets('deletes the project after confirming', (tester) async {
    final id = await project('in_progress');
    await pumpPushed(tester, () => ProjectDetailPage(projectId: id, db: db));

    await tester.tap(find.byTooltip('ลบโปรเจกต์'));
    await tester.pumpAndSettle();
    await tester.tap(_filled('ลบ'));
    await tester.pumpAndSettle();

    expect(await db.select('projects', {}), isEmpty);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('cancelling keeps the project', (tester) async {
    final id = await project('in_progress');
    await pumpPushed(tester, () => ProjectDetailPage(projectId: id, db: db));

    await tester.tap(find.byTooltip('ลบโปรเจกต์'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();

    expect(await db.select('projects', {}), hasLength(1));
    expect(find.text('รายละเอียดโปรเจกต์'), findsOneWidget);
  });
}
