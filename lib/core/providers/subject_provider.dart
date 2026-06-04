import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/subject_model.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

/// Real-time stream of subjects for a given semester.
///
/// This is a `.family` provider — pass the semesterId as the parameter:
/// ```dart
/// ref.watch(subjectsProvider('semesterId'))
/// ```
///
/// Each unique semesterId gets its own Firestore listener.
/// Riverpod automatically disposes it when no longer watched.
final subjectsProvider =
    StreamProvider.family<List<Subject>, String>((ref, semesterId) {
  final uid = ref.watch(currentUidProvider);
  return FirestoreService().watchSubjects(uid, semesterId);
});
