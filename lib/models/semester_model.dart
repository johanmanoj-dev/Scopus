import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/app_time.dart';

/// Represents one academic semester.
///
/// Firestore path: `users/{uid}/semesters/{semesterId}`
///
/// [driveFolderId] — the Google Drive folder ID for this semester under
/// `AcademicWorkspace/`. Created by DriveService on semester creation.
///
/// [subjectCount] — UI convenience field; not stored in Firestore.
/// Will be derived from Firestore query count in Step 6.
class Semester {
  final String id;
  final String title;
  final String driveFolderId;
  final bool isActive;
  final bool isArchived;
  final DateTime createdAt;

  /// UI convenience field — not persisted to Firestore.
  /// Kept for settings_screen compatibility until Step 6 wires Riverpod.
  final int subjectCount;

  const Semester({
    required this.id,
    required this.title,
    required this.driveFolderId,
    required this.createdAt,
    this.isActive = false,
    this.isArchived = false,
    this.subjectCount = 0,
  });

  // ── Firestore Serialization ───────────────────────────────────────

  factory Semester.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Semester(
      id: doc.id,
      title: data['title'] as String,
      driveFolderId: data['driveFolderId'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? false,
      isArchived: data['isArchived'] as bool? ?? false,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? AppTime.now(),
    );
  }

  /// Fields written to Firestore. [subjectCount] is intentionally excluded
  /// (it is a derived UI value, not a source-of-truth field).
  Map<String, dynamic> toMap() => {
        'title': title,
        'driveFolderId': driveFolderId,
        'isActive': isActive,
        'isArchived': isArchived,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  Semester copyWith({
    String? id,
    String? title,
    String? driveFolderId,
    bool? isActive,
    bool? isArchived,
    DateTime? createdAt,
    int? subjectCount,
  }) {
    return Semester(
      id: id ?? this.id,
      title: title ?? this.title,
      driveFolderId: driveFolderId ?? this.driveFolderId,
      isActive: isActive ?? this.isActive,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      subjectCount: subjectCount ?? this.subjectCount,
    );
  }

}
