import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/app_time.dart';

enum AssignmentStatus { active, missed, done }

class Assignment {
  final String id;
  final String semesterId;
  final String title;
  final String? subjectId;
  final String? subjectName;
  final DateTime dueDate;
  final bool isDone;
  final DateTime? doneAt;
  final DateTime createdAt;

  const Assignment({
    required this.id,
    required this.semesterId,
    required this.title,
    this.subjectId,
    this.subjectName,
    required this.dueDate,
    this.isDone = false,
    this.doneAt,
    required this.createdAt,
  });

  /// Computed property: An assignment is missed if it's not done and the due date has passed.
  bool get isMissed {
    if (isDone) return false;
    final now = AppTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return today.isAfter(due);
  }

  factory Assignment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Assignment(
      id: doc.id,
      semesterId: data['semesterId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      subjectId: data['subjectId'] as String?,
      subjectName: data['subjectName'] as String?,
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      isDone: data['isDone'] as bool? ?? false,
      doneAt: data['doneAt'] != null ? (data['doneAt'] as Timestamp).toDate() : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'semesterId': semesterId,
      'title': title,
      'subjectId': subjectId,
      'subjectName': subjectName,
      'dueDate': Timestamp.fromDate(dueDate),
      'isDone': isDone,
      'doneAt': doneAt != null ? Timestamp.fromDate(doneAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Assignment copyWith({
    String? id,
    String? semesterId,
    String? title,
    String? subjectId,
    String? subjectName,
    DateTime? dueDate,
    bool? isDone,
    DateTime? doneAt,
    DateTime? createdAt,
  }) {
    return Assignment(
      id: id ?? this.id,
      semesterId: semesterId ?? this.semesterId,
      title: title ?? this.title,
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      dueDate: dueDate ?? this.dueDate,
      isDone: isDone ?? this.isDone,
      doneAt: doneAt ?? this.doneAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

