part of 'page.dart';

typedef _Detail = ({Project project, List<Type> types});

/// [project] with its checklist steps replaced by [items] and [progress].
Project _withChecklists(
  Project project,
  List<ProjectChecklist> items,
  num progress,
) => Project(
  projectId: project.projectId,
  orgId: project.orgId,
  projectName: project.projectName,
  startDate: project.startDate,
  deadline: project.deadline,
  wages: project.wages,
  status: project.status,
  submittedAt: project.submittedAt,
  paidAt: project.paidAt,
  note: project.note,
  organizer: project.organizer,
  checklists: items,
  rating: project.rating,
  progress: progress,
);

/// While the work is being reviewed (pending) this shows the submission
/// tracking layout instead of the project detail.
class ProjectDetailPage extends Page<_Detail> {
  ProjectDetailPage({required int projectId, required super.db})
    : _projectId = projectId;

  final int _projectId;
  final _note = TextEditingController();

  Project get _project => data!.project;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _load(() async {
    final (project, types) = await (
      _projects.getProject(_projectId),
      _checklists.getTypes(),
    ).wait;
    _note.text = project.note;
    return (project: project, types: types);
  });

  void _showProject(Project project) {
    showData((project: project, types: data!.types));
    _note.text = project.note;
  }

  Future<void> _pickChecklist(List<Type> available) async {
    final choice = await showModalBottomSheet<Object>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _project.checklists.isEmpty
                    ? 'เลือก Checklist'
                    : 'เปลี่ยนเป็น Checklist',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ),
            for (final t in available)
              ListTile(
                leading: const Text('✦', style: TextStyle(fontSize: 18)),
                title: Text(t.name),
                subtitle: Text('${t.checklists.length} ขั้นตอน'),
                onTap: () => Navigator.pop(context, t),
              ),
            ListTile(
              leading: const Icon(Icons.add, color: _primary),
              title: const Text(
                'สร้าง Checklist ใหม่',
                style: TextStyle(color: _primary),
              ),
              onTap: () => Navigator.pop(context, checklistFormRoute),
            ),
          ],
        ),
      ),
    );
    if (choice is Type) return _addChecklist(choice);
    if (choice == checklistFormRoute) {
      final created = await showForm(checklistFormRoute);
      if (created is Type) await _addChecklist(created);
    }
  }

  /// Uses [type] as the project's checklist, replacing the current one
  /// (a project has only one).
  Future<void> _addChecklist(Type type) async {
    final current = {
      for (final item in _project.checklists)
        if (item.checklist != null) item.checklist!.typeId,
    };
    if (current.isNotEmpty) {
      final ok = await _confirm(
        context,
        title: 'เปลี่ยน Checklist',
        message:
            'เปลี่ยนเป็น "${type.name}" ใช่หรือไม่ '
            'ขั้นตอนและสถานะที่ติ๊กไว้ของอันเดิมจะหายไป',
        confirmLabel: 'เปลี่ยน',
      );
      if (!ok) return;
    }
    // Reload the project (for its progress) and the types (a new one may
    // have just been created).
    final result = await _run(() async {
      for (final typeId in current) {
        await _checklists.removeChecklistFromProject(_projectId, {
          'type_id': typeId,
        });
      }
      await _checklists.addChecklistToProject(_projectId, {
        'type_id': type.typeId,
      });
      return (_projects.getProject(_projectId), _checklists.getTypes()).wait;
    }, success: 'ใช้ Checklist "${type.name}" เรียบร้อยแล้ว');
    if (result == null) return;
    final (project, types) = result;
    showData((project: project, types: types));
  }

  Future<void> _removeChecklist(Type type) async {
    final ok = await _confirm(
      context,
      title: 'ลบ Checklist',
      message:
          'ลบขั้นตอนทั้งหมดของ "${type.name}" ออกจากงานนี้ใช่หรือไม่ '
          'สถานะที่ติ๊กไว้จะหายไปด้วย',
      confirmLabel: 'ลบ',
    );
    if (!ok) return;
    final project = await _run(() async {
      await _checklists.removeChecklistFromProject(_projectId, {
        'type_id': type.typeId,
      });
      return _projects.getProject(_projectId);
    }, success: 'ลบ Checklist เรียบร้อยแล้ว');
    if (project != null) _showProject(project);
  }

  Future<void> _toggle(ProjectChecklist item) async {
    final completed = !item.completed;
    final progress = await _run(
      () => _checklists.updateChecklist(_projectId, item.checklistId, {
        'completed': completed,
      }),
    );
    if (progress == null) return;
    final items = [
      for (final i in _project.checklists)
        i.checklistId == item.checklistId
            ? ProjectChecklist(
                projectId: i.projectId,
                checklistId: i.checklistId,
                completed: completed,
                checklist: i.checklist,
              )
            : i,
    ];
    _showProject(_withChecklists(_project, items, progress));
  }

  Future<void> _submit() async {
    final ok = await _confirm(
      context,
      title: 'ส่งงานให้ Organizer',
      message:
          'ส่งงานให้ ${_project.organizer?.orgName ?? 'Organizer'} '
          'ตรวจสอบใช่หรือไม่',
      confirmLabel: 'ส่งงาน',
    );
    if (!ok) return;
    final project = await _run(
      () => _projects.submitProject(_projectId),
      success: 'ส่งงานแล้ว รอผลการตรวจ',
    );
    if (project != null) _showProject(project);
  }

  // Back to work, saving the note typed on the tracking screen.
  Future<void> _fail() async {
    final note = _note.text;
    final project = await _run(() async {
      var project = await _projects.failProject(_projectId);
      if (note.trim() != project.note) {
        project = await _projects.saveNote(_projectId, {'note': note});
      }
      return project;
    }, success: 'บันทึกแล้ว กลับไปแก้ไขงาน');
    if (project != null) _showProject(project);
  }

  Future<void> _saveNote() async {
    final project = await _run(
      () => _projects.saveNote(_projectId, {'note': _note.text}),
      success: 'บันทึกโน้ตเรียบร้อยแล้ว',
    );
    if (project != null) _showProject(project);
  }

  Future<void> _pass() async {
    final ok = await _confirm(
      context,
      title: 'ผ่านการตรวจ',
      message: 'ยืนยันว่า Organizer ตรวจรับงานแล้ว สถานะจะเปลี่ยนเป็นรอรับเงิน',
    );
    if (!ok) return;
    final project = await _run(
      () => _projects.passProject(_projectId),
      success: 'งานผ่านแล้ว รอรับเงิน',
    );
    if (project != null) _showProject(project);
  }

  Future<void> _confirmPayment() async {
    final paid = await _confirmPaymentFlow(_project);
    if (paid != null && mounted) Navigator.pop(context);
  }

  Future<void> _rate() async {
    if (await _rateFlow(_project)) await _refresh();
  }

  Future<void> _delete() => _deleteFlow(
    title: 'ลบโปรเจกต์',
    message:
        'ลบ "${_project.projectName}" พร้อม Checklist และคะแนนของงานนี้'
        'ใช่หรือไม่ ลบแล้วกู้คืนไม่ได้',
    delete: () => _projects.deleteProject(_projectId),
  );

  Future<void> _edit() async {
    await _openPage(() => ProjectFormPage(db: _db, project: _project));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    if (d == null) return _loadingScaffold(onRetry: _refresh);
    final tracking = d.project.status == ProjectStatus.pending;
    // A new key per layout so switching layouts starts at the top.
    return KeyedSubtree(
      key: ValueKey(tracking),
      child: tracking ? _trackingScreen(d.project) : _detailScreen(d),
    );
  }

  Widget _trackingScreen(Project project) {
    final submitted = project.submittedAt == null
        ? ''
        : ' · ${formatDateTime(project.submittedAt)}';
    return _screen(
      context,
      title: 'ติดตามการส่งงาน',
      subtitle: 'จัดการการตรวจรับและแก้ไขงาน',
      loading: _loading,
      onRefresh: _refresh,
      children: [
        _surface(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                project.projectName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ส่งให้ ${project.organizer?.orgName ?? 'Organizer'} '
                'ตรวจแล้ว$submitted',
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 16),
              _statusChip(ProjectStatus.pending, label: 'รอผลการตรวจ'),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _sectionTitle(
          'ผลการตรวจจาก Organizer',
          subtitle: 'บันทึกผลเมื่อได้รับการตอบกลับจากลูกค้า',
        ),
        const SizedBox(height: 20),
        _decisionTile(
          icon: Icons.check_rounded,
          title: 'ผ่านการตรวจ',
          subtitle: 'เปลี่ยนสถานะเป็นรอรับเงิน',
          color: _green,
          background: _greenSoft,
          onTap: _pass,
        ),
        const SizedBox(height: 14),
        _decisionTile(
          icon: Icons.refresh_rounded,
          title: 'ต้องแก้ไข',
          subtitle: 'บันทึกคำแนะนำและกลับไปทำงานต่อ',
          color: _red,
          background: _redSoft,
          onTap: _fail,
        ),
        const SizedBox(height: 32),
        _fieldLabel('หมายเหตุสำหรับการแก้ไข'),
        TextField(
          controller: _note,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: 'กรอกรายละเอียดที่ต้องปรับแก้...',
            errorText: fieldErrors['note'],
          ),
        ),
      ],
    );
  }

  Widget _decisionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color background,
    required VoidCallback onTap,
  }) {
    return _surface(
      color: background,
      padding: const EdgeInsets.all(24),
      onTap: _loading ? null : onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailScreen(_Detail d) {
    final project = d.project;
    final editable = project.status != ProjectStatus.completed;
    final deadline = project.deadline;
    final overdue =
        deadline != null &&
        deadline.isBefore(DateUtils.dateOnly(DateTime.now())) &&
        project.status == ProjectStatus.inProgress;

    // Group steps under the type they came from.
    final typeById = {for (final t in d.types) t.typeId: t};
    final groups = <int?, List<ProjectChecklist>>{};
    for (final item in project.checklists) {
      groups.putIfAbsent(item.checklist?.typeId, () => []).add(item);
    }
    final available = [
      for (final t in d.types)
        if (!groups.containsKey(t.typeId)) t,
    ];

    return _screen(
      context,
      title: 'รายละเอียดโปรเจกต์',
      subtitle:
          '${project.organizer?.orgName ?? '-'} · '
          '${formatDateRange(project.startDate, deadline)}',
      loading: _loading,
      onRefresh: _refresh,
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (editable)
            IconButton(
              tooltip: 'แก้ไขโปรเจกต์',
              onPressed: _loading ? null : _edit,
              icon: const Icon(Icons.edit_outlined, color: _ink),
            ),
          _deleteButton('ลบโปรเจกต์', _loading ? null : _delete),
        ],
      ),
      bottom: _detailAction(project),
      children: [
        _surface(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statusChip(project.status),
              const SizedBox(height: 16),
              Text(
                project.projectName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'ค่าจ้าง  ${formatBaht(project.wages)}',
                style: const TextStyle(
                  color: _primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                deadline == null
                    ? 'ไม่มีกำหนดส่ง'
                    : 'กำหนดส่ง ${formatDate(deadline)}',
                style: TextStyle(color: overdue ? _red : _muted),
              ),
              if (project.paidAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'รับเงินเมื่อ ${formatDateTime(project.paidAt)}',
                    style: const TextStyle(color: _muted),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            const Expanded(
              child: Text(
                'ความคืบหน้างาน',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ),
            Text(
              '${project.progress.round()}%',
              style: const TextStyle(
                color: _primary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _progressBar(project.progress, _primary, height: 12),
        const SizedBox(height: 28),
        _sectionTitle('รายการ Checklist'),
        const SizedBox(height: 12),
        if (project.checklists.isEmpty)
          _emptyCard(
            'ยังไม่มี Checklist',
            'เลือกแม่แบบขั้นตอนการทำงานให้โปรเจกต์นี้',
          ),
        for (final MapEntry(key: typeId, value: steps) in groups.entries) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  typeById[typeId]?.name ?? 'อื่น ๆ',
                  style: const TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (editable && typeById[typeId] != null)
                IconButton(
                  tooltip: 'ลบ Checklist นี้ออกจากงาน',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, color: _muted),
                  onPressed: _loading
                      ? null
                      : () => _removeChecklist(typeById[typeId]!),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (final item in steps) ...[
            _checkRow(item, enabled: editable),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
        ],
        if (editable) ...[
          const SizedBox(height: 6),
          _softButton(
            project.checklists.isEmpty
                ? '+ เพิ่ม Checklist'
                : 'เปลี่ยน Checklist',
            _loading ? null : () => _pickChecklist(available),
          ),
        ],
        const SizedBox(height: 28),
        _fieldLabel('บันทึก / คำแนะนำจาก Organizer'),
        TextField(
          controller: _note,
          enabled: editable,
          minLines: 2,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: 'จดสิ่งที่ต้องแก้ไข หรือรายละเอียดเพิ่มเติม',
            errorText: fieldErrors['note'],
          ),
        ),
        if (editable)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _loading ? null : _saveNote,
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึกโน้ต'),
            ),
          ),
      ],
    );
  }

  Widget _checkRow(ProjectChecklist item, {required bool enabled}) {
    return Semantics(
      checked: item.completed,
      child: _surface(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        onTap: enabled && !_loading ? () => _toggle(item) : null,
        child: Row(
          children: [
            Icon(
              item.completed
                  ? Icons.check_rounded
                  : Icons.radio_button_unchecked,
              color: item.completed ? _green : _muted,
              size: 26,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                item.checklist?.name ?? '',
                style: const TextStyle(fontSize: 16, color: _ink),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Submitting is only possible once every checklist step is done.
  Widget _submitAction(Project project) {
    final ready = project.checklists.isNotEmpty && project.progress >= 100;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!ready)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              project.checklists.isEmpty
                  ? 'เพิ่ม Checklist ก่อนส่งงาน'
                  : 'ทำ Checklist ให้ครบ 100% ก่อนส่งงาน',
              style: const TextStyle(color: _muted),
            ),
          ),
        _primaryButton(
          'ส่งงานให้ Organizer',
          ready && !_loading ? _submit : null,
        ),
      ],
    );
  }

  Widget? _detailAction(Project project) => switch (project.status) {
    ProjectStatus.inProgress => _submitAction(project),
    ProjectStatus.submitted => _primaryButton(
      'ยืนยันรับเงิน',
      _loading ? null : _confirmPayment,
      color: _green,
    ),
    ProjectStatus.completed =>
      project.rating == null
          ? _primaryButton(
              '★ ให้คะแนน Organizer',
              _loading ? null : _rate,
              color: _orange,
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('ให้คะแนนแล้ว  ', style: TextStyle(color: _muted)),
                _stars(project.rating!.score, size: 24),
              ],
            ),
    ProjectStatus.pending => null,
  };
}
