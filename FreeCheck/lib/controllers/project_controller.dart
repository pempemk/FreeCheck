import '../core/app_exception.dart';
import '../core/validators.dart';
import '../services/database_connector.dart';
import '../models/models.dart';

class ProjectController {
  ProjectController(this._db);

  final DatabaseConnector _db;

  /// Projects with `progress_percent`, using the same expression as
  /// ChecklistController.getProgress (0 for projects without steps).
  static const _projectsWithProgressSql = '''
SELECT p.*, COALESCE(pr.progress_percent, 0) AS progress_percent
FROM projects p
LEFT JOIN (
  SELECT project_id,
         ROUND(COALESCE(100.0 * SUM(completed)
               / NULLIF(COUNT(*), 0), 0), 2) AS progress_percent
  FROM project_checklists
  GROUP BY project_id
) pr ON pr.project_id = p.project_id''';

  static const _labels = {
    ProjectStatus.inProgress: 'กำลังทำงาน',
    ProjectStatus.pending: 'รอตรวจสอบงาน',
    ProjectStatus.submitted: 'รอรับเงิน',
    ProjectStatus.completed: 'เสร็จสิ้น',
  };

  /// Returns field errors for a project body; empty when valid.
  Map<String, String> validate(Map<String, dynamic> body) {
    final errors = <String, String>{};

    final name = textOf(body['project_name']);
    if (name == null) {
      errors['project_name'] = 'กรุณากรอกชื่องาน';
    } else if (name.length > 200) {
      errors['project_name'] = 'ชื่องานยาวเกิน 200 ตัวอักษร';
    }

    if (textOf(body['org_id']) == null) {
      errors['org_id'] = 'กรุณาเลือก Organizer';
    } else if (intOf(body['org_id']) == null) {
      errors['org_id'] = 'Organizer ไม่ถูกต้อง';
    }

    final startDate = dateOf(body['start_date']);
    if (textOf(body['start_date']) == null) {
      errors['start_date'] = 'กรุณาเลือกวันที่เริ่มงาน';
    } else if (startDate == null) {
      errors['start_date'] = 'วันที่ต้องอยู่ในรูปแบบ YYYY-MM-DD';
    }

    if (textOf(body['deadline']) != null) {
      final deadline = dateOf(body['deadline']);
      if (deadline == null) {
        errors['deadline'] = 'วันที่ต้องอยู่ในรูปแบบ YYYY-MM-DD';
      } else if (startDate != null && deadline.isBefore(startDate)) {
        errors['deadline'] = 'กำหนดส่งต้องไม่ก่อนวันที่เริ่มงาน';
      }
    }

    final wages = numOf(body['wages']);
    if (textOf(body['wages']) == null) {
      errors['wages'] = 'กรุณากรอกค่าจ้าง';
    } else if (wages == null || wages.isNaN || wages.isInfinite) {
      errors['wages'] = 'ค่าจ้างต้องเป็นตัวเลข';
    } else if (wages < 0) {
      errors['wages'] = 'ค่าจ้างต้องไม่ติดลบ';
    } else if (wages >= 1e10) {
      errors['wages'] = 'ค่าจ้างสูงเกินไป';
    } else if (wages != num.parse(wages.toStringAsFixed(2))) {
      errors['wages'] = 'ค่าจ้างมีทศนิยมได้ไม่เกิน 2 ตำแหน่ง';
    }

    return errors;
  }

  Future<Project> createProject(Map<String, dynamic> body) async {
    final errors = validate(body);
    if (errors.isNotEmpty) throw AppException.validation(errors);

    final data = _fields(body);
    await _checkOrganizerAndName(data);
    final id = await _db.save('projects', {
      ...data,
      'status': ProjectStatus.inProgress.value,
    }, idColumn: 'project_id');
    return getProject(id);
  }

  /// Saves new details for a project that is not completed yet.
  Future<Project> updateProject(int id, Map<String, dynamic> body) async {
    final errors = validate(body);
    if (errors.isNotEmpty) throw AppException.validation(errors);

    final project = await getProject(id);
    if (project.status == ProjectStatus.completed) {
      throw AppException.conflict('งานที่เสร็จสิ้นแล้วแก้ไขไม่ได้');
    }
    final data = _fields(body);
    await _checkOrganizerAndName(data, exceptId: id);
    await _db.update('projects', {'project_id': id}, data);
    return getProject(id);
  }

  Map<String, Object?> _fields(Map<String, dynamic> body) => {
    'project_name': textOf(body['project_name']),
    'org_id': intOf(body['org_id']),
    'start_date': textOf(body['start_date']),
    'deadline': textOf(body['deadline']),
    'wages': numOf(body['wages']),
  };

  /// The organizer must exist, and a project name may be used once per
  /// organizer and start date.
  Future<void> _checkOrganizerAndName(
    Map<String, Object?> data, {
    int? exceptId,
  }) async {
    if (!await _db.checkDuplicate('organizers', {'org_id': data['org_id']})) {
      throw AppException.validation({'org_id': 'ไม่พบ Organizer ที่เลือก'});
    }
    final sameName = await _db.select('projects', {
      'project_name': data['project_name'],
      'org_id': data['org_id'],
      'start_date': data['start_date'],
    });
    if (sameName.any((p) => p['project_id'] != exceptId)) {
      const message =
          'มีงานชื่อนี้ของ Organizer นี้ในวันที่เริ่มงานเดียวกันแล้ว';
      throw AppException.conflict(message, fields: {'project_name': message});
    }
  }

