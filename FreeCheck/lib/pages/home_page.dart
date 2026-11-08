part of 'page.dart';

typedef _HomeData = ({
  List<Project> active,
  List<Project> history,
  List<Type> types,
  List<Organizer> organizers,
});

/// The app shell with four tabs — dashboard, projects,
/// checklist templates and organizers.
class HomePage extends Page<_HomeData> {
  HomePage({required super.db});

  int _tab = 0;
  ProjectStatus? _statusFilter;
  final _projectSearch = TextEditingController();
  final _organizerSearch = TextEditingController();

  @override
  void initState() {
    super.initState();
    _projectSearch.addListener(() => setState(() {}));
    _organizerSearch.addListener(() => setState(() {}));
    _refresh();
  }

  @override
  void dispose() {
    _projectSearch.dispose();
    _organizerSearch.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _load(() async {
    final (active, history, types, organizers) = await (
      _projects.getProjects(),
      _projects.getHistory(),
      _checklists.getTypes(),
      _organizers.getOrganizers(),
    ).wait;
    return (
      active: active,
      history: history,
      types: types,
      organizers: organizers,
    );
  });

  Future<void> _openForm(String name) async {
    final created = await showForm(name);
    if (created != null) await _refresh();
  }

  Future<void> _openProject(Project project) async {
    await _openPage(
      () => ProjectDetailPage(projectId: project.projectId, db: _db),
    );
    await _refresh();
  }

  Future<void> _openHistory() async {
    await _openPage(() => HistoryPage(db: _db));
    await _refresh();
  }

  Future<void> _openOrganizer(Organizer organizer) async {
    await _openPage(() => OrganizerDetailPage(orgId: organizer.orgId, db: _db));
    await _refresh();
  }

  Future<void> _openTemplate(Type type) async {
    await _openPage(() => ChecklistDetailPage(typeId: type.typeId, db: _db));
    await _refresh();
  }

  void _showProjects({ProjectStatus? status}) => setState(() {
    _tab = 1;
    _statusFilter = status;
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _buildLoaded(
          onRetry: _refresh,
          (d) => switch (_tab) {
            0 => _dashboard(d),
            1 => _projectsTab(d),
            2 => _templates(d),
            _ => _organizersTab(d),
          },
        ),
      ),
      bottomNavigationBar: _navigationBar(),
    );
  }

