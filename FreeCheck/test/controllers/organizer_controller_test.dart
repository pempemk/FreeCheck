import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_tracker/controllers/organizer_controller.dart';
import 'package:freelance_tracker/services/database_service.dart';

import '../support.dart';

void main() {
  late DatabaseService db;
  late OrganizerController controller;

  final valid = {
    'org_name': 'ACME',
    'contact_name': 'สมชาย Smith',
    'phone': '0812345678',
    'color': '#ff5733',
  };

  setUp(() async {
    db = await openTestDb();
    controller = OrganizerController(db);
  });

  group('validate', () {
    test('passes for valid input', () {
      expect(controller.validate(valid), isEmpty);
    });

    test('phone is optional', () {
      expect(controller.validate({...valid, 'phone': ''}), isEmpty);
    });

    test('fails when required fields are empty', () {
      final errors = controller.validate({});
      expect(errors.keys, containsAll(['org_name', 'contact_name', 'color']));
      expect(errors.containsKey('phone'), isFalse);
    });

    test('fails when contact_name has digits or symbols', () {
      for (final name in ['Som1', 'Som@chai']) {
        expect(
          controller.validate({...valid, 'contact_name': name}),
          contains('contact_name'),
          reason: name,
        );
      }
    });

    test('fails when phone is not digits only', () {
      expect(
        controller.validate({...valid, 'phone': '081-234'}),
        contains('phone'),
      );
    });

    test('fails when color is not hex', () {
      for (final color in ['red', '#FFF', 'FF5733', '#GG5733']) {
        expect(
          controller.validate({...valid, 'color': color}),
          contains('color'),
          reason: color,
        );
      }
    });
  });

  group('createOrganizer', () {
    test('saves with rate 0 and an upper-case color', () async {
      final organizer = await controller.createOrganizer(valid);

      expect(organizer.orgId, greaterThan(0));
      expect(organizer.rate, 0);
      expect(organizer.color, '#FF5733');
      final rows = await db.select('organizers', {'org_id': organizer.orgId});
      expect(rows.single['org_name'], 'ACME');
    });

    test('throws 400 and saves nothing when invalid', () async {
      await expectLater(
        controller.createOrganizer({...valid, 'org_name': ' '}),
        throwsAppException(400, field: 'org_name'),
      );
      expect(await db.select('organizers', {}), isEmpty);
    });

    test('throws 409 when org_name already exists', () async {
      await controller.createOrganizer(valid);
      await expectLater(
        controller.createOrganizer(valid),
        throwsAppException(409, field: 'org_name'),
      );
    });
  });

  test('getOrganizers returns organizers ordered by name', () async {
    await controller.createOrganizer({...valid, 'org_name': 'Zeta'});
    await controller.createOrganizer({...valid, 'org_name': 'Alpha'});

    final organizers = await controller.getOrganizers();
    expect([for (final o in organizers) o.orgName], ['Alpha', 'Zeta']);
  });
}
