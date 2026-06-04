import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/subject_model.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

/// Real-time stream of files for a given subject.
///
/// This is a `.family` provider — pass the subjectId as the parameter:
/// ```dart
/// ref.watch(filesProvider('subjectId'))
/// ```
///
/// Each unique subjectId gets its own Firestore listener.
/// Riverpod automatically disposes it when no longer watched.
final filesProvider =
    StreamProvider.family<List<SubjectFile>, String>((ref, subjectId) {
  final uid = ref.watch(currentUidProvider);
  return FirestoreService().watchFiles(uid, subjectId);
});
