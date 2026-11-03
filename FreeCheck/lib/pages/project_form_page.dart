part of 'page.dart';

class ProjectFormPage extends Page<List<Organizer>> {
  ProjectFormPage({required super.db});

  final _name = TextEditingController();
  final _wages = TextEditingController();
  int? _orgId;
  DateTime? _startDate = DateUtils.dateOnly(DateTime.now());
  DateTime? _deadline;

  @override
  void initState() {
    super.initState();
    _loadOrganizers();
  }

  @override
  void dispose() {
    _name.dispose();
    _wages.dispose();
    super.dispose();
  }

  Future<void> _loadOrganizers() => _load(_organizers.getOrganizers);

  Future<void> _addOrganizer() async {
    final created = await showForm(organizerFormRoute);
    if (created is! Organizer) return;
    await _loadOrganizers();
    setState(() => _orgId = created.orgId);
  }

  Future<DateTime?> _pickDate(DateTime? initial, {DateTime? first}) {
    return showDatePicker(
      context: context,
      initialDate: initial ?? first ?? DateTime.now(),
      firstDate: first ?? DateTime(2000),
      lastDate: DateTime(2100),
    );
  }

  Future<void> _save() async {
    final project = await _run(
      () => _projects.createProject({
        'project_name': _name.text,
        'org_id': _orgId,
        'start_date': _startDate == null ? null : toApiDate(_startDate!),
        'deadline': _deadline == null ? null : toApiDate(_deadline!),
        'wages': _wages.text.replaceAll(',', ''),
      }),
      success: 'บันทึกโปรเจกต์เรียบร้อยแล้ว',
    );
    if (project != null && mounted) Navigator.pop(context, project);
  }

  @override
  Widget build(BuildContext context) {
    final organizers = data;
    if (organizers == null) return _loadingScaffold(onRetry: _loadOrganizers);

    return _screen(
      context,
      title: 'เพิ่มโปรเจกต์ใหม่',
      subtitle: 'บันทึกรายละเอียดงานที่ได้รับ',
      loading: _loading,
      bottom: _primaryButton('บันทึกโปรเจกต์', _loading ? null : _save),
      children: [
        _fieldLabel('ชื่อโปรเจกต์'),
        TextField(
          controller: _name,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'กรอกชื่อโปรเจกต์',
            errorText: fieldErrors['project_name'],
          ),
        ),
        const SizedBox(height: 20),
        _fieldLabel('Organizer / ผู้ว่าจ้าง'),
        DropdownButtonFormField<int>(
          key: ValueKey(_orgId),
          initialValue: _orgId,
          isExpanded: true,
          borderRadius: BorderRadius.circular(16),
          dropdownColor: Colors.white,
          hint: const Text('เลือก Organizer'),
          decoration: InputDecoration(errorText: fieldErrors['org_id']),
          items: [
            for (final o in organizers)
              DropdownMenuItem(
                value: o.orgId,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 6,
                      backgroundColor: colorFromHex(o.color),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(o.orgName, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (v) => setState(() => _orgId = v),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _addOrganizer,
            child: const Text('+ เพิ่ม Organizer ใหม่'),
          ),
        ),
        const SizedBox(height: 4),
        _fieldLabel('วันที่เริ่มงาน'),
        _dateField(
          value: _startDate,
          hint: 'เลือกวันที่เริ่มงาน',
          error: fieldErrors['start_date'],
          onTap: () async {
            final d = await _pickDate(_startDate);
            if (d != null) setState(() => _startDate = d);
          },
        ),
        const SizedBox(height: 20),
        _fieldLabel('กำหนดส่ง (ไม่บังคับ)'),
        _dateField(
          value: _deadline,
          hint: 'เลือกวันที่กำหนดส่ง',
          error: fieldErrors['deadline'],
          onTap: () async {
            final d = await _pickDate(_deadline, first: _startDate);
            if (d != null) setState(() => _deadline = d);
          },
          onClear: _deadline == null
              ? null
              : () => setState(() => _deadline = null),
        ),
        const SizedBox(height: 20),
        _fieldLabel('ค่าจ้าง (บาท)'),
        TextField(
          controller: _wages,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '0.00',
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 20, right: 8),
              child: Text('฿', style: TextStyle(fontSize: 16, color: _ink)),
            ),
            prefixIconConstraints: const BoxConstraints(),
            errorText: fieldErrors['wages'],
          ),
        ),
        const SizedBox(height: 24),
        _surface(
          color: _purpleSoft,
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: _primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'หลังบันทึก สถานะเริ่มต้นคือ “กำลังทำ”',
                  style: TextStyle(color: _primary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dateField({
    required DateTime? value,
    required String hint,
    required VoidCallback onTap,
    String? error,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        isEmpty: value == null,
        decoration: InputDecoration(
          hintText: hint,
          errorText: error,
          suffixIcon: onClear == null
              ? const Icon(Icons.calendar_month_outlined, color: _muted)
              : IconButton(
                  tooltip: 'ล้าง',
                  icon: const Icon(Icons.close, color: _muted),
                  onPressed: onClear,
                ),
        ),
        child: value == null
            ? null
            : Text(formatDate(value), style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
