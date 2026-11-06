import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_tracker/controllers/checklist_controller.dart';
import 'package:freelance_tracker/controllers/organizer_controller.dart';
import 'package:freelance_tracker/controllers/project_controller.dart';
import 'package:freelance_tracker/controllers/rating_controller.dart';
import 'package:freelance_tracker/services/database_service.dart';
import 'package:freelance_tracker/models/models.dart';

import '../support.dart';

void main() {
  late DatabaseService db;
  late ProjectController controller;
  late ChecklistController checklists;
  late int orgId;

  Map<String, dynamic> body(String name, {String? deadline}) => {
    'project_name': name,
    'org_id': orgId,
    'start_date': '2026-10-01',
    'deadline': deadline,
    'wages': '15000',
  };

  setUp(() async {
    db = await openTestDb();
    controller = ProjectController(db);
    checklists = ChecklistController(db);
    orgId = (await OrganizerController(db).createOrganizer({
      'org_name': 'ACME',
      'contact_name': 'Som',
      'color': '#FF5733',
    })).orgId;
  });

  group('validate', () {
    final valid = {
      'project_name': 'Website',
      'org_id': 1,
      'start_date': '2026-10-01',
      'deadline': '2026-11-30',
      'wages': 15000,
    };

    test('passes for valid input; deadline is optional', () {
      expect(controller.validate(valid), isEmpty);
      expect(controller.validate({...valid, 'deadline': null}), isEmpty);
    });

    test('fails when required fields are empty', () {
      expect(
        controller.validate({}).keys,
        containsAll(['project_name', 'org_id', 'start_date', 'wages']),
      );
    });

    test('fails when wages is not a number', () {
      expect(
        controller.validate({...valid, 'wages': 'abc'}),
        contains('wages'),
      );
    });

    test('fails on impossible dates and deadline before start', () {
      expect(
        controller.validate({...valid, 'start_date': '2026-02-31'}),
        contains('start_date'),
      );
      expect(
        controller.validate({...valid, 'deadline': '2026-09-01'}),
        contains('deadline'),
      );
    });
  });

  group('createProject', () {
    test('saves with status in_progress and loads its organizer', () async {
      final project = await controller.createProject(body('Website'));

      expect(project.status, ProjectStatus.inProgress);
      expect(project.wages, 15000);
      expect(project.startDate, DateTime(2026, 10));
      expect(project.organizer!.orgName, 'ACME');
      expect(project.progress, 0);
    });

    test('throws 400 when invalid', () {
      expect(
        () => controller.createProject({...body('x'), 'project_name': ''}),
        throwsAppException(400, field: 'project_name'),
      );
    });

    test('throws 400 when organizer does not exist', () async {
      await expectLater(
        controller.createProject({...body('x'), 'org_id': 999}),
        throwsAppException(400, field: 'org_id'),
      );
    });

    test('throws 409 when name is taken for the same organizer', () async {
      await controller.createProject(body('Website'));
      await expectLater(
        controller.createProject(body('Website')),
        throwsAppException(409, field: 'project_name'),
      );
    });
  });

  test('progress comes from SQL over the project checklist', () async {
    final project = await controller.createProject(body('Website'));
    final type = await checklists.createChecklist({
      'name': 'Web',
      'steps': ['a', 'b', 'c'],
    });
    await checklists.addChecklistToProject(project.projectId, {
      'type_id': type.typeId,
    });
    await checklists.updateChecklist(
      project.projectId,
      type.checklists.first.checklistId,
      {},
    );

    final loaded = await controller.getProject(project.projectId);
    expect(loaded.progress, 33.33);
    expect(loaded.checklists.first.checklist!.name, 'a');
    expect(loaded.checklists.first.completed, isTrue);
  });

  group('status transitions', () {
    test('full path: submit → fail → submit → pass → confirm', () async {
      final id = (await controller.createProject(body('Website'))).projectId;
      await readyToSubmit(db, id);

      final submitted = await controller.submitProject(id);
      expect(submitted.status, ProjectStatus.pending);
      expect(submitted.submittedAt, isNotNull);
      expect(
        (await controller.failProject(id)).status,
        ProjectStatus.inProgress,
      );
      await controller.submitProject(id);
      expect(
        (await controller.passProject(id)).status,
        ProjectStatus.submitted,
      );
      final paid = await controller.confirmPayment(id);
      expect(paid.status, ProjectStatus.completed);
      expect(paid.paidAt, isNotNull);
    });

    test('throws 409 for transitions that are not allowed', () async {
      final id = (await controller.createProject(body('Website'))).projectId;
      await expectLater(controller.passProject(id), throwsAppException(409));
      await expectLater(controller.failProject(id), throwsAppException(409));
      await expectLater(controller.confirmPayment(id), throwsAppException(409));
      expect(
        (await controller.getProject(id)).status,
        ProjectStatus.inProgress,
      );
    });

    test('throws 404 for unknown project', () async {
      await expectLater(controller.submitProject(99), throwsAppException(404));
    });
  });

  group('saveNote', () {
    test('saves the trimmed note', () async {
      final id = (await controller.createProject(body('Website'))).projectId;
      final project = await controller.saveNote(id, {'note': ' แก้สีปุ่ม '});
      expect(project.note, 'แก้สีปุ่ม');
    });

    test('throws 400 when note is missing', () {
      expect(
        () => controller.saveNote(1, {}),
        throwsAppException(400, field: 'note'),
      );
    });
  });

  test('getProjects skips completed work and puts no-deadline last', () async {
    await controller.createProject(body('No deadline'));
    await controller.createProject(body('Later', deadline: '2026-12-31'));
    await controller.createProject(body('Sooner', deadline: '2026-11-01'));
    final done = await controller.createProject(body('Done'));
    await readyToSubmit(db, done.projectId);
    for (final step in [
      controller.submitProject,
      controller.passProject,
      controller.confirmPayment,
    ]) {
      await step(done.projectId);
    }

    final projects = await controller.getProjects();
    expect(
      [for (final p in projects) p.projectName],
      ['Sooner', 'Later', 'No deadline'],
    );
  });

  test('getHistory lists paid work newest first with its rating', () async {
    Future<int> complete(String name) async {
      final id = (await controller.createProject(body(name))).projectId;
      await readyToSubmit(db, id);
      await controller.submitProject(id);
      await controller.passProject(id);
      await controller.confirmPayment(id);
      return id;
    }

    final first = await complete('First');
    await complete('Second');
    await RatingController(db).saveRating(first, {'score': 4});

    final history = await controller.getHistory();
    expect([for (final p in history) p.projectName], ['Second', 'First']);
    expect(history.last.rating!.score, 4);
    expect(history.first.rating, isNull);
  });

  group('submit needs a finished checklist', () {
    test('throws 409 when the project has no checklist', () async {
      final id = (await controller.createProject(body('Website'))).projectId;
      await expectLater(controller.submitProject(id), throwsAppException(409));
    });

    test('throws 409 until every step is ticked, then submits', () async {
      final id = (await controller.createProject(body('Website'))).projectId;
      final type = await checklists.createChecklist({
        'name': 'Web',
        'steps': ['a', 'b'],
      });
      await checklists.addChecklistToProject(id, {'type_id': type.typeId});
      await checklists.updateChecklist(
        id,
        type.checklists.first.checklistId,
        {},
      );

      await expectLater(controller.submitProject(id), throwsAppException(409));
      expect(
        (await controller.getProject(id)).status,
        ProjectStatus.inProgress,
      );

      await checklists.updateChecklist(
        id,
        type.checklists.last.checklistId,
        {},
      );
      expect(
        (await controller.submitProject(id)).status,
        ProjectStatus.pending,
      );
    });
  });

  group('updateProject', () {
    test('saves the new details', () async {
      final id = (await controller.createProject(body('Website'))).projectId;

      final updated = await controller.updateProject(id, {
        ...body('Website v2', deadline: '2026-12-01'),
        'wages': '20000',
      });

      expect(updated.projectName, 'Website v2');
      expect(updated.deadline, DateTime(2026, 12));
      expect(updated.wages, 20000);
      expect(updated.status, ProjectStatus.inProgress);
    });

    test('keeps its own name but rejects another project\'s', () async {
      final id = (await controller.createProject(body('Website'))).projectId;
      await controller.createProject(body('Logo'));

      await controller.updateProject(id, body('Website'));
      await expectLater(
        controller.updateProject(id, body('Logo')),
        throwsAppException(409, field: 'project_name'),
      );
    });

    test('throws 400 when invalid and 404 when missing', () async {
      final id = (await controller.createProject(body('Website'))).projectId;
      await expectLater(
        controller.updateProject(id, {...body('x'), 'wages': 'abc'}),
        throwsAppException(400, field: 'wages'),
      );
      await expectLater(
        controller.updateProject(99, body('x')),
        throwsAppException(404),
      );
    });

    test('throws 409 for a completed project', () async {
      final id = (await controller.createProject(body('Website'))).projectId;
      await readyToSubmit(db, id);
      await controller.submitProject(id);
      await controller.passProject(id);
      await controller.confirmPayment(id);

      await expectLater(
        controller.updateProject(id, body('Website v2')),
        throwsAppException(409),
      );
    });
  });

  group('deleteProject', () {
    test('deletes the project with its checklist steps', () async {
      final id = (await controller.createProject(body('Website'))).projectId;
      await readyToSubmit(db, id);

      await controller.deleteProject(id);

      expect(await db.select('projects', {}), isEmpty);
      expect(await db.select('project_checklists', {}), isEmpty);
    });

    test('drops its rating from the organizer average', () async {
      Future<int> rated(String name, int score) async {
        final id = (await controller.createProject(body(name))).projectId;
        await readyToSubmit(db, id);
        await controller.submitProject(id);
        await controller.passProject(id);
        await controller.confirmPayment(id);
        await RatingController(db).saveRating(id, {'score': score});
        return id;
      }

      await rated('A', 5);
      final low = await rated('B', 2);
      expect((await db.select('organizers', {})).single['rate'], 3.5);

      await controller.deleteProject(low);

      expect((await db.select('organizers', {})).single['rate'], 5);
      expect(await db.select('ratings', {}), hasLength(1));
    });

    test('throws 404 when missing', () async {
      await expectLater(controller.deleteProject(99), throwsAppException(404));
    });
  });
}
