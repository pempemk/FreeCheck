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
}
