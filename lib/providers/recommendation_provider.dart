import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecommendationProvider extends Notifier<Map<String, dynamic>> {
  @override
  Map<String, dynamic> build() {
    return {};
  }

  void addTasks(task) {
    state = task;
  }
}

final recommendationProvider =
    NotifierProvider<RecommendationProvider, Map<String, dynamic>>(() {
  return RecommendationProvider();
});

final isRecommendLoaded = StateProvider<bool>((ref) => false);