  Widget _navigationBar() {
    return NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (i) => setState(() => _tab = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'หน้าแรก',
        ),
        NavigationDestination(
          icon: Icon(Icons.view_list_outlined),
          selectedIcon: Icon(Icons.view_list_rounded),
          label: 'โปรเจกต์',
        ),
        NavigationDestination(
          icon: Icon(Icons.grid_on_outlined),
          selectedIcon: Icon(Icons.grid_on_rounded),
          label: 'เช็กลิสต์',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'ลูกค้า',
        ),
      ],
    );
  }

  Widget _dashboard(_HomeData d) {
    final total = d.history.fold<num>(0, (sum, p) => sum + p.wages);
    final inProgress = d.active
        .where((p) => p.status == ProjectStatus.inProgress)
        .length;
    final pending = d.active
        .where((p) => p.status == ProjectStatus.pending)
        .length;
    final awaiting = [
      for (final p in d.active)
        if (p.status == ProjectStatus.submitted) p,
    ];

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const Text(
            'FreeCheck',
            style: TextStyle(
              color: _primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'สวัสดี 👋 วันนี้พร้อมลุยงานไหม?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'ภาพรวมงานและรายได้ของคุณ',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 20),
          _financeCard(
            earned: total,
            awaiting: awaiting.fold<num>(0, (sum, p) => sum + p.wages),
            awaitingCount: awaiting.length,
            note: _incomeTrend(d.history),
            onTap: _openHistory,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statTile(
                inProgress,
                'กำลังทำ',
                _primary,
                () => _showProjects(status: ProjectStatus.inProgress),
              ),
              const SizedBox(width: 12),
              _statTile(
                pending,
                'รอตรวจ',
                _orange,
                () => _showProjects(status: ProjectStatus.pending),
              ),
              const SizedBox(width: 12),
              _statTile(d.history.length, 'เสร็จสิ้น', _green, _openHistory),
            ],
          ),
          const SizedBox(height: 28),
          _sectionTitle(
            'โปรเจกต์ที่ต้องติดตาม',
            trailing: TextButton(
              onPressed: _showProjects,
              child: const Text('ดูทั้งหมด'),
            ),
          ),
          const SizedBox(height: 12),
          if (d.active.isEmpty)
            _emptyCard(
              'ยังไม่มีงานที่กำลังทำ',
              'เพิ่มโปรเจกต์แรกเพื่อเริ่มติดตามงาน',
              action: _softButton(
                'เพิ่ม Project',
                () => _openForm(projectFormRoute),
              ),
            ),
          for (final p in d.active.take(5)) ...[
            _projectCard(p, onTap: () => _openProject(p), shortDate: true),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  /// This month's income compared with last month's.
  String _incomeTrend(List<Project> history) {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    num paidIn(DateTime month) => history
        .where((p) {
          final paid = p.paidAt?.toLocal();
          return paid != null &&
              paid.year == month.year &&
              paid.month == month.month;
        })
        .fold<num>(0, (sum, p) => sum + p.wages);

    final current = paidIn(now);
    final previous = paidIn(lastMonth);
    if (previous > 0) {
      final change = (current - previous) / previous * 100;
      final arrow = change >= 0 ? '↗ +' : '↘ ';
      return '$arrow${change.toStringAsFixed(1)}% จากเดือนก่อน';
    }
    return current > 0
        ? 'เดือนนี้ ${formatBaht(current)}'
        : 'ยังไม่มีรายได้เดือนนี้';
  }

  Widget _statTile(int count, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: _surface(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count.toString().padLeft(2, '0'),
              style: TextStyle(
                color: color,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: _muted)),
          ],
        ),
      ),
    );
  }

  Widget _projectsTab(_HomeData d) {
    final query = _projectSearch.text.trim().toLowerCase();
    final all = [...d.active, ...d.history];
    final shown = [
      for (final p in all)
        if ((_statusFilter == null || p.status == _statusFilter) &&
            (query.isEmpty ||
                p.projectName.toLowerCase().contains(query) ||
                (p.organizer?.orgName.toLowerCase().contains(query) ?? false)))
          p,
    ];

    Widget filter(String label, ProjectStatus? status) {
      final selected = _statusFilter == status;
      final style = status == null
          ? (color: _primary, soft: _purpleSoft)
          : (
              color: _statusStyle(status).color,
              soft: _statusStyle(status).soft,
            );
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: _pill(
          label,
          color: selected ? Colors.white : style.color,
          background: selected ? style.color : style.soft,
          onTap: () => setState(() => _statusFilter = status),
        ),
      );
    }

    return _screenBody(
      context,
      back: false,
      title: 'โปรเจกต์ของฉัน',
      subtitle: 'จัดการทุกงานในที่เดียว',
      onRefresh: _refresh,
      bottom: _primaryButton(
        'เพิ่ม Project',
        () => _openForm(projectFormRoute),
      ),
      children: [
        TextField(
          controller: _projectSearch,
          decoration: const InputDecoration(
            hintText: 'ค้นหาชื่อโปรเจกต์...',
            prefixIcon: Icon(Icons.search, color: _muted),
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              filter('ทั้งหมด ${all.length}', null),
              for (final s in [
                ProjectStatus.inProgress,
                ProjectStatus.pending,
                ProjectStatus.submitted,
                ProjectStatus.completed,
              ])
                filter(_statusStyle(s).label, s),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (shown.isEmpty)
          _emptyCard(
            all.isEmpty ? 'ยังไม่มีโปรเจกต์' : 'ไม่พบโปรเจกต์',
            all.isEmpty
                ? 'กดปุ่ม เพิ่ม Project เพื่อเพิ่มโปรเจกต์แรก'
                : 'ลองเปลี่ยนคำค้นหาหรือตัวกรอง',
          ),
        for (final p in shown) ...[
          _projectCard(p, onTap: () => _openProject(p)),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _templates(_HomeData d) {
    final all = [...d.active, ...d.history];
    int usedBy(Type type) => all
        .where(
          (p) => p.checklists.any((c) => c.checklist?.typeId == type.typeId),
        )
        .length;

    return _screenBody(
      context,
      back: false,
      title: 'แม่แบบ Checklist',
      subtitle: 'สร้างรายการขั้นตอนที่ใช้ซ้ำได้',
      onRefresh: _refresh,
      bottom: _primaryButton(
        'สร้าง Checklist',
        () => _openForm(checklistFormRoute),
      ),
      children: [
        if (d.types.isEmpty)
          _emptyCard(
            'ยังไม่มีแม่แบบ Checklist',
            'สร้างขั้นตอนการทำงานไว้ใช้ซ้ำกับหลายโปรเจกต์',
          ),
        for (final t in d.types) ...[
          _surface(
            padding: const EdgeInsets.all(24),
            onTap: _loading ? null : () => _openTemplate(t),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '✦ ${t.name}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${t.checklists.length} ขั้นตอน • ใช้กับ ${usedBy(t)} โปรเจกต์',
                  style: const TextStyle(color: _muted),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill(
                      'เลือกใช้งาน',
                      color: _primary,
                      background: _purpleSoft,
                      onTap: _loading ? null : () => _applyTemplate(t, d),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  /// Pick an open project to copy [type]'s steps into.
  Future<void> _applyTemplate(Type type, _HomeData d) async {
    // A project has one checklist, so only projects without one qualify.
    final candidates = [
      for (final p in d.active)
        if (p.checklists.isEmpty) p,
    ];
    if (candidates.isEmpty) {
      _alert.showMessage('ทุกโปรเจกต์ที่กำลังทำมี Checklist แล้ว');
      return;
    }

    final project = await _selectSheet<Project>(
      context,
      title: 'เลือกใช้งาน "${type.name}"',
      items: candidates,
      label: (p) => p.projectName,
      detail: (p) => p.organizer?.orgName ?? '',
    );
    if (project is! Project) return;

    final items = await _run(
      () => _checklists.addChecklistToProject(project.projectId, {
        'type_id': type.typeId,
      }),
      success: 'บันทึกสำเร็จ',
    );
    if (items != null) await _refresh();
  }

  Widget _organizersTab(_HomeData d) {
    final query = _organizerSearch.text.trim().toLowerCase();
    final shown = [
      for (final o in d.organizers)
        if (query.isEmpty ||
            o.orgName.toLowerCase().contains(query) ||
            o.contactName.toLowerCase().contains(query))
          o,
    ];

    return _screenBody(
      context,
      back: false,
      title: 'Organizer',
      subtitle: 'รายชื่อผู้ว่าจ้างและข้อมูลติดต่อ',
      onRefresh: _refresh,
      bottom: _primaryButton(
        'เพิ่ม Organizer',
        () => _openForm(organizerFormRoute),
      ),
      children: [
        TextField(
          controller: _organizerSearch,
          decoration: const InputDecoration(
            hintText: 'ค้นหา Organizer...',
            prefixIcon: Icon(Icons.search, color: _muted),
          ),
        ),
        const SizedBox(height: 20),
        if (shown.isEmpty)
          _emptyCard(
            d.organizers.isEmpty ? 'ยังไม่มี Organizer' : 'ไม่พบ Organizer',
            d.organizers.isEmpty
                ? 'เพิ่มผู้ว่าจ้างคนแรกของคุณ'
                : 'ลองเปลี่ยนคำค้นหา',
          ),
        for (final o in shown) ...[
          _surface(
            padding: const EdgeInsets.all(24),
            onTap: () => _openOrganizer(o),
            child: Row(
              children: [
                _organizerAvatar(o),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.orgName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${o.contactName} • ${formatPhone(o.phone)}',
                        style: const TextStyle(color: _muted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '★ ${o.rate.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: _orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: _muted),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
