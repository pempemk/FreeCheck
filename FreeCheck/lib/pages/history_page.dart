part of 'page.dart';

typedef _History = ({List<Project> awaiting, List<Project> done});

/// Money waiting to be paid and finished work.
class HistoryPage extends Page<_History> {
  HistoryPage({required super.db});

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() => _load(() async {
    final (active, done) = await (
      _projects.getProjects(),
      _projects.getHistory(),
    ).wait;
    return (
      awaiting: [
        for (final p in active)
          if (p.status == ProjectStatus.submitted) p,
      ],
      done: done,
    );
  });

  Future<void> _confirmPayment(Project project) async {
    if (await _confirmPaymentFlow(project) != null) await _refresh();
  }

  Future<void> _rate(Project project) async {
    if (await _rateFlow(project)) await _refresh();
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

    final waiting = d.awaiting.fold<num>(0, (sum, p) => sum + p.wages);
    final earned = d.done.fold<num>(0, (sum, p) => sum + p.wages);

    return _screen(
      context,
      title: 'การเงินและประวัติ',
      subtitle: 'ติดตามยอดค้างชำระและงานที่สำเร็จ',
      loading: _loading,
      onRefresh: _refresh,
      children: [
        _financeCard(
          earned: earned,
          awaiting: waiting,
          awaitingCount: d.awaiting.length,
        ),
        const SizedBox(height: 32),
        _sectionTitle('รอรับเงิน'),
        const SizedBox(height: 14),
        if (d.awaiting.isEmpty)
          _emptyCard('ไม่มีงานที่รอรับเงิน', 'งานที่ผ่านแล้วจะแสดงที่นี่'),
        for (final p in d.awaiting) ...[
          _surface(
            padding: const EdgeInsets.all(24),
            onTap: () => _openProject(p),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title(p.projectName),
                const SizedBox(height: 6),
                Text(
                  '${p.organizer?.orgName ?? '-'}  •  ${formatBaht(p.wages)}',
                  style: const TextStyle(color: _muted),
                ),
                const SizedBox(height: 14),
                _pill(
                  'ยืนยันรับเงิน',
                  color: _green,
                  background: _greenSoft,
                  onTap: _loading ? null : () => _confirmPayment(p),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 16),
        _sectionTitle('ประวัติงานที่เสร็จสิ้น'),
        const SizedBox(height: 14),
        if (d.done.isEmpty)
          _emptyCard(
            'ยังไม่มีงานที่เสร็จสิ้น',
            'งานที่ยืนยันรับเงินแล้วจะแสดงที่นี่',
          ),
        for (final p in d.done) ...[
          _surface(
            padding: const EdgeInsets.all(24),
            onTap: () => _openProject(p),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title(p.projectName),
                const SizedBox(height: 6),
                Text(
                  '${p.organizer?.orgName ?? '-'}  •  ${formatBaht(p.wages)}  •  '
                  'รับเงิน ${formatShortDate(p.paidAt)}',
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (p.rating != null)
                  _stars(p.rating!.score)
                else
                  _pill(
                    'ให้คะแนน',
                    color: _orange,
                    background: _orangeSoft,
                    onTap: _loading ? null : () => _rate(p),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _title(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: _ink,
    ),
  );
}
