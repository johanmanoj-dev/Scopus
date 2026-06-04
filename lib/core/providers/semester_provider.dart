import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/semester_model.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

/// Real-time stream of ALL semesters for the current user, newest first.
///
/// Both active and archived semesters are included so that
/// [activeSemesterProvider] and [archivedSemestersProvider] can be derived
/// from a single Firestore listener (avoids two open subscriptions).
final semestersProvider = StreamProvider<List<Semester>>((ref) {
  final uid = ref.watch(currentUidProvider);
  return FirestoreService().watchSemesters(uid);
});

/// The currently active (non-archived) semester.
///
/// Returns null when no active semester exists.
/// GoRouter uses this to decide whether to show the dashboard or
/// redirect to /no-semester (wired in Step 6).
final activeSemesterProvider = Provider<Semester?>((ref) {
  final semesters = ref.watch(semestersProvider).valueOrNull ?? [];
  try {
    return semesters.firstWhere((s) => s.isActive && !s.isArchived);
  } catch (_) {
    return null;
  }
});

/// All archived semesters, newest first.
///
/// Derived from [semestersProvider] — no extra Firestore listener.
/// Used by settings_screen's archived semester list (wired in Step 6).
final archivedSemestersProvider = Provider<List<Semester>>((ref) {
  final semesters = ref.watch(semestersProvider).valueOrNull ?? [];
  return semesters.where((s) => s.isArchived).toList();
});
