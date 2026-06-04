import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/auth_user.dart';
import '../../models/semester_model.dart';
import '../../models/subject_model.dart';
import '../../models/assignment_model.dart';
import '../errors/app_exception.dart';

/// Handles all interactions with Cloud Firestore.
///
/// Firestore structure:
/// ```
/// users/{uid}/
///   ├── semesters/{semesterId}
///   │     ├── title, driveFolderId, isActive, isArchived, createdAt
///   └── subjects/{subjectId}
///         ├── semesterId, title, driveFolderId, createdAt
///         └── files/{fileId}          ← Phase 3
///               ├── name, driveFileId, mimeType, sizeBytes, uploadedAt
/// ```
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Collection References ─────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _semestersRef(String uid) =>
      _db.collection('users').doc(uid).collection('semesters');

  CollectionReference<Map<String, dynamic>> _subjectsRef(String uid) =>
      _db.collection('users').doc(uid).collection('subjects');

  // ── User Profile ──────────────────────────────────────────────────

  /// Saves or updates the user profile in Firestore.
  ///
  /// Uses merge so we never overwrite fields added by later phases.
  Future<void> saveUserProfile(AuthUser user) async {
    try {
      await _db.collection('users').doc(user.uid).set(
        {
          'email': user.email,
          'displayName': user.displayName,
          'photoUrl': user.photoUrl,
          'rootFolderId': user.rootFolderId,
          'lastLogin': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      throw FirestoreException(
        'Failed to save user profile: $e',
        code: 'profile-save-failed',
        originalError: e,
      );
    }
  }

  /// Fetches the user's `AcademicWorkspace` Drive folder ID from Firestore.
  /// Used by screens that need to create semester/subject folders in Drive.
  Future<String?> getRootFolderId(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['rootFolderId'] as String?;
  }

  // ── Semester CRUD ─────────────────────────────────────────────────

  /// Creates a new semester document.
  ///
  /// If [semester.id] is non-empty, it is used as the document ID.
  /// Otherwise Firestore auto-generates one.
  /// Returns the final document ID (use this to persist into your state).
  Future<String> createSemester(String uid, Semester semester) async {
    try {
      final ref = semester.id.isNotEmpty
          ? _semestersRef(uid).doc(semester.id)
          : _semestersRef(uid).doc();
      await ref.set(semester.toMap());
      return ref.id;
    } catch (e) {
      throw FirestoreException(
        'Failed to create semester: $e',
        code: 'semester-create-failed',
        originalError: e,
      );
    }
  }

  /// Merges [data] into an existing semester document.
  /// Use for partial updates (e.g. updating just the title).
  Future<void> updateSemester(
    String uid,
    String semesterId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _semestersRef(uid).doc(semesterId).update(data);
    } catch (e) {
      throw FirestoreException(
        'Failed to update semester $semesterId: $e',
        code: 'semester-update-failed',
        originalError: e,
      );
    }
  }

  /// Archives the semester: sets `isActive = false`, `isArchived = true`.
  ///
  /// Archived semesters become read-only cold storage.
  /// A new semester must be created to continue working.
  Future<void> archiveSemester(String uid, String semesterId) async {
    try {
      await _semestersRef(uid).doc(semesterId).update({
        'isActive': false,
        'isArchived': true,
      });
    } catch (e) {
      throw FirestoreException(
        'Failed to archive semester $semesterId: $e',
        code: 'semester-archive-failed',
        originalError: e,
      );
    }
  }

  /// Real-time stream of ALL semesters for [uid], newest first.
  ///
  /// Providers derive active / archived views from this single stream
  /// to avoid multiple Firestore listeners.
  Stream<List<Semester>> watchSemesters(String uid) async* {
    final stream = _semestersRef(uid)
        .orderBy('createdAt', descending: true)
        .snapshots(includeMetadataChanges: true);

    bool isFirst = true;
    await for (final snap in stream) {
      if (isFirst && snap.metadata.isFromCache && snap.docs.isEmpty) {
        try {
          final serverSnap = await _semestersRef(uid)
              .orderBy('createdAt', descending: true)
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(milliseconds: 1000));
          yield serverSnap.docs.map(Semester.fromFirestore).toList();
        } catch (_) {
          yield snap.docs.map(Semester.fromFirestore).toList();
        }
      } else {
        yield snap.docs.map(Semester.fromFirestore).toList();
      }
      isFirst = false;
    }
  }

  /// Real-time stream of archived semesters only, newest first.
  ///
  /// Used by settings_screen's archived semester list.
  Stream<List<Semester>> watchArchivedSemesters(String uid) {
    return _semestersRef(uid)
        .where('isArchived', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Semester.fromFirestore).toList());
  }

  // ── Subject CRUD ──────────────────────────────────────────────────

  /// Creates a new subject document.
  ///
  /// Returns the final Firestore-generated document ID.
  Future<String> createSubject(String uid, Subject subject) async {
    try {
      final ref = subject.id.isNotEmpty
          ? _subjectsRef(uid).doc(subject.id)
          : _subjectsRef(uid).doc();
      await ref.set(subject.toMap());
      return ref.id;
    } catch (e) {
      throw FirestoreException(
        'Failed to create subject: $e',
        code: 'subject-create-failed',
        originalError: e,
      );
    }
  }

  /// Permanently deletes a subject document AND all its file metadata documents.
  ///
  /// IMPORTANT: Firestore does NOT automatically delete subcollections when a
  /// parent document is deleted. This method explicitly purges the `files`
  /// subcollection first, then deletes the subject document itself.
  ///
  /// The corresponding Drive folder is handled separately by DriveService.
  Future<void> deleteSubjectWithFiles(String uid, String subjectId) async {
    try {
      // 1. Fetch all file documents in the subject's files subcollection.
      final filesSnap = await _filesRef(uid, subjectId).get();

      // 2. Delete each file document in a batched write for efficiency.
      if (filesSnap.docs.isNotEmpty) {
        final batch = _db.batch();
        for (final doc in filesSnap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      // 3. Delete the subject document itself.
      await _subjectsRef(uid).doc(subjectId).delete();
    } catch (e) {
      throw FirestoreException(
        'Failed to delete subject $subjectId with files: $e',
        code: 'subject-delete-failed',
        originalError: e,
      );
    }
  }

  /// Merges [data] into an existing subject document.
  /// Use for partial updates (e.g. renaming a subject).
  Future<void> updateSubject(
    String uid,
    String subjectId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _subjectsRef(uid).doc(subjectId).update(data);
    } catch (e) {
      throw FirestoreException(
        'Failed to update subject $subjectId: $e',
        code: 'subject-update-failed',
        originalError: e,
      );
    }
  }

  /// Real-time stream of subjects belonging to [semesterId], sorted oldest first.
  ///
  /// Sorting is done in memory (not via orderBy) to avoid requiring a
  /// composite Firestore index. This is efficient for typical subject counts.
  Stream<List<Subject>> watchSubjects(String uid, String semesterId) {
    return _subjectsRef(uid)
        .where('semesterId', isEqualTo: semesterId)
        .snapshots()
        .map((snap) {
          final subjects = snap.docs.map(Subject.fromFirestore).toList();
          subjects.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return subjects;
        });
  }

  // ── File CRUD ─────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _filesRef(
          String uid, String subjectId) =>
      _subjectsRef(uid).doc(subjectId).collection('files');

  /// Creates a new file metadata document.
  ///
  /// Returns the Firestore-generated document ID. The caller MUST use
  /// `file.copyWith(id: returnedId)` to keep the in-memory object in sync.
  Future<String> createFileMetadata(
      String uid, String subjectId, SubjectFile file) async {
    try {
      final ref = file.id.isNotEmpty
          ? _filesRef(uid, subjectId).doc(file.id)
          : _filesRef(uid, subjectId).doc();
      await ref.set(file.toMap());
      return ref.id;
    } catch (e) {
      throw FirestoreException(
        'Failed to create file metadata: $e',
        code: 'file-create-failed',
        originalError: e,
      );
    }
  }

  /// Real-time stream of files belonging to [subjectId], sorted newest first.
  ///
  /// Sorting is done in memory (not via orderBy) to avoid requiring a
  /// composite Firestore index.
  Stream<List<SubjectFile>> watchFiles(String uid, String subjectId) {
    return _filesRef(uid, subjectId).snapshots().map((snap) {
      final files = snap.docs.map(SubjectFile.fromFirestore).toList();
      files.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      return files;
    });
  }

  /// Permanently deletes a file metadata document.
  ///
  /// The corresponding Drive file is handled separately by DriveService.
  Future<void> deleteFileMetadata(
      String uid, String subjectId, String fileId) async {
    try {
      await _filesRef(uid, subjectId).doc(fileId).delete();
    } catch (e) {
      throw FirestoreException(
        'Failed to delete file metadata $fileId: $e',
        code: 'file-delete-failed',
        originalError: e,
      );
    }
  }

  // ── Assignment CRUD ───────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _assignmentsRef(String uid) =>
      _db.collection('users').doc(uid).collection('assignments');

  Future<String> createAssignment(String uid, Assignment assignment) async {
    try {
      final ref = assignment.id.isNotEmpty
          ? _assignmentsRef(uid).doc(assignment.id)
          : _assignmentsRef(uid).doc();
      await ref.set(assignment.toMap());
      return ref.id;
    } catch (e) {
      throw FirestoreException(
        'Failed to create assignment: $e',
        code: 'assignment-create-failed',
        originalError: e,
      );
    }
  }

  Stream<List<Assignment>> watchAssignments(String uid, String semesterId) {
    return _assignmentsRef(uid)
        .where('semesterId', isEqualTo: semesterId)
        .snapshots()
        .map((snap) {
      final assignments = snap.docs.map(Assignment.fromFirestore).toList();
      assignments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return assignments;
    });
  }

  Future<void> markAssignmentDone(String uid, String assignmentId) async {
    try {
      await _assignmentsRef(uid).doc(assignmentId).update({
        'isDone': true,
        'doneAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw FirestoreException(
        'Failed to mark assignment as done: $e',
        code: 'assignment-update-failed',
        originalError: e,
      );
    }
  }

  Future<void> deleteAssignment(String uid, String assignmentId) async {
    try {
      await _assignmentsRef(uid).doc(assignmentId).delete();
    } catch (e) {
      throw FirestoreException(
        'Failed to delete assignment $assignmentId: $e',
        code: 'assignment-delete-failed',
        originalError: e,
      );
    }
  }

  // ── Singleton ─────────────────────────────────────────────────────
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();
}
