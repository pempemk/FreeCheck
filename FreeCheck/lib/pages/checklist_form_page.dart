part of 'page.dart';

class ChecklistFormPage extends Page<void> {
  ChecklistFormPage({required super.db});

  final _name = TextEditingController();
  final _steps = [TextEditingController()];

  @override
  void dispose() {
    _name.dispose();
    for (final s in _steps) {
      s.dispose();
    }
    super.dispose();
  }

  void _addStep() => setState(() => _steps.add(TextEditingController()));

  void _removeStep(int index) {
    setState(() {
      _steps.removeAt(index).dispose();
      // Indexed errors no longer line up with the rows.
      fieldErrors = const {};
    });
  }

  Future<void> _save() async {
    final type = await _run(
      () => _checklists.createChecklist({
        'name': _name.text,
        'steps': [for (final s in _steps) s.text],
      }),
      success: 'บันทึก Checklist เรียบร้อยแล้ว',
    );
    if (type != null && mounted) Navigator.pop(context, type);
  }

  @override
  Widget build(BuildContext context) {
    return _screen(
      context,
      title: 'สร้าง Checklist ใหม่',
      subtitle: 'กำหนดขั้นตอนการทำงาน',
      loading: _loading,
      bottom: _primaryButton('บันทึก Checklist', _loading ? null : _save),
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
            key: ObjectKey(_steps[i]),
            padding: const EdgeInsets.only(bottom: 10),
            child: _stepRow(i),
          ),
        const SizedBox(height: 8),
        _softButton('+ เพิ่มขั้นตอน', _addStep),
      ],
    );
  }

  Widget _stepRow(int i) {
    final error = fieldErrors['steps.$i'];
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
                  controller: _steps[i],
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
        _fieldError(error),
      ],
    );
  }
}
