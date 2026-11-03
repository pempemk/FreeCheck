import 'json_serializable.dart';
import 'json_utils.dart';

class Rating implements JsonSerializable {
  const Rating({
    required this.projectId,
    required this.orgId,
    required this.score,
    this.ratingId = 0,
  });

  factory Rating.fromJson(Map<String, dynamic> json) => Rating(
    ratingId: asInt(json['rating_id']),
    projectId: asInt(json['project_id']),
    orgId: asInt(json['org_id']),
    score: asInt(json['score']),
  );

  final int ratingId;
  final int projectId;
  final int orgId;
  final int score;

  @override
  Map<String, dynamic> toJson() => {
    'rating_id': ratingId,
    'project_id': projectId,
    'org_id': orgId,
    'score': score,
  };
}
