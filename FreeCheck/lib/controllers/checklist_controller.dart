import '../core/app_exception.dart';
import '../core/validators.dart';
import '../services/database_service.dart';
import '../models/models.dart';

class ChecklistController {
  ChecklistController(this._db);

  final DatabaseService _db;

  /// Percentage of a project's steps that are completed (0 when none).
  /// `completed` is 0/1, so SUM(completed) counts the completed steps.
  /// ProjectController uses the same expression when it loads projects.
  static const _progressSql =
      'SELECT ROUND(COALESCE(100.0 * SUM(completed) '
      '/ NULLIF(COUNT(*), 0), 0), 2) AS progress_percent '
      'FROM project_checklists WHERE project_id = ?';

  /// Returns field errors for a checklist type body; empty when valid.
  ///
  /// Errors for individual steps use the key `steps.<index>`.
  Map<String, String> validate(Map<String, dynamic> body) {
    final errors = <String, String>{};

    final name = textOf(body['name']);
    if (name == null) {
      errors['name'] = 'กรุณากรอกชื่อประเภทงาน';
    } else if (name.length > 255) {
      errors['name'] = 'ชื่อประเภทงานยาวเกิน 255 ตัวอักษร';
    }

    final steps = body['steps'];
    if (steps is! List || steps.isEmpty) {
      errors['steps'] = 'ต้องมีขั้นตอนอย่างน้อย 1 รายการ';
    } else {
      for (var i = 0; i < steps.length; i++) {
        final step = steps[i];
        final text = step is String ? textOf(step) : null;
        if (text == null) {
          errors['steps.$i'] = 'กรุณากรอกชื่อขั้นตอน';
        } else if (text.length > 255) {
          errors['steps.$i'] = 'ชื่อขั้นตอนยาวเกิน 255 ตัวอักษร';
        }
      }
    }

    return errors;
  }

  /// Inserts the type and all its steps in one transaction.
  Future<Type> createChecklist(Map<String, dynamic> body) async {
    final errors = validate(body);
    if (errors.isNotEmpty) throw AppException.validation(errors);

    final name = textOf(body['name'])!;
    final steps = [for (final s in body['steps'] as List) textOf(s)!];

    if (await _db.exists('types', {'name': name})) {
      throw AppException.conflict(
        'มีประเภทงานชื่อนี้อยู่แล้ว',
        fields: {'name': 'มีประเภทงานชื่อนี้อยู่แล้ว'},
      );
    }

    late int typeId;
    final created = <Checklist>[];
    await _db.transaction((tx) async {
      typeId = await tx.insert('types', {'name': name}, idColumn: 'type_id');
      for (final step in steps) {
        final id = await tx.insert('checklists', {
          'type_id': typeId,
          'name': step,
        }, idColumn: 'checklist_id');
        created.add(Checklist(checklistId: id, typeId: typeId, name: step));
      }
    });
    return Type(typeId: typeId, name: name, checklists: created);
  }

  Future<List<Type>> getTypes() async {
    final types = await _db.select('types', {}, orderBy: 'name');
    if (types.isEmpty) return [];
    final steps = await _db.select('checklists', {
      'type_id': [for (final t in types) t['type_id']],
    }, orderBy: 'checklist_id');
    return [
      for (final t in types)
        Type.fromJson({
          ...t,
          'checklists': [
            for (final s in steps)
              if (s['type_id'] == t['type_id']) s,
          ],
        }),
    ];
  }

