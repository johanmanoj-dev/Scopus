import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/assignment_model.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

final assignmentsProvider = StreamProvider.family<List<Assignment>, String>((ref, semesterId) {
  final uid = ref.watch(currentUidProvider);
  return FirestoreService().watchAssignments(uid, semesterId);
});
