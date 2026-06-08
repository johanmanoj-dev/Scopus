import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/assignment_model.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';
import '../database/cache_database.dart';

final pendingOperationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) async* {
  final db = CacheDatabase();
  yield await db.getPendingOperations();
  await for (final _ in db.onQueueChanged) {
    yield await db.getPendingOperations();
  }
});

final _firestoreAssignmentsProvider = StreamProvider.family<List<Assignment>, String>((ref, semesterId) {
  final uid = ref.watch(currentUidProvider);
  return FirestoreService().watchAssignments(uid, semesterId);
});

final assignmentsProvider = Provider.family<AsyncValue<List<Assignment>>, String>((ref, semesterId) {
  final firestoreAsync = ref.watch(_firestoreAssignmentsProvider(semesterId));
  final pendingAsync = ref.watch(pendingOperationsProvider);

  if (firestoreAsync.isLoading || pendingAsync.isLoading) {
    // If it's the very first load, show loading. Otherwise keep showing data (isRefreshing).
    if (!firestoreAsync.hasValue && !pendingAsync.hasValue) {
      return const AsyncValue.loading();
    }
  }

  if (firestoreAsync.hasError) {
    return AsyncValue.error(firestoreAsync.error!, firestoreAsync.stackTrace!);
  }

  var assignments = firestoreAsync.valueOrNull?.toList() ?? [];
  final pendingOps = pendingAsync.valueOrNull ?? [];

  for (final op in pendingOps) {
    final payload = jsonDecode(op['payload'] as String);
    final operation = op['operation'] as String;

    if (operation == 'create_assignment') {
      if (payload['semesterId'] == semesterId) {
        assignments.add(Assignment(
          id: payload['id'] as String? ?? '',
          semesterId: payload['semesterId'] as String? ?? '',
          title: payload['title'] as String? ?? '',
          subjectId: payload['subjectId'] as String?,
          subjectName: payload['subjectName'] as String?,
          dueDate: DateTime.parse(payload['dueDate'] as String),
          isDone: payload['isDone'] as bool? ?? false,
          doneAt: payload['doneAt'] != null ? DateTime.parse(payload['doneAt'] as String) : null,
          createdAt: DateTime.parse(payload['createdAt'] as String),
          isPendingSync: true,
        ));
      }
    } else if (operation == 'mark_done') {
      final id = payload['assignmentId'] as String;
      final index = assignments.indexWhere((a) => a.id == id);
      if (index != -1) {
        assignments[index] = assignments[index].copyWith(
          isDone: true,
          isPendingSync: true,
        );
      }
    } else if (operation == 'delete_assignment') {
      final id = payload['assignmentId'] as String;
      assignments.removeWhere((a) => a.id == id);
    }
  }

  assignments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
  return AsyncValue.data(assignments);
});