  /// Copies the steps of a type into the project (completed = false).
  /// A project may use several types; steps it already has are skipped.
  Future<List<ProjectChecklist>> addChecklistToProject(
    int projectId,
    Map<String, dynamic> body,
  ) async {
    final typeId = intOf(body['type_id']);
    if (typeId == null) {
      throw AppException.validation({'type_id': 'กรุณาเลือกประเภทงาน'});
    }

    await _requireOpenProject(projectId);
    if (!await _db.exists('types', {'type_id': typeId})) {
      throw AppException.notFound('ไม่พบประเภทงานนี้');
    }

    final steps = await _db.select(
      'checklists',
      {'type_id': typeId},
      columns: ['checklist_id'],
    );
    final existing = await _db.select(
      'project_checklists',
      {'project_id': projectId},
      columns: ['checklist_id'],
    );
    final existingIds = {for (final r in existing) r['checklist_id']};
    final newSteps = [
      for (final step in steps)
        if (!existingIds.contains(step['checklist_id'])) step,
    ];
    if (newSteps.isEmpty) {
      throw AppException.conflict('งานนี้มีขั้นตอนของ Checklist นี้ครบแล้ว');
    }

    await _db.transaction((tx) async {
      for (final step in newSteps) {
        await tx.insert('project_checklists', {
          'project_id': projectId,
          'checklist_id': step['checklist_id'],
          'completed': false,
        }, idColumn: 'checklist_id');
      }
    });
    return getProjectChecklists(projectId);
  }

  /// Removes every step of a type from the project.
  Future<void> removeChecklistFromProject(
    int projectId,
    Map<String, dynamic> query,
  ) async {
    final typeId = intOf(query['type_id']);
    if (typeId == null) {
      throw AppException.validation({'type_id': 'กรุณาเลือกประเภทงาน'});
    }

    await _requireOpenProject(projectId);

    final steps = await _db.select(
      'checklists',
      {'type_id': typeId},
      columns: ['checklist_id'],
    );
    final where = {
      'project_id': projectId,
      'checklist_id': [for (final s in steps) s['checklist_id']],
    };
    if (steps.isEmpty || !await _db.exists('project_checklists', where)) {
      throw AppException.notFound('งานนี้ไม่มี Checklist ประเภทนี้');
    }
    await _db.delete('project_checklists', where);
  }

  Future<List<ProjectChecklist>> getProjectChecklists(int projectId) async {
    if (!await _db.exists('projects', {'project_id': projectId})) {
      throw AppException.notFound('ไม่พบงานนี้');
    }
    final rows = await _db.select('project_checklists', {
      'project_id': projectId,
    }, orderBy: 'checklist_id');
    if (rows.isEmpty) return [];
    final steps = await _db.select('checklists', {
      'checklist_id': [for (final r in rows) r['checklist_id']],
    });
    final stepById = {for (final s in steps) s['checklist_id']: s};
    return [
      for (final r in rows)
        ProjectChecklist.fromJson({
          ...r,
          'checklist': stepById[r['checklist_id']],
        }),
    ];
  }

  /// Marks a step done (or not done when `completed` is false) and
  /// returns the value of [getProgress].
  Future<num> updateChecklist(
    int projectId,
    int checklistId,
    Map<String, dynamic> body,
  ) async {
    final completed = body['completed'] ?? true;
    if (completed is! bool) {
      throw AppException.validation({
        'completed': 'ค่าต้องเป็น true หรือ false',
      });
    }
    final key = {'project_id': projectId, 'checklist_id': checklistId};
    if (!await _db.exists('project_checklists', key)) {
      throw AppException.notFound('ไม่พบขั้นตอนนี้ในงาน');
    }
    await _db.update('project_checklists', key, {'completed': completed});
    return getProgress(projectId);
  }

  /// Percentage (0–100) of the project's steps that are completed.
  Future<num> getProgress(int projectId) async {
    final rows = await _db.query(_progressSql, [projectId]);
    return rows.first['progress_percent'] as num;
  }

  Future<void> _requireOpenProject(int projectId) async {
    final rows = await _db.select('projects', {'project_id': projectId});
    if (rows.isEmpty) throw AppException.notFound('ไม่พบงานนี้');
    if (rows.first['status'] == ProjectStatus.completed.value) {
      throw AppException.conflict('งานนี้เสร็จสิ้นแล้ว');
    }
  }
}
