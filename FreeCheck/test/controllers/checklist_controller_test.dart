import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_tracker/controllers/checklist_controller.dart';
import 'package:freelance_tracker/controllers/organizer_controller.dart';
import 'package:freelance_tracker/controllers/project_controller.dart';
import 'package:freelance_tracker/services/database_service.dart';
import 'package:freelance_tracker/models/models.dart';

import '../support.dart';

void main() {
  late DatabaseService db;
  late ChecklistController controller;
  late ProjectController projects;
  late int projectId;

  Future<Type> type(String name, List<String> steps) =>
      controller.createChecklist({'name': name, 'steps': steps});

  setUp(() async {
    db = await openTestDb();
    controller = ChecklistController(db);
    projects = ProjectController(db);
    final org = await OrganizerController(db).createOrganizer({
      'org_name': 'ACME',
      'contact_name': 'Som',
      'color': '#FF5733',
    });
    projectId = (await projects.createProject({
      'project_name': 'Website',
      'org_id': org.orgId,
      'start_date': '2026-10-01',
      'wages': 1000,
    })).projectId;
  });

  group('validate', () {
    test('passes for valid input', () {
      expect(
        controller.validate({
          'name': 'เว็บไซต์',
          'steps': ['ออกแบบ', 'พัฒนา'],
        }),
        isEmpty,
      );
    });

    test('fails when name is empty or steps missing', () {
      final errors = controller.validate({'name': '', 'steps': <String>[]});
      expect(errors.keys, containsAll(['name', 'steps']));
    });

    test('reports each empty step by index', () {
      final errors = controller.validate({
        'name': 'x',
        'steps': ['ok', ' ', 5],
      });
      expect(errors.keys, containsAll(['steps.1', 'steps.2']));
      expect(errors.containsKey('steps.0'), isFalse);
    });
  });

  group('createChecklist', () {
    test('saves the type and its steps in order', () async {
      final created = await type('เว็บไซต์', ['ออกแบบ', 'พัฒนา']);

      expect([for (final c in created.checklists) c.name], ['ออกแบบ', 'พัฒนา']);
      final steps = await db.select('checklists', {
        'type_id': created.typeId,
      }, orderBy: 'checklist_id');
      expect([for (final s in steps) s['name']], ['ออกแบบ', 'พัฒนา']);
    });

    test('throws 400 and saves nothing when invalid', () async {
      await expectLater(
        controller.createChecklist({'name': 'x', 'steps': <String>[]}),
        throwsAppException(400, field: 'steps'),
      );
      expect(await db.select('types', {}), isEmpty);
    });

    test('throws 409 when type name exists', () async {
      await type('เว็บไซต์', ['a']);
      await expectLater(
        type('เว็บไซต์', ['b']),
        throwsAppException(409, field: 'name'),
      );
    });
  });

  test('getTypes groups steps under their type', () async {
    await type('B', ['b1', 'b2']);
    await type('A', ['a1']);

    final types = await controller.getTypes();
    expect([for (final t in types) t.name], ['A', 'B']);
    expect([for (final t in types) t.checklists.length], [1, 2]);
  });

  group('addChecklistToProject', () {
    test('copies all steps of the type with completed = false', () async {
      final web = await type('Web', ['a', 'b']);

      final items = await controller.addChecklistToProject(projectId, {
        'type_id': web.typeId,
      });

      expect([for (final i in items) i.checklist!.name], ['a', 'b']);
      expect(items.every((i) => !i.completed), isTrue);
    });

    test('adds a second type next to the first', () async {
      final web = await type('Web', ['a', 'b']);
      final logo = await type('Logo', ['c']);
      await controller.addChecklistToProject(projectId, {
        'type_id': web.typeId,
      });

      final items = await controller.addChecklistToProject(projectId, {
        'type_id': logo.typeId,
      });
      expect([for (final i in items) i.checklist!.name], ['a', 'b', 'c']);
    });

    test('throws 400 when type_id missing', () {
      expect(
        () => controller.addChecklistToProject(projectId, {}),
        throwsAppException(400, field: 'type_id'),
      );
    });

    test('throws 404 for unknown project or type', () async {
      final web = await type('Web', ['a']);
      await expectLater(
        controller.addChecklistToProject(99, {'type_id': web.typeId}),
        throwsAppException(404),
      );
      await expectLater(
        controller.addChecklistToProject(projectId, {'type_id': 99}),
        throwsAppException(404),
      );
    });

    test('throws 409 when every step of the type is already added', () async {
      final web = await type('Web', ['a']);
      await controller.addChecklistToProject(projectId, {
        'type_id': web.typeId,
      });
      await expectLater(
        controller.addChecklistToProject(projectId, {'type_id': web.typeId}),
        throwsAppException(409),
      );
    });
  });

  group('removeChecklistFromProject', () {
    test('removes only the steps of that type', () async {
      final web = await type('Web', ['a', 'b']);
      final logo = await type('Logo', ['c']);
      for (final t in [web, logo]) {
        await controller.addChecklistToProject(projectId, {
          'type_id': t.typeId,
        });
      }

      await controller.removeChecklistFromProject(projectId, {
        'type_id': '${web.typeId}',
      });

      final left = await controller.getProjectChecklists(projectId);
      expect([for (final i in left) i.checklist!.name], ['c']);
    });

    test('throws 400 when type_id is missing or not a number', () {
      for (final query in [
        <String, dynamic>{},
        {'type_id': 'abc'},
      ]) {
        expect(
          () => controller.removeChecklistFromProject(projectId, query),
          throwsAppException(400, field: 'type_id'),
        );
      }
    });

    test('throws 404 when the project does not use that type', () async {
      final web = await type('Web', ['a']);
      await expectLater(
        controller.removeChecklistFromProject(projectId, {
          'type_id': web.typeId,
        }),
        throwsAppException(404),
      );
    });

    test('throws 409 when the project is completed', () async {
      final web = await type('Web', ['a']);
      await controller.addChecklistToProject(projectId, {
        'type_id': web.typeId,
      });
      await projects.submitProject(projectId);
      await projects.passProject(projectId);
      await projects.confirmPayment(projectId);

      await expectLater(
        controller.removeChecklistFromProject(projectId, {
          'type_id': web.typeId,
        }),
        throwsAppException(409),
      );
    });
  });

  group('updateChecklist / getProgress', () {
    test('progress is 0 without steps', () async {
      expect(await controller.getProgress(projectId), 0);
    });

    test('ticking and unticking returns the new progress', () async {
      final web = await type('Web', ['a', 'b', 'c']);
      await controller.addChecklistToProject(projectId, {
        'type_id': web.typeId,
      });
      final [a, b, _] = web.checklists;

      expect(
        await controller.updateChecklist(projectId, a.checklistId, {}),
        33.33,
      );
      expect(
        await controller.updateChecklist(projectId, b.checklistId, {}),
        66.67,
      );
      expect(
        await controller.updateChecklist(projectId, a.checklistId, {
          'completed': false,
        }),
        33.33,
      );
      expect(await controller.getProgress(projectId), 33.33);
    });

    test('throws 400 when completed is not a bool', () {
      expect(
        () => controller.updateChecklist(projectId, 1, {'completed': 'yes'}),
        throwsAppException(400, field: 'completed'),
      );
    });

    test('throws 404 when step is not in project', () async {
      await expectLater(
        controller.updateChecklist(projectId, 99, {}),
        throwsAppException(404),
      );
    });
  });
}
