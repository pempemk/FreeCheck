part of 'page.dart';

typedef _ChecklistDetail = ({Type type, List<Project> projects});

/// A checklist template, read-only, with the projects that use it.
/// Editing starts from the pencil in the header.
class ChecklistDetailPage extends Page<_ChecklistDetail> {
  ChecklistDetailPage({required int typeId, required super.db})
    : _typeId = typeId;

  final int _typeId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() => _load(() async {
    final (types, active, history) = await (
      _checklists.getTypes(),
      _projects.getProjects(),
      _projects.getHistory(),
    ).wait;
    final type = types.where((t) => t.typeId == _typeId).firstOrNull;
    if (type == null) throw AppException.notFound('ไม่พบ Checklist นี้');
    return (
      type: type,
      projects: [
        for (final p in [...active, ...history])
          if (p.checklists.any((c) => c.checklist?.typeId == _typeId)) p,
      ],
    );
  });

  Future<void> _edit() async {
    await _openPage(() => ChecklistFormPage(db: _db, type: data!.type));
    if (!mounted) return;
    // The checklist may have been deleted from the edit screen.
    final types = await _checklists.getTypes();
    if (!mounted) return;
    if (!types.any((t) => t.typeId == _typeId)) {
      Navigator.pop(context);
      return;
    }
    await _refresh();
  }

  Future<void> _openProject(Project project) async {
    await _openPage(
      () => ProjectDetailPage(projectId: project.projectId, db: _db),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    if (d == null) return _loadingScaffold(onRetry: _refresh);
    final steps = d.type.checklists;

    return _screen(
      context,
      title: 'รายละเอียด Checklist',
      subtitle: 'ขั้นตอนการทำงานของแม่แบบนี้',
      loading: _loading,
      onRefresh: _refresh,
      action: IconButton(
        tooltip: 'แก้ไข Checklist',
        onPressed: _loading ? null : _edit,
        icon: const Icon(Icons.edit_outlined, color: _ink),
      ),
      children: [
        _surface(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '✦ ${d.type.name}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${steps.length} ขั้นตอน • ใช้กับ ${d.projects.length} โปรเจกต์',
                style: const TextStyle(color: _muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _sectionTitle('ขั้นตอนการทำงาน'),
        const SizedBox(height: 12),
        for (var i = 0; i < steps.length; i++) ...[
          _surface(
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _purpleSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    steps[i].name,
                    style: const TextStyle(fontSize: 16, color: _ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 18),
        _sectionTitle('โปรเจกต์ที่ใช้ Checklist นี้'),
        const SizedBox(height: 12),
        if (d.projects.isEmpty)
          _emptyCard(
            'ยังไม่มีโปรเจกต์ที่ใช้',
            'กด เลือกใช้งาน ในหน้าแม่แบบ Checklist เพื่อใช้กับโปรเจกต์',
          ),
        for (final p in d.projects) ...[
          _projectCard(p, onTap: () => _openProject(p)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
