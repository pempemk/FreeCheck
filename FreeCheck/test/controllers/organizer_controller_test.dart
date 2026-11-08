import 'package:flutter_test/flutter_test.dart';
import 'package:freecheck/controllers/organizer_controller.dart';
import 'package:freecheck/controllers/project_controller.dart';
import 'package:freecheck/services/database_service.dart';

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

    test('phone is at most 10 digits', () {
      expect(controller.validate({...valid, 'phone': '0812345678'}), isEmpty);
      expect(
        controller.validate({...valid, 'phone': '08123456789'}),
        contains('phone'),
      );
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

  group('updateOrganizer', () {
    test('saves new values and keeps the rate', () async {
      final org = await controller.createOrganizer(valid);
      await db.update('organizers', {'org_id': org.orgId}, {'rate': 4.5});

      final updated = await controller.updateOrganizer(org.orgId, {
        ...valid,
        'org_name': 'ACME Studio',
        'color': '#00ff00',
      });

      expect(updated.orgName, 'ACME Studio');
      expect(updated.color, '#00FF00');
      expect(updated.rate, 4.5);
    });

    test('keeps its own name but rejects another organizer\'s', () async {
      final org = await controller.createOrganizer(valid);
      await controller.createOrganizer({...valid, 'org_name': 'Other'});

      await controller.updateOrganizer(org.orgId, valid);
      await expectLater(
        controller.updateOrganizer(org.orgId, {...valid, 'org_name': 'Other'}),
        throwsAppException(409, field: 'org_name'),
      );
    });

    test('throws 400 when invalid and 404 when missing', () async {
      final org = await controller.createOrganizer(valid);
      await expectLater(
        controller.updateOrganizer(org.orgId, {...valid, 'phone': 'abc'}),
        throwsAppException(400, field: 'phone'),
      );
      await expectLater(
        controller.updateOrganizer(99, valid),
        throwsAppException(404),
      );
    });
  });

  group('deleteOrganizer', () {
    test('deletes an organizer without projects', () async {
      final org = await controller.createOrganizer(valid);
      await controller.deleteOrganizer(org.orgId);
      expect(await db.select('organizers', {}), isEmpty);
    });

    test('throws 409 while the organizer still has projects', () async {
      final org = await controller.createOrganizer(valid);
      await ProjectController(db).createProject({
        'project_name': 'Website',
        'org_id': org.orgId,
        'start_date': '2026-10-01',
        'wages': 1000,
      });
      await expectLater(
        controller.deleteOrganizer(org.orgId),
        throwsAppException(409),
      );
      expect(await db.select('organizers', {}), hasLength(1));
    });

    test('throws 404 when missing', () async {
      await expectLater(
        controller.deleteOrganizer(99),
        throwsAppException(404),
      );
    });
  });
}
