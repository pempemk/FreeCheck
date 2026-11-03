import 'checklist.dart';
import 'json_serializable.dart';
import 'json_utils.dart';

/// A checklist step copied into a project, with its completion state.
class ProjectChecklist implements JsonSerializable {
  const ProjectChecklist({
    required this.projectId,
    required this.checklistId,
    this.completed = false,
    this.checklist,
  });

  factory ProjectChecklist.fromJson(Map<String, dynamic> json) =>
      ProjectChecklist(
        projectId: asInt(json['project_id']),
        checklistId: asInt(json['checklist_id']),
        completed: asBool(json['completed']),
        checklist: objectOf(json['checklist'], Checklist.fromJson),
      );

  final int projectId;
  final int checklistId;
  final bool completed;

  /// The step's name and type, when loaded.
  final Checklist? checklist;

  @override
  Map<String, dynamic> toJson() => {
    'project_id': projectId,
    'checklist_id': checklistId,
    'completed': completed,
    'checklist': checklist?.toJson(),
  };
}
