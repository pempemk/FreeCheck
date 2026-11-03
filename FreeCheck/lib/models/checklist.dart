import 'json_serializable.dart';
import 'json_utils.dart';

/// One step of a checklist [Type].
class Checklist implements JsonSerializable {
  const Checklist({required this.name, this.checklistId = 0, this.typeId = 0});

  factory Checklist.fromJson(Map<String, dynamic> json) => Checklist(
    checklistId: asInt(json['checklist_id']),
    typeId: asInt(json['type_id']),
    name: json['name'] as String,
  );

  final int checklistId;
  final int typeId;
  final String name;

  @override
  Map<String, dynamic> toJson() => {
    'checklist_id': checklistId,
    'type_id': typeId,
    'name': name,
  };
}
