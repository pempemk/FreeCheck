part of 'page.dart';

const _palette = [
  Color(0xFF6C5CE7),
  Color(0xFF4FA37E),
  Color(0xFFE0974B),
  Color(0xFFD9636E),
  Color(0xFF4A7BD6),
  Color(0xFF4338CA),
  Color(0xFFD16BA5),
  Color(0xFF2FA4A9),
];

/// Adds a new organizer, or edits [organizer] when given.
class OrganizerFormPage extends Page<void> {
  OrganizerFormPage({required super.db, Organizer? organizer})
    : _editing = organizer;

  final Organizer? _editing;
  late final _orgName = TextEditingController(text: _editing?.orgName);
  late final _contactName = TextEditingController(text: _editing?.contactName);
  late final _phone = TextEditingController(text: _editing?.phone);
  late Color _color = _editing == null
      ? _palette.first
      : colorFromHex(_editing.color);

  @override
  void dispose() {
    _orgName.dispose();
    _contactName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickCustomColor() async {
    var picked = _color;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เลือกสี'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _color,
            onColorChanged: (c) => picked = c,
            enableAlpha: false,
            hexInputBar: true,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
    if (ok ?? false) setState(() => _color = picked.withAlpha(255));
  }

  Future<void> _delete() => _deleteFlow(
    title: 'ลบ Organizer',
    message: 'ลบ "${_editing!.orgName}" ใช่หรือไม่ ลบแล้วกู้คืนไม่ได้',
    delete: () => _organizers.deleteOrganizer(_editing.orgId),
  );

  Future<void> _save() async {
    final body = {
      'org_name': _orgName.text,
      'contact_name': _contactName.text,
      'phone': _phone.text,
      'color': colorToHex(_color),
    };
    final editing = _editing;
    final organizer = await _run(
      () => editing == null
          ? _organizers.createOrganizer(body)
          : _organizers.updateOrganizer(editing.orgId, body),
      success: 'บันทึก Organizer เรียบร้อยแล้ว',
    );
    if (organizer != null && mounted) Navigator.pop(context, organizer);
  }

  @override
  Widget build(BuildContext context) {
    final custom = !_palette.any((c) => c.toARGB32() == _color.toARGB32());
    return _screen(
      context,
      title: _editing == null ? 'เพิ่ม Organizer' : 'แก้ไข Organizer',
      subtitle: _editing == null
          ? 'บันทึกข้อมูลผู้ว่าจ้างใหม่'
          : 'แก้ไขข้อมูลผู้ว่าจ้าง',
      loading: _loading,
      action: _editing == null
          ? null
          : _deleteButton('ลบ Organizer', _loading ? null : _delete),
      bottom: _primaryButton(
        _editing == null ? 'บันทึก Organizer' : 'บันทึกการแก้ไข',
        _loading ? null : _save,
      ),
      children: [
        _fieldLabel('ชื่อบริษัท'),
        TextField(
          controller: _orgName,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'กรอกชื่อบริษัท / Organizer',
            errorText: fieldErrors['org_name'],
          ),
        ),
        const SizedBox(height: 20),
        _fieldLabel('ชื่อผู้ติดต่อ'),
        TextField(
          controller: _contactName,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: 'กรอกชื่อผู้ติดต่อ',
            errorText: fieldErrors['contact_name'],
          ),
        ),
        const SizedBox(height: 20),
        _fieldLabel('เบอร์โทรศัพท์'),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: InputDecoration(
            hintText: 'ตัวเลข 0-9 ไม่เกิน 10 หลัก',
            errorText: fieldErrors['phone'],
          ),
        ),
        const SizedBox(height: 20),
        _fieldLabel('สีประจำ Organizer'),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final c in _palette)
              _swatch(
                color: c,
                selected: c.toARGB32() == _color.toARGB32(),
                onTap: () => setState(() => _color = c),
              ),
            _swatch(
              color: custom ? _color : Colors.white,
              selected: custom,
              onTap: _pickCustomColor,
              tooltip: 'เลือกสีอื่น',
              icon: Icons.palette_outlined,
            ),
          ],
        ),
        _fieldError(fieldErrors['color']),
        if (_editing == null) ...[
          const SizedBox(height: 20),
          const Text(
            'คะแนนเริ่มต้นของ Organizer จะเป็น 0',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
        ],
      ],
    );
  }

  Widget _swatch({
    required Color color,
    required bool selected,
    required VoidCallback onTap,
    String? tooltip,
    IconData? icon,
  }) {
    return Tooltip(
      message: tooltip ?? colorToHex(color),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 56,
            height: 56,
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 28)
                : icon == null
                ? null
                : Icon(icon, color: _muted),
          ),
        ),
      ),
    );
  }
}
