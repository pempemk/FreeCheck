import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_tracker/controllers/organizer_controller.dart';
import 'package:freelance_tracker/controllers/project_controller.dart';
import 'package:freelance_tracker/controllers/rating_controller.dart';
import 'package:freelance_tracker/services/database_service.dart';

import '../support.dart';

void main() {
  late DatabaseService db;
  late RatingController controller;
  late ProjectController projects;
  late int orgId;

  Future<int> project(String name, {bool complete = true}) async {
    final id = (await projects.createProject({
      'project_name': name,
      'org_id': orgId,
      'start_date': '2026-10-01',
      'wages': 1000,
    })).projectId;
    if (complete) {
      await readyToSubmit(db, id);
      await projects.submitProject(id);
      await projects.passProject(id);
      await projects.confirmPayment(id);
    }
    return id;
  }

  setUp(() async {
    db = await openTestDb();
    controller = RatingController(db);
    projects = ProjectController(db);
    orgId = (await OrganizerController(db).createOrganizer({
      'org_name': 'ACME',
      'contact_name': 'Som',
      'color': '#FF5733',
    })).orgId;
  });

  group('validate', () {
    test('passes for 1 to 5', () {
      for (var s = 1; s <= 5; s++) {
        expect(controller.validate({'score': s}), isEmpty);
      }
    });

    test('fails when empty, out of range, or not an integer', () {
      for (final s in [null, '', 0, 6, 3.5, '3']) {
        expect(
          controller.validate({'score': s}),
          contains('score'),
          reason: '$s',
        );
      }
    });
  });

  group('saveRating', () {
    test('saves the rating and sets the organizer average', () async {
      final first = await project('First');
      final second = await project('Second');

      final rating = await controller.saveRating(first, {'score': 5});
      expect(rating.score, 5);
      expect(rating.orgId, orgId);
      await controller.saveRating(second, {'score': 4});

      final org = await db.select('organizers', {'org_id': orgId});
      expect(org.single['rate'], 4.5);
    });

    test('throws 400 and saves nothing when score is invalid', () async {
      final id = await project('First');
      await expectLater(
        controller.saveRating(id, {'score': 0}),
        throwsAppException(400, field: 'score'),
      );
      expect(await db.select('ratings', {}), isEmpty);
    });

    test('throws 404 for unknown project', () async {
      await expectLater(
        controller.saveRating(99, {'score': 5}),
        throwsAppException(404),
      );
    });

    test('throws 409 when project is not completed', () async {
      final id = await project('Open', complete: false);
      await expectLater(
        controller.saveRating(id, {'score': 5}),
        throwsAppException(409),
      );
    });

    test('throws 409 when project was already rated', () async {
      final id = await project('First');
      await controller.saveRating(id, {'score': 5});
      await expectLater(
        controller.saveRating(id, {'score': 3}),
        throwsAppException(409),
      );
    });
  });
}