  /// Deletes a project with its checklist steps and rating. The
  /// organizer's average rate is recalculated without it.
  Future<void> deleteProject(int id) async {
    final rows = await _db.select('projects', {'project_id': id});
    if (rows.isEmpty) throw AppException.notFound('ไม่พบงานนี้');
    final orgId = rows.single['org_id'];

    await _db.transaction((tx) async {
      await tx.delete('project_checklists', {'project_id': id});
      await tx.delete('ratings', {'project_id': id});
      await tx.delete('projects', {'project_id': id});
      final avg = await tx.select(
        'ratings',
        {'org_id': orgId},
        columns: ['COALESCE(AVG(score), 0) AS avg_score'],
      );
      final rate = (avg.first['avg_score'] as num).toStringAsFixed(2);
      await tx.update(
        'organizers',
        {'org_id': orgId},
        {'rate': num.parse(rate)},
      );
    });
  }

  /// Projects that are not completed yet.
  Future<List<Project>> getProjects() async {
    final rows = await _db.query(
      '$_projectsWithProgressSql '
      'WHERE p.status IN (?, ?, ?) '
      // SQLite sorts NULL first; projects without a deadline go last.
      'ORDER BY p.deadline IS NULL, p.deadline',
      [
        for (final s in ProjectStatus.values)
          if (s != ProjectStatus.completed) s.value,
      ],
    );
    return _load(rows);
  }

  /// One project with its organizer, checklist steps and rating.
  Future<Project> getProject(int id) async {
    final rows = await _db.query(
      '$_projectsWithProgressSql '
      'WHERE p.project_id = ?',
      [id],
    );
    if (rows.isEmpty) throw AppException.notFound('ไม่พบงานนี้');
    return (await _load(rows)).single;
  }

  /// in_progress → pending.
  Future<Project> submitProject(int id) =>
      _changeStatus(id, ProjectStatus.pending);

  /// pending → in_progress.
  Future<Project> failProject(int id) =>
      _changeStatus(id, ProjectStatus.inProgress);

  /// Save the revision note / organizer feedback.
  Future<Project> saveNote(int id, Map<String, dynamic> body) async {
    final note = body['note'];
    if (note is! String) {
      throw AppException.validation({'note': 'กรุณากรอกบันทึก'});
    }
    if (!await _db.checkDuplicate('projects', {'project_id': id})) {
      throw AppException.notFound('ไม่พบงานนี้');
    }
    await _db.update('projects', {'project_id': id}, {'note': note.trim()});
    return getProject(id);
  }

  /// pending → submitted.
  Future<Project> passProject(int id) =>
      _changeStatus(id, ProjectStatus.submitted);

  /// submitted → completed.
  Future<Project> confirmPayment(int id) =>
      _changeStatus(id, ProjectStatus.completed);

  /// Completed projects, most recently paid first.
  Future<List<Project>> getHistory() async {
    final rows = await _db.query(
      '$_projectsWithProgressSql '
      'WHERE p.status = ? ORDER BY p.paid_at DESC, p.project_id DESC',
      [ProjectStatus.completed.value],
    );
    return _load(rows);
  }

  /// Moves a project to [next] if [Project.canChangeTo] allows it.
  Future<Project> _changeStatus(int id, ProjectStatus next) async {
    final project = await getProject(id);
    if (!project.canChangeTo(next)) {
      throw AppException.conflict(
        'ไม่สามารถเปลี่ยนสถานะจาก "${_labels[project.status]}" '
        'เป็น "${_labels[next]}" ได้',
      );
    }
    if (next == ProjectStatus.pending) {
      if (project.checklists.isEmpty) {
        throw AppException.conflict('ต้องเพิ่ม Checklist ก่อนส่งงาน');
      }
      if (project.progress < 100) {
        throw AppException.conflict('ต้องทำ Checklist ให้ครบ 100% ก่อนส่งงาน');
      }
    }

    final now = DateTime.now().toUtc();
    // Including the old status in WHERE keeps a concurrent change from
    // being overwritten.
    await _db.update(
      'projects',
      {'project_id': id, 'status': project.status.value},
      {
        'status': next.value,
        if (next == ProjectStatus.pending) 'submitted_at': now,
        if (next == ProjectStatus.completed) 'paid_at': now,
      },
    );
    final updated = await getProject(id);
    if (updated.status != next) {
      throw AppException.conflict('สถานะของงานถูกเปลี่ยนไปแล้ว');
    }
    return updated;
  }

  /// Builds [Project]s from rows (which already include progress_percent),
  /// loading their organizer, checklist steps and rating with one query per
  /// table.
  Future<List<Project>> _load(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return [];
    final ids = [for (final r in rows) r['project_id']];

    final organizers = await _db.select('organizers', {
      'org_id': {for (final r in rows) r['org_id']}.toList(),
    });
    final items = await _db.select('project_checklists', {
      'project_id': ids,
    }, orderBy: 'checklist_id');
    final steps = items.isEmpty
        ? <Map<String, dynamic>>[]
        : await _db.select('checklists', {
            'checklist_id': {for (final i in items) i['checklist_id']}.toList(),
          });
    final ratings = await _db.select('ratings', {'project_id': ids});

    final organizerById = {for (final o in organizers) o['org_id']: o};
    final stepById = {for (final s in steps) s['checklist_id']: s};
    final ratingByProject = {for (final r in ratings) r['project_id']: r};

    return [
      for (final row in rows)
        Project.fromJson({
          ...row,
          'organizer': organizerById[row['org_id']],
          'checklists': [
            for (final i in items)
              if (i['project_id'] == row['project_id'])
                {...i, 'checklist': stepById[i['checklist_id']]},
          ],
          'rating': ratingByProject[row['project_id']],
        }),
    ];
  }
}
