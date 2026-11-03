import 'json_serializable.dart';
import 'json_utils.dart';
import 'organizer.dart';
import 'project_checklist.dart';
import 'project_status.dart';
import 'rating.dart';

class Project implements JsonSerializable {
  const Project({
    required this.projectName,
    required this.orgId,
    required this.startDate,
    required this.wages,
    this.projectId = 0,
    this.deadline,
    this.status = ProjectStatus.inProgress,
    this.submittedAt,
    this.paidAt,
    this.note = '',
    this.organizer,
    this.checklists = const [],
    this.rating,
    this.progress = 0,
  });

  factory Project.fromJson(Map<String, dynamic> json) => Project(
    projectId: asInt(json['project_id']),
    orgId: asInt(json['org_id']),
    projectName: json['project_name'] as String,
    startDate: asDateTime(json['start_date'])!,
    deadline: asDateTime(json['deadline']),
    wages: asNum(json['wages']),
    status: ProjectStatus.values.firstWhere(
      (s) => s.value == json['status'],
      orElse: () => ProjectStatus.inProgress,
    ),
    submittedAt: asDateTime(json['submitted_at']),
    paidAt: asDateTime(json['paid_at']),
    note: json['note'] as String? ?? '',
    organizer: objectOf(json['organizer'], Organizer.fromJson),
    checklists: listOf(json['checklists'], ProjectChecklist.fromJson),
    rating: objectOf(json['rating'], Rating.fromJson),
    progress: asNum(json['progress_percent'] ?? 0),
  );

  /// 0 until saved.
  final int projectId;
  final int orgId;
  final String projectName;
  final DateTime startDate;
  final DateTime? deadline;
  final num wages;
  final ProjectStatus status;
  final DateTime? submittedAt;
  final DateTime? paidAt;
  final String note;
  final Organizer? organizer;
  final List<ProjectChecklist> checklists;
  final Rating? rating;

  /// Percentage (0–100) of checklist steps completed, calculated by the
  /// database (`progress_percent`).
  final num progress;

  /// Whether the status may move from [status] to [next].
  bool canChangeTo(ProjectStatus next) => switch ((status, next)) {
    (ProjectStatus.inProgress, ProjectStatus.pending) ||
    (ProjectStatus.pending, ProjectStatus.inProgress) ||
    (ProjectStatus.pending, ProjectStatus.submitted) ||
    (ProjectStatus.submitted, ProjectStatus.completed) => true,
    _ => false,
  };

  @override
  Map<String, dynamic> toJson() => {
    'project_id': projectId,
    'org_id': orgId,
    'project_name': projectName,
    'start_date': dateOnly(startDate),
    'deadline': dateOnly(deadline),
    'wages': wages,
    'status': status.value,
    'submitted_at': submittedAt?.toIso8601String(),
    'paid_at': paidAt?.toIso8601String(),
    'note': note,
    'organizer': organizer?.toJson(),
    'checklists': [for (final c in checklists) c.toJson()],
    'rating': rating?.toJson(),
    'progress_percent': progress,
  };
}
