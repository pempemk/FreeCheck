import '../core/app_exception.dart';
import '../services/database_connector.dart';
import '../models/models.dart';

class RatingController {
  RatingController(this._db);

  final DatabaseConnector _db;

  /// Returns field errors for a rating body; empty when valid.
  Map<String, String> validate(Map<String, dynamic> body) {
    final score = body['score'];
    if (score == null || (score is String && score.trim().isEmpty)) {
      return {'score': 'กรุณาให้คะแนน'};
    }
    if (score is! int || score < 1 || score > 5) {
      return {'score': 'คะแนนต้องเป็นจำนวนเต็ม 1-5'};
    }
    return {};
  }

  /// Saves the rating and recalculates `organizers.rate` in one transaction.
  Future<Rating> saveRating(int projectId, Map<String, dynamic> body) async {
    final errors = validate(body);
    if (errors.isNotEmpty) throw AppException.validation(errors);
    final score = body['score'] as int;

    final projects = await _db.select('projects', {'project_id': projectId});
    if (projects.isEmpty) throw AppException.notFound('ไม่พบงานนี้');
    final project = projects.first;
    if (project['status'] != ProjectStatus.completed.value) {
      throw AppException.conflict('ให้คะแนนได้เฉพาะงานที่เสร็จสิ้นแล้ว');
    }
    if (await _db.exists('ratings', {'project_id': projectId})) {
      throw AppException.conflict('งานนี้ให้คะแนนไปแล้ว');
    }

    final orgId = project['org_id'] as int;
    late int ratingId;
    await _db.transaction((tx) async {
      ratingId = await tx.insert('ratings', {
        'project_id': projectId,
        'org_id': orgId,
        'score': score,
      }, idColumn: 'rating_id');
      final avg = await tx.select(
        'ratings',
        {'org_id': orgId},
        columns: ['COALESCE(AVG(score), 0) AS avg_score'],
      );
      final rate = (avg.first['avg_score'] as num).toStringAsFixed(2);
      await tx.update(
        'organizers',
        {'org_id': orgId},
        {'rate': num.parse(rate)},
      );
    });

    return Rating(
      ratingId: ratingId,
      projectId: projectId,
      orgId: orgId,
      score: score,
    );
  }
}
