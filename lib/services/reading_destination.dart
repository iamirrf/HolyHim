import 'package:holyher/services/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReadingDestination {
  final int day;
  final bool scripture;
  const ReadingDestination(this.day, {this.scripture = false});
}

final readingDestinationProvider = StateProvider<ReadingDestination?>((ref) {
  ref.watch(authProvider.select((s) => s.user?.uid));
  return null;
});
