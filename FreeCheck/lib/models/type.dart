import 'checklist.dart';
import 'json_serializable.dart';
import 'json_utils.dart';

/// A kind of work (e.g. "Website") and its checklist steps.
class Type implements JsonSerializable {
  const Type({required this.name, this.typeId = 0, this.checklists = const []});

  factory Type.fromJson(Map<String, dynamic> json) => Type(
    typeId: asInt(json['type_id']),
    name: json['name'] as String,
    checklists: listOf(json['checklists'], Checklist.fromJson),
  );

  final int typeId;
  final String name;
  final List<Checklist> checklists;

  @override
  Map<String, dynamic> toJson() => {
    'type_id': typeId,
    'name': name,
    'checklists': [for (final c in checklists) c.toJson()],
  };
}
