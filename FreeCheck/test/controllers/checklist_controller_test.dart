import 'package:flutter_test/flutter_test.dart';
import 'package:freecheck/controllers/checklist_controller.dart';
import 'package:freecheck/controllers/organizer_controller.dart';
import 'package:freecheck/controllers/project_controller.dart';
import 'package:freecheck/services/database_connector.dart';
import 'package:freecheck/models/models.dart';

import '../support.dart';

void main() {
  late DatabaseConnector db;
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

    test('throws 409 when the project already has a checklist', () async {
      final web = await type('Web', ['a']);
      final logo = await type('Logo', ['b']);
      await controller.addChecklistToProject(projectId, {
        'type_id': web.typeId,
      });

      for (final t in [web, logo]) {
        await expectLater(
          controller.addChecklistToProject(projectId, {'type_id': t.typeId}),
          throwsAppException(409),
        );
      }
      final items = await controller.getProjectChecklists(projectId);
      expect([for (final i in items) i.checklist!.name], ['a']);
    });

    test('the checklist can be swapped after removing the old one', () async {
      final web = await type('Web', ['a']);
      final logo = await type('Logo', ['b']);
      await controller.addChecklistToProject(projectId, {
        'type_id': web.typeId,
      });

      await controller.removeChecklistFromProject(projectId, {
        'type_id': web.typeId,
      });
      final items = await controller.addChecklistToProject(projectId, {
        'type_id': logo.typeId,
      });
      expect([for (final i in items) i.checklist!.name], ['b']);
    });
  });

  group('removeChecklistFromProject', () {
    test('removes the project checklist', () async {
      final web = await type('Web', ['a', 'b']);
      await controller.addChecklistToProject(projectId, {
        'type_id': web.typeId,
      });

      await controller.removeChecklistFromProject(projectId, {
        'type_id': '${web.typeId}',
      });

      expect(await controller.getProjectChecklists(projectId), isEmpty);
      expect(await db.select('checklists', {}), hasLength(2));
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
      await readyToSubmit(db, projectId);
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

  group('editChecklist', () {
    test('renames, adds and removes unused steps', () async {
      final web = await controller.createChecklist({
        'name': 'Web',
        'steps': ['a', 'b', 'c'],
      });
      final [a, b, _] = web.checklists;

      final edited = await controller.editChecklist(web.typeId, {
        'name': 'Website',
        'steps': [
          {'checklist_id': a.checklistId, 'name': 'a2'},
          {'checklist_id': b.checklistId, 'name': 'b'},
          'd',
        ],
      });

      expect(edited.name, 'Website');
      expect([for (final c in edited.checklists) c.name], ['a2', 'b', 'd']);
      expect(edited.checklists.first.checklistId, a.checklistId);
    });

    test('throws 409 when removing a step a project uses', () async {
      final web = await controller.createChecklist({
        'name': 'Web',
        'steps': ['a', 'b'],
      });
      await controller.addChecklistToProject(projectId, {
        'type_id': web.typeId,
      });

      await expectLater(
        controller.editChecklist(web.typeId, {
          'name': 'Web',
          'steps': [
            {'checklist_id': web.checklists.first.checklistId, 'name': 'a'},
          ],
        }),
        throwsAppException(409, field: 'steps'),
      );
      expect((await controller.getTypes()).single.checklists, hasLength(2));
    });

    test('throws 409 for a name another type has, 404 when missing', () async {
      final web = await controller.createChecklist({
        'name': 'Web',
        'steps': ['a'],
      });
      await controller.createChecklist({
        'name': 'Logo',
        'steps': ['b'],
      });

      await expectLater(
        controller.editChecklist(web.typeId, {
          'name': 'Logo',
          'steps': ['a'],
        }),
        throwsAppException(409, field: 'name'),
      );
      await expectLater(
        controller.editChecklist(99, {
          'name': 'X',
          'steps': ['a'],
        }),
        throwsAppException(404),
      );
    });

    test('throws 400 when a step is empty', () async {
      final web = await controller.createChecklist({
        'name': 'Web',
        'steps': ['a'],
      });
      await expectLater(
        controller.editChecklist(web.typeId, {
          'name': 'Web',
          'steps': [
            {'checklist_id': web.checklists.first.checklistId, 'name': ' '},
          ],
        }),
        throwsAppException(400, field: 'steps.0'),
      );
    });
  });

  group('deleteChecklist', () {
    test('deletes a type and its steps when no project uses it', () async {
      final web = await type('Web', ['a', 'b']);
      await controller.deleteChecklist(web.typeId);
      expect(await db.select('types', {}), isEmpty);
      expect(await db.select('checklists', {}), isEmpty);
    });

    test('throws 409 while a project uses its steps', () async {
      final web = await type('Web', ['a']);
      await controller.addChecklistToProject(projectId, {
        'type_id': web.typeId,
      });
      await expectLater(
        controller.deleteChecklist(web.typeId),
        throwsAppException(409),
      );

      await controller.removeChecklistFromProject(projectId, {
        'type_id': web.typeId,
      });
      await controller.deleteChecklist(web.typeId);
      expect(await db.select('types', {}), isEmpty);
    });

    test('throws 404 when missing', () async {
      await expectLater(
        controller.deleteChecklist(99),
        throwsAppException(404),
      );
    });
  });
}
