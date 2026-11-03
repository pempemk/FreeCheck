import 'package:freelance_tracker/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Project project(ProjectStatus status) => Project(
  projectId: 1,
  orgId: 1,
  projectName: 'Website',
  startDate: DateTime(2026, 10),
  wages: 100,
  status: status,
);

void main() {
  group('Project.canChangeTo', () {
    const allowed = {
      (ProjectStatus.inProgress, ProjectStatus.pending),
      (ProjectStatus.pending, ProjectStatus.inProgress),
      (ProjectStatus.pending, ProjectStatus.submitted),
      (ProjectStatus.submitted, ProjectStatus.completed),
    };

    for (final from in ProjectStatus.values) {
      for (final to in ProjectStatus.values) {
        final expected = allowed.contains((from, to));
        test('${from.name} -> ${to.name} is $expected', () {
          expect(project(from).canChangeTo(to), expected);
        });
      }
    }
  });

  test('Project round-trips through snake_case JSON', () {
    final json = {
      'project_id': 3,
      'org_id': 2,
      'project_name': 'Website',
      'start_date': '2026-10-01',
      'deadline': null,
      'wages': 1500.5,
      'status': 'in_progress',
      'submitted_at': '2026-10-26T16:35:12.446Z',
      'paid_at': null,
      'note': 'x',
      'organizer': {
        'org_id': 2,
        'org_name': 'ACME',
        'contact_name': 'Som',
        'phone': null,
        'color': '#FF5733',
        'rate': 4.5,
      },
      'checklists': [
        {
          'project_id': 3,
          'checklist_id': 9,
          'completed': true,
          'checklist': {'checklist_id': 9, 'type_id': 1, 'name': 'ออกแบบ'},
        },
      ],
      'rating': {'rating_id': 1, 'project_id': 3, 'org_id': 2, 'score': 5},
      'progress_percent': 100,
    };

    final p = Project.fromJson(json);
    expect(p.projectName, 'Website');
    expect(p.status, ProjectStatus.inProgress);
    expect(p.organizer!.orgName, 'ACME');
    expect(p.checklists.single.checklist!.name, 'ออกแบบ');
    expect(p.rating!.score, 5);
    expect(p.progress, 100);

    final back = p.toJson();
    expect(back['start_date'], '2026-10-01');
    expect(back['status'], 'in_progress');
    expect(back['progress_percent'], 100);
    expect(Project.fromJson(back).toJson(), back);
  });

  test('Type parses its checklists', () {
    final t = Type.fromJson({
      'type_id': 1,
      'name': 'เว็บไซต์',
      'checklists': [
        {'checklist_id': 1, 'type_id': 1, 'name': 'ออกแบบ'},
      ],
    });
    expect(t.checklists.single.name, 'ออกแบบ');
    expect(Type.fromJson(t.toJson()).toJson(), t.toJson());
  });

  test('ProjectChecklist reads SQLite 0/1 as completed', () {
    final done = ProjectChecklist.fromJson({
      'project_id': 1,
      'checklist_id': 2,
      'completed': 1,
    });
    final open = ProjectChecklist.fromJson({
      'project_id': 1,
      'checklist_id': 3,
      'completed': 0,
    });
    expect(done.completed, isTrue);
    expect(open.completed, isFalse);
  });
}
