import '../core/app_exception.dart';
import '../core/validators.dart';
import '../services/database_service.dart';
import '../models/models.dart';

class OrganizerController {
  OrganizerController(this._db);

  final DatabaseService _db;

  /// Returns field errors for an organizer body; empty when valid.
  Map<String, String> validate(Map<String, dynamic> body) {
    final errors = <String, String>{};

    final orgName = textOf(body['org_name']);
    if (orgName == null) {
      errors['org_name'] = 'กรุณากรอกชื่อ Organizer';
    } else if (orgName.length > 255) {
      errors['org_name'] = 'ชื่อ Organizer ยาวเกิน 255 ตัวอักษร';
    }

    final contactName = textOf(body['contact_name']);
    if (contactName == null) {
      errors['contact_name'] = 'กรุณากรอกชื่อผู้ติดต่อ';
    } else if (!thaiOrEnglishPattern.hasMatch(contactName)) {
      errors['contact_name'] =
          'ชื่อผู้ติดต่อต้องเป็นอักษรไทยหรืออังกฤษเท่านั้น';
    } else if (contactName.length > 255) {
      errors['contact_name'] = 'ชื่อผู้ติดต่อยาวเกิน 255 ตัวอักษร';
    }

    final phone = textOf(body['phone']);
    if (phone != null) {
      if (!digitsPattern.hasMatch(phone)) {
        errors['phone'] = 'เบอร์โทรต้องเป็นตัวเลข 0-9 เท่านั้น';
      } else if (phone.length > 20) {
        errors['phone'] = 'เบอร์โทรยาวเกิน 20 หลัก';
      }
    }

    final color = textOf(body['color']);
    if (color == null) {
      errors['color'] = 'กรุณาเลือกสี';
    } else if (!hexColorPattern.hasMatch(color)) {
      errors['color'] = 'สีต้องเป็นรหัส hex เช่น #FF5733';
    }

    return errors;
  }

  Future<Organizer> createOrganizer(Map<String, dynamic> body) async {
    final errors = validate(body);
    if (errors.isNotEmpty) throw AppException.validation(errors);

    final orgName = textOf(body['org_name'])!;
    if (await _db.exists('organizers', {'org_name': orgName})) {
      throw AppException.conflict(
        'มี Organizer ชื่อนี้อยู่แล้ว',
        fields: {'org_name': 'มี Organizer ชื่อนี้อยู่แล้ว'},
      );
    }

    final organizer = Organizer(
      orgName: orgName,
      contactName: textOf(body['contact_name'])!,
      phone: textOf(body['phone']),
      color: textOf(body['color'])!.toUpperCase(),
    );
    final data = organizer.toJson()..remove('org_id');
    final id = await _db.insert('organizers', data, idColumn: 'org_id');
    return Organizer.fromJson({...data, 'org_id': id});
  }

  Future<List<Organizer>> getOrganizers() async {
    final rows = await _db.select('organizers', {}, orderBy: 'org_name');
    return rows.map(Organizer.fromJson).toList();
  }
}
