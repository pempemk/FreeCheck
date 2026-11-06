part of 'page.dart';

/// Creates a checklist template, or edits [type] when given.
class ChecklistFormPage extends Page<void> {
  ChecklistFormPage({required super.db, Type? type}) : _editing = type;

  final Type? _editing;
  late final _name = TextEditingController(text: _editing?.name);

  /// Each row keeps the id of the step it edits; null for new steps.
  late final _steps = <({int? id, TextEditingController text})>[
    for (final c in _editing?.checklists ?? const <Checklist>[])
      (id: c.checklistId, text: TextEditingController(text: c.name)),
    if (_editing == null || _editing.checklists.isEmpty)
      (id: null, text: TextEditingController()),
  ];

  @override
  void dispose() {
    _name.dispose();
    for (final s in _steps) {
      s.text.dispose();
    }
    super.dispose();
  }

  void _addStep() =>
      setState(() => _steps.add((id: null, text: TextEditingController())));

  void _removeStep(int index) {
    setState(() {
      _steps.removeAt(index).text.dispose();
      // Indexed errors no longer line up with the rows.
      fieldErrors = const {};
    });
  }

  Future<void> _delete() => _deleteFlow(
    title: 'ลบ Checklist',
    message:
        'ลบ "${_editing!.name}" และขั้นตอนทั้งหมดใช่หรือไม่ '
        'ลบแล้วกู้คืนไม่ได้',
    delete: () => _checklists.deleteChecklist(_editing.typeId),
  );

  Future<void> _save() async {
    final editing = _editing;
    final type = await _run(
      () => editing == null
          ? _checklists.createChecklist({
              'name': _name.text,
              'steps': [for (final s in _steps) s.text.text],
            })
          : _checklists.editChecklist(editing.typeId, {
              'name': _name.text,
              'steps': [
                for (final s in _steps)
                  s.id == null
                      ? s.text.text
                      : {'checklist_id': s.id, 'name': s.text.text},
              ],
            }),
      success: 'บันทึก Checklist เรียบร้อยแล้ว',
    );
    if (type != null && mounted) Navigator.pop(context, type);
  }

  @override
  Widget build(BuildContext context) {
    return _screen(
      context,
      title: _editing == null ? 'สร้าง Checklist ใหม่' : 'แก้ไข Checklist',
      subtitle: _editing == null
          ? 'กำหนดขั้นตอนการทำงาน'
          : 'ขั้นตอนที่มีโปรเจกต์ใช้อยู่จะลบไม่ได้',
      loading: _loading,
      action: _editing == null
          ? null
          : _deleteButton('ลบ Checklist', _loading ? null : _delete),
      bottom: _primaryButton(
        _editing == null ? 'บันทึก Checklist' : 'บันทึกการแก้ไข',
        _loading ? null : _save,
      ),
      children: [
        _fieldLabel('ประเภทงาน'),
        TextField(
          controller: _name,
          decoration: InputDecoration(
            hintText: 'กรอกประเภทงาน เช่น ออกแบบกราฟิก',
            errorText: fieldErrors['name'],
          ),
        ),
        const SizedBox(height: 28),
        _sectionTitle('ขั้นตอนการทำงาน'),
        _fieldError(fieldErrors['steps']),
        const SizedBox(height: 12),
        for (var i = 0; i < _steps.length; i++)
          Padding(
            key: ObjectKey(_steps[i].text),
            padding: const EdgeInsets.only(bottom: 10),
            child: _stepRow(i),
          ),
        const SizedBox(height: 8),
        _softButton('+ เพิ่มขั้นตอน', _addStep),
      ],
    );
  }

  Widget _stepRow(int i) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _surface(
          radius: 16,
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
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
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _steps[i].text,
                  textInputAction: i == _steps.length - 1
                      ? TextInputAction.done
                      : TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'ขั้นตอนที่ ${i + 1}',
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'ลบขั้นตอน',
                onPressed: _steps.length == 1 ? null : () => _removeStep(i),
                icon: const Icon(Icons.close_rounded, color: _muted),
              ),
            ],
          ),
        ),
        _fieldError(fieldErrors['steps.$i']),
      ],
    );
  }
}
