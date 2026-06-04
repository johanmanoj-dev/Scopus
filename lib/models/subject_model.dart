import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/app_time.dart';

/// A file associated with a subject, stored in Google Drive.
class SubjectFile {
  final String id;
  final String name;
  final String driveFileId;
  final String mimeType;
  final int sizeBytes;
  final DateTime uploadedAt;

  const SubjectFile({
    required this.id,
    required this.name,
    required this.driveFileId,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedAt,
  });

  factory SubjectFile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SubjectFile(
      id: doc.id,
      name: data['name'] as String,
      driveFileId: data['driveFileId'] as String,
      mimeType: data['mimeType'] as String,
      sizeBytes: data['sizeBytes'] as int,
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate() ?? AppTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'driveFileId': driveFileId,
        'mimeType': mimeType,
        'sizeBytes': sizeBytes,
        'uploadedAt': Timestamp.fromDate(uploadedAt),
      };

  SubjectFile copyWith({
    String? id,
    String? name,
    String? driveFileId,
    String? mimeType,
    int? sizeBytes,
    DateTime? uploadedAt,
  }) {
    return SubjectFile(
      id: id ?? this.id,
      name: name ?? this.name,
      driveFileId: driveFileId ?? this.driveFileId,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }

  String get displaySize {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Represents one academic subject belonging to a semester.
///
/// Firestore path: `users/{uid}/subjects/{subjectId}`
///
/// [driveFolderId] — the Google Drive folder ID for this subject under
/// `AcademicWorkspace/{SemesterFolder}/`. Created by DriveService on creation.
class Subject {
  final String id;
  final String semesterId;
  final String title;
  final String driveFolderId;
  final DateTime createdAt;

  Subject({
    required this.id,
    required this.semesterId,
    required this.title,
    this.driveFolderId = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? AppTime.now();

  // ── Firestore Serialization ───────────────────────────────────────

  factory Subject.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Subject(
      id: doc.id,
      semesterId: data['semesterId'] as String,
      title: data['title'] as String,
      driveFolderId: data['driveFolderId'] as String? ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? AppTime.now(),
    );
  }

  /// Fields written to Firestore.
  Map<String, dynamic> toMap() => {
        'semesterId': semesterId,
        'title': title,
        'driveFolderId': driveFolderId,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  Subject copyWith({
    String? id,
    String? semesterId,
    String? title,
    String? driveFolderId,
    DateTime? createdAt,
  }) {
    return Subject(
      id: id ?? this.id,
      semesterId: semesterId ?? this.semesterId,
      title: title ?? this.title,
      driveFolderId: driveFolderId ?? this.driveFolderId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
