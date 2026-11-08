part of 'page.dart';

typedef _OrganizerDetail = ({Organizer organizer, List<Project> projects});

/// An organizer's contact details and every project done for them.
/// Editing starts from the pencil in the header.
class OrganizerDetailPage extends Page<_OrganizerDetail> {
  OrganizerDetailPage({required int orgId, required super.db}) : _orgId = orgId;

  final int _orgId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() => _load(() async {
    final (organizers, active, history) = await (
      _organizers.getOrganizers(),
      _projects.getProjects(),
      _projects.getHistory(),
    ).wait;
    final organizer = organizers.where((o) => o.orgId == _orgId).firstOrNull;
    if (organizer == null) throw AppException.notFound('ไม่พบ Organizer นี้');
    return (
      organizer: organizer,
      projects: [
        for (final p in [...active, ...history])
          if (p.orgId == _orgId) p,
      ],
    );
  });

  Future<void> _edit() async {
    await _openPage(
      () => OrganizerFormPage(db: _db, organizer: data!.organizer),
    );
    if (!mounted) return;
    // The organizer may have been deleted from the edit screen.
    final organizers = await _organizers.getOrganizers();
    if (!mounted) return;
    if (!organizers.any((o) => o.orgId == _orgId)) {
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
    final o = d.organizer;
    final earned = d.projects
        .where((p) => p.status == ProjectStatus.completed)
        .fold<num>(0, (sum, p) => sum + p.wages);

    return _screen(
      context,
      title: 'รายละเอียด Organizer',
      subtitle: 'ข้อมูลผู้ว่าจ้างและโปรเจกต์',
      loading: _loading,
      onRefresh: _refresh,
      action: IconButton(
        tooltip: 'แก้ไข Organizer',
        onPressed: _loading ? null : _edit,
        icon: const Icon(Icons.edit_outlined, color: _ink),
      ),
      children: [
        _surface(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              _organizerAvatar(o, size: 72),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.orgName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _infoLine(Icons.person_outline_rounded, o.contactName),
                    _infoLine(Icons.phone_outlined, formatPhone(o.phone)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _stars(o.rate, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          o.rate.toStringAsFixed(2),
                          style: const TextStyle(
                            color: _orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _stat('${d.projects.length}', 'โปรเจกต์ทั้งหมด', _primary),
            const SizedBox(width: 12),
            _stat(formatBaht(earned), 'รายได้ที่ได้รับแล้ว', _green),
          ],
        ),
        const SizedBox(height: 28),
        _sectionTitle('โปรเจกต์'),
        const SizedBox(height: 12),
        if (d.projects.isEmpty)
          _emptyCard(
            'ยังไม่มีโปรเจกต์',
            'โปรเจกต์ของ Organizer นี้จะแสดงที่นี่',
          ),
        for (final p in d.projects) ...[
          _projectCard(p, onTap: () => _openProject(p)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _infoLine(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Row(
      children: [
        Icon(icon, size: 16, color: _muted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text, style: const TextStyle(color: _muted)),
        ),
      ],
    ),
  );

  Widget _stat(String value, String label, Color color) => Expanded(
    child: _surface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: _muted)),
        ],
      ),
    ),
  );
}
