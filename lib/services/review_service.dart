import '../modules/database.dart';
import '../models/review.dart';

class ReviewService {
  final AppDatabase _db;

  ReviewService(this._db);

  /// Saves or updates a review for a given week and goal.
  Future<Review> saveReview(
    String week, {
    int? goalId,
    String? notes,
  }) async {
    final existing = await _db.getReviewForWeek(week, goalId: goalId);

    if (existing != null) {
      final updated = existing.copyWith(notes: notes);
      await _db.updateReview(updated);
      return updated;
    } else {
      final review = Review(goalId: goalId, week: week, notes: notes);
      final id = await _db.insertReview(review);
      return review.copyWith(id: id);
    }
  }

  Future<Review?> getReview(String week, {int? goalId}) =>
      _db.getReviewForWeek(week, goalId: goalId);

  Future<List<Review>> getAllReviews({int? goalId}) =>
      _db.getAllReviews(goalId: goalId);

  Future<void> deleteReview(int id) => _db.deleteReview(id);
}
