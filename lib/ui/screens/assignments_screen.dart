import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/app_time.dart';
import '../../models/assignment_model.dart';
import '../../models/subject_model.dart';
import '../../core/themes/app_theme.dart';
import '../../core/providers/assignment_provider.dart';
import '../../core/providers/semester_provider.dart';
import '../../core/providers/subject_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/firestore_service.dart';
import '../widgets/assignment_card.dart';
import '../widgets/app_primary_button.dart';
import 'dart:convert';
import '../../core/utils/network_monitor.dart';
import '../../core/database/cache_database.dart';
import '../../core/errors/app_error_handler.dart';
import '../widgets/riverpod_error_state.dart';
import 'package:uuid/uuid.dart';

class AssignmentsScreen extends ConsumerWidget {
  const AssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Platform.isAndroid) return _buildAndroid(context, ref);
    return _buildWindows(context, ref);
  }

  Widget _buildAndroid(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeSemester = ref.watch(activeSemesterProvider);

    if (activeSemester == null) {
      return const SizedBox.shrink();
    }

    final assignmentsAsync = ref.watch(assignmentsProvider(activeSemester.id));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF60A5FA),
          onPressed: () => _showAddDialog(context, ref, activeSemester.id),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text('Assignments', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  activeSemester.title,
                  style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),
                Container(
                  height: 48,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0xFF346BD9),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF346BD9).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: AppTheme.textSecondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    splashBorderRadius: BorderRadius.circular(10),
                    tabs: const [
                      Tab(text: 'Running'),
                      Tab(text: 'Done'),
                      Tab(text: 'Missed'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: assignmentsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => RiverpodErrorState(
                      error: e,
                      customMessage: 'Failed to load assignments',
                      onRetry: () => ref.invalidate(assignmentsProvider(activeSemester.id)),
                    ),
                    data: (assignments) {
                      final running = assignments.where((a) => !a.isDone && !a.isMissed).toList();
                      
                      final done = assignments.where((a) => a.isDone).toList();
                      done.sort((a, b) => (b.doneAt ?? b.dueDate).compareTo(a.doneAt ?? a.dueDate));
                      
                      final missed = assignments.where((a) => a.isMissed).toList();
                      missed.sort((a, b) => a.dueDate.compareTo(b.dueDate));

                      return TabBarView(
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildList(context, ref, running, isReadOnly: false),
                          _buildList(context, ref, done, isReadOnly: true),
                          _buildList(context, ref, missed, isReadOnly: true),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWindows(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeSemester = ref.watch(activeSemesterProvider);

    if (activeSemester == null) {
      return const SizedBox.shrink(); // Router prevents this state
    }

    final assignmentsAsync = ref.watch(assignmentsProvider(activeSemester.id));

    return DefaultTabController(
      length: 3,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Assignments Control Panel',
                  style: theme.textTheme.displayMedium,
                ),
                AppPrimaryButton(
                  onPressed: () => _showAddDialog(context, ref, activeSemester.id),
                  icon: Icons.add,
                  label: 'Add Assignment',
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              height: 52,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF346BD9),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF346BD9).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                splashBorderRadius: BorderRadius.circular(10),
                overlayColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
                  if (states.contains(WidgetState.hovered)) {
                    return Colors.white.withValues(alpha: 0.05);
                  }
                  return null;
                }),
                tabs: const [
                  Tab(child: _HoverText(text: 'Running')),
                  Tab(child: _HoverText(text: 'Done')),
                  Tab(child: _HoverText(text: 'Missed')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: assignmentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => RiverpodErrorState(
                  error: e,
                  customMessage: 'Failed to load assignments',
                  onRetry: () => ref.invalidate(assignmentsProvider(activeSemester.id)),
                ),
                data: (assignments) {
                  final running = assignments.where((a) => !a.isDone && !a.isMissed).toList();
                  
                  final done = assignments.where((a) => a.isDone).toList();
                  done.sort((a, b) => (b.doneAt ?? b.dueDate).compareTo(a.doneAt ?? a.dueDate));
                  
                  final missed = assignments.where((a) => a.isMissed).toList();
                  missed.sort((a, b) => a.dueDate.compareTo(b.dueDate));

                  return TabBarView(
                    physics: Platform.isAndroid ? const NeverScrollableScrollPhysics() : null,
                    children: [
                      _buildList(context, ref, running, isReadOnly: false),
                      _buildList(context, ref, done, isReadOnly: true),
                      _buildList(context, ref, missed, isReadOnly: true),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<Assignment> list, {required bool isReadOnly}) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          'No assignments here.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final assignment = list[index];
        return AssignmentCard(
          assignment: assignment,
          isReadOnly: isReadOnly,
          onChanged: isReadOnly ? null : (value) {
            if (value == true) {
              _markAsDone(context, ref, assignment);
            }
          },
          onDelete: isReadOnly ? null : () => _deleteAssignment(context, ref, assignment),
        );
      },
    );
  }

  void _markAsDone(BuildContext context, WidgetRef ref, Assignment assignment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        title: const Text('Confirm Completion'),
        content: const Text('Are you sure you want to mark this assignment as done?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uid = ref.read(currentUidProvider);
              final isOnline = ref.read(networkStatusProvider).value ?? true;
              try {
                if (isOnline) {
                  await FirestoreService().markAssignmentDone(uid, assignment.id);
                } else {
                  final payload = jsonEncode({'assignmentId': assignment.id});
                  await CacheDatabase().enqueueOperation('mark_done', payload);
                  AppErrorHandler.showMessage("You're offline. This will sync when you reconnect.", isError: false);
                }
              } catch (e) {
                AppErrorHandler.showMessage('Error: $e');
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
            child: const Text('Mark Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteAssignment(BuildContext context, WidgetRef ref, Assignment assignment) {
    if (assignment.isPendingSync) return; // Disallow deleting while pending sync
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            const Text('Delete Assignment?'),
          ],
        ),
        content: Text('Are you sure you want to delete "${assignment.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              final isOnline = ref.read(networkStatusProvider).value ?? true;
              if (!isOnline) {
                AppErrorHandler.showMessage('Device offline. This action requires an internet connection.');
                return;
              }
              final uid = ref.read(currentUidProvider);
              try {
                await FirestoreService().deleteAssignment(uid, assignment.id);
              } catch (e) {
                AppErrorHandler.showMessage('Error: $e');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref, String semesterId) async {
    final titleController = TextEditingController();
    DateTime? selectedDate = AppTime.now().add(const Duration(days: 7));
    Subject? selectedSubject;
    bool hasTitleError = false;
    final isAndroid = Platform.isAndroid;

    await showDialog(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (context, dialogRef, _) {
            final subjectsAsync = dialogRef.watch(subjectsProvider(semesterId));
            final subjects = subjectsAsync.valueOrNull ?? [];

            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  backgroundColor: AppTheme.surfaceVariant,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  titlePadding: EdgeInsets.fromLTRB(isAndroid ? 24 : 32, isAndroid ? 24 : 32, isAndroid ? 24 : 32, 16),
                  contentPadding: EdgeInsets.symmetric(horizontal: isAndroid ? 24 : 32),
                  actionsPadding: EdgeInsets.fromLTRB(isAndroid ? 24 : 32, isAndroid ? 16 : 24, isAndroid ? 24 : 32, isAndroid ? 24 : 32),
                  title: const Text('Add Assignment', style: TextStyle(fontWeight: FontWeight.bold)),
                  content: SizedBox(
                    width: isAndroid ? null : 420,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: titleController,
                            autofocus: true,
                            decoration: InputDecoration(
                              labelText: 'Assignment Title',
                              hintText: 'e.g. Physics Lab Report',
                              errorText: hasTitleError ? 'Please enter a title' : null,
                            ),
                            onChanged: (val) {
                              if (hasTitleError && val.trim().isNotEmpty) {
                                setDialogState(() => hasTitleError = false);
                              }
                            },
                            onSubmitted: (_) {
                              if (titleController.text.trim().isEmpty) {
                                setDialogState(() => hasTitleError = true);
                                return;
                              }
                              Navigator.pop(ctx);
                              _createAssignment(ref, semesterId, titleController.text, selectedSubject, selectedDate!);
                            },
                          ),
                        const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<Subject?>(
                                value: selectedSubject,
                                dropdownColor: AppTheme.surfaceVariant,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('No Subject (Optional)', style: TextStyle(color: AppTheme.textSecondary))),
                                  ...subjects.map((s) => DropdownMenuItem(value: s, child: Text(s.title))),
                                ],
                                onChanged: (val) => setDialogState(() => selectedSubject = val),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 20, color: AppTheme.textSecondary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Due:\n${selectedDate!.toLocal().toString().split(' ')[0]}',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: selectedDate!,
                                      firstDate: AppTime.now(),
                                      lastDate: AppTime.now().add(const Duration(days: 365)),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            dialogTheme: DialogThemeData(
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(24),
                                              ),
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                if (date != null) {
                                  setDialogState(() {
                                    selectedDate = date;
                                  });
                                }
                              },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    backgroundColor: const Color(0xFF346BD9).withValues(alpha: 0.1),
                                    foregroundColor: const Color(0xFF346BD9),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Change Date'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
                    ),
                    FilledButton(
                      onPressed: () {
                        if (titleController.text.trim().isEmpty) {
                          setDialogState(() => hasTitleError = true);
                          return;
                        }
                        Navigator.pop(ctx);
                        _createAssignment(ref, semesterId, titleController.text, selectedSubject, selectedDate!);
                      },
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF346BD9)),
                      child: const Text('Add'),
                    ),
                  ],
                );
              }
            );
          }
        );
      },
    );
    await Future.delayed(const Duration(milliseconds: 300));
    titleController.dispose();
  }

  void _createAssignment(WidgetRef ref, String semesterId, String titleText, Subject? selectedSubject, DateTime selectedDate) async {
    final title = titleText.trim();
    if (title.isEmpty) return;

    final uid = ref.read(currentUidProvider);
    final isOnline = ref.read(networkStatusProvider).value ?? true;

    final assignment = Assignment(
      id: isOnline ? '' : const Uuid().v4(), // Generate temp ID for optimistic UI
      semesterId: semesterId,
      title: title,
      subjectId: selectedSubject?.id,
      subjectName: selectedSubject?.title,
      dueDate: selectedDate,
      createdAt: AppTime.now(),
    );

    try {
      if (isOnline) {
        await FirestoreService().createAssignment(uid, assignment);
      } else {
        final payload = jsonEncode({
          'id': assignment.id,
          'semesterId': assignment.semesterId,
          'title': assignment.title,
          'subjectId': assignment.subjectId,
          'subjectName': assignment.subjectName,
          'dueDate': assignment.dueDate.toIso8601String(),
          'isDone': assignment.isDone,
          'doneAt': assignment.doneAt?.toIso8601String(),
          'createdAt': assignment.createdAt.toIso8601String(),
        });
        await CacheDatabase().enqueueOperation('create_assignment', payload);
        // Toast removed: UI will optimistically show "To be synced"
      }
    } catch (e) {
      AppErrorHandler.showMessage('Error: $e');
    }
  }
}

class _HoverText extends StatefulWidget {
  final String text;
  const _HoverText({required this.text});

  @override
  State<_HoverText> createState() => _HoverTextState();
}

class _HoverTextState extends State<_HoverText> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0.0, _isHovered ? -1.5 : 0.0, 0.0),
        child: Text(widget.text),
      ),
    );
  }
}
