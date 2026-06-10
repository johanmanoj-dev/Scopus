import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/assignment_model.dart';
import '../database/cache_database.dart';
import '../services/firestore_service.dart';
import '../providers/auth_provider.dart';
import 'network_monitor.dart';
import '../services/notification_service.dart';

/// A provider that initializes and manages background sync.
/// Watch or read this provider in the root layout to keep it alive.
final syncManagerProvider = Provider<SyncManager>((ref) {
  final manager = SyncManager(ref);
  
  // Listen to network status changes
  ref.listen<AsyncValue<bool>>(networkStatusProvider, (previous, next) {
    if (next.value == true) {
      manager.sync();
    }
  });
  
  return manager;
});

class SyncManager {
  final Ref ref;
  bool _isSyncing = false;

  SyncManager(this.ref);

  /// Reads all pending operations from the offline queue and replays them
  /// against Firestore. Skips operations that fail and leaves them for next time.
  Future<void> sync() async {
    if (_isSyncing) return;
    
    String uid;
    try {
      uid = ref.read(currentUidProvider);
    } catch (_) {
      return; // No signed in user
    }

    _isSyncing = true;
    try {
      final db = CacheDatabase();
      final pendingOps = await db.getPendingOperations();
      if (pendingOps.isEmpty) return;

      for (final op in pendingOps) {
        final id = op['id'] as int;
        final operation = op['operation'] as String;
        final payloadStr = op['payload'] as String;

        try {
          final payload = jsonDecode(payloadStr) as Map<String, dynamic>;

          if (operation == 'create_assignment') {
            final assignment = Assignment(
              id: payload['id'] as String? ?? '',
              semesterId: payload['semesterId'] as String? ?? '',
              title: payload['title'] as String? ?? '',
              subjectId: payload['subjectId'] as String?,
              subjectName: payload['subjectName'] as String?,
              dueDate: DateTime.parse(payload['dueDate'] as String),
              isDone: payload['isDone'] as bool? ?? false,
              doneAt: payload['doneAt'] != null ? DateTime.parse(payload['doneAt'] as String) : null,
              createdAt: DateTime.parse(payload['createdAt'] as String),
            );
            await FirestoreService().createAssignment(uid, assignment);
            NotificationService().scheduleAssignmentReminder(assignment);
          } else if (operation == 'mark_done') {
            final assignmentId = payload['assignmentId'] as String;
            await FirestoreService().markAssignmentDone(uid, assignmentId);
            NotificationService().cancelReminder(assignmentId);
          } else if (operation == 'delete_assignment') {
            final assignmentId = payload['assignmentId'] as String;
            await FirestoreService().deleteAssignment(uid, assignmentId);
            NotificationService().cancelReminder(assignmentId);
          }

          // Operation succeeded (or was handled), remove from queue
          await db.deleteOperation(id);
        } catch (e) {
          // If a delete operation fails because the document doesn't exist
          // (e.g., deleted on another device), treat it as success and remove
          // it from the queue. Re-deleting a non-existent document is a no-op.
          final isDeleteOp = operation == 'delete_assignment';
          final isNotFound = e.toString().contains('NOT_FOUND') ||
              e.toString().contains('not-found');
          if (isDeleteOp && isNotFound) {
            await db.deleteOperation(id);
          } else {
            // For all other failures (e.g. permission issue, malformed data),
            // log it and leave it in the queue for the next sync attempt.
            debugPrint('SyncManager: Failed to replay operation $id ($operation): $e');
          }
        }
      }
    } finally {
      _isSyncing = false;
    }
  }
}
