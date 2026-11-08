import 'package:flutter/material.dart' show FilledButton, FloatingActionButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:freecheck/pages/page.dart';
import 'package:freecheck/services/database_connector.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'seed.dart';
import 'support.dart';

void main() {
  late DatabaseConnector db;

  setUpAll(() => initializeDateFormatting('th'));

  setUp(() async {
    db = await openTestDb();
    final seed = Seed(db);
    final orgId = await seed.organizer('Nova Events');
    final typeId = await seed.type('ออกแบบกราฟิก', ['รับบรีฟงาน', 'ส่งร่าง']);
    await seed.project(
      'ออกแบบโปสเตอร์ Event',
      orgId: orgId,
      typeId: typeId,
      done: 1,
    );
    await seed.project('Landing Page', orgId: orgId, status: 'pending');
    await seed.project(
      'Social Media',
      orgId: orgId,
      typeId: typeId,
      status: 'completed',
    );
  });

  testWidgets('dashboard and every tab render on a phone screen', (
    tester,
  ) async {
    await pumpPage(tester, () => HomePage(db: db));

    // Dashboard: money received and money waiting, in one card.
    expect(find.text('รายได้ที่ได้รับแล้ว'), findsOneWidget);
    expect(find.text('ยอดรอรับเงิน'), findsOneWidget);
    expect(find.text('฿ 12,000'), findsOneWidget);
    expect(find.text('01'), findsNWidgets(3));
    expect(find.text('ออกแบบโปสเตอร์ Event'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Projects tab with filters.
    await tester.tap(find.text('โปรเจกต์'));
    await tester.pumpAndSettle();
    expect(find.text('โปรเจกต์ของฉัน'), findsOneWidget);
    expect(find.text('ทั้งหมด 3'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'เพิ่ม Project'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    // The filter row scrolls sideways on narrow screens.
    await tester.ensureVisible(find.text('รอตรวจ').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('รอตรวจ').first);
    await tester.pumpAndSettle();
    expect(find.text('Landing Page'), findsOneWidget);
    expect(find.text('ออกแบบโปสเตอร์ Event'), findsNothing);

    // Checklist templates with usage counts.
    await tester.tap(find.text('เช็กลิสต์'));
    await tester.pumpAndSettle();
    expect(find.text('✦ ออกแบบกราฟิก'), findsOneWidget);
    expect(find.text('2 ขั้นตอน • ใช้กับ 2 โปรเจกต์'), findsOneWidget);

    // Organizers.
    await tester.tap(find.text('ลูกค้า'));
    await tester.pumpAndSettle();
    expect(find.text('Nova Events'), findsOneWidget);
    expect(find.text('ศิริพร • 081-234-5678'), findsOneWidget);
    expect(find.text('★ 0.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
