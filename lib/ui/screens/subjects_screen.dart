import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/database/cache_database.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/errors/app_exception.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/semester_provider.dart';
import '../../core/providers/subject_provider.dart';
import '../../core/providers/file_provider.dart';
import '../../core/services/drive_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/google_auth_service.dart';
import '../../core/themes/app_theme.dart';
import '../../core/utils/network_monitor.dart';
import '../../core/utils/app_time.dart';
import '../../models/subject_model.dart';
import '../widgets/riverpod_error_state.dart';
import '../widgets/app_primary_button.dart';

class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Platform.isAndroid) return _buildAndroid(context, ref);
    return _buildWindows(context, ref);
  }

  Widget _buildAndroid(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeSemester = ref.watch(activeSemesterProvider);

    final subjectsAsync = activeSemester != null
        ? ref.watch(subjectsProvider(activeSemester.id))
        : const AsyncValue<List<Subject>>.data([]);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: activeSemester == null
          ? null
          : FloatingActionButton(
              backgroundColor: const Color(0xFF60A5FA),
              onPressed: () => _showAddSubjectDialog(context, ref, activeSemester.id, activeSemester.driveFolderId),
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text('Subjects', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
              if (activeSemester != null) ...[
                const SizedBox(height: 4),
                Consumer(
                  builder: (context, ref, _) {
                    final subjectsAsync = ref.watch(subjectsProvider(activeSemester.id));
                    return Text(
                      '${activeSemester.title} - ${subjectsAsync.valueOrNull?.length ?? 0} courses',
                      style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary),
                    );
                  }
                ),
              ],
              const SizedBox(height: 24),
              Expanded(
                child: subjectsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => RiverpodErrorState(
                    error: e,
                    customMessage: 'Failed to load subjects',
                    onRetry: () => ref.invalidate(subjectsProvider(activeSemester!.id)),
                  ),
                  data: (subjects) => subjects.isEmpty
                      ? Center(
                          child: Text(
                            'No subjects yet. Add your first subject!',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.15,
                          ),
                          itemCount: subjects.length,
                          itemBuilder: (context, index) =>
                              _SubjectCard(subject: subjects[index]),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWindows(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeSemester = ref.watch(activeSemesterProvider);

    // If no active semester, subjects list is empty (router handles redirect)
    final subjectsAsync = activeSemester != null
        ? ref.watch(subjectsProvider(activeSemester.id))
        : const AsyncValue<List<Subject>>.data([]);

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subjects', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                  if (activeSemester != null) ...[
                    const SizedBox(height: 8),
                    Consumer(
                      builder: (context, ref, _) {
                        final subjectsAsync = ref.watch(subjectsProvider(activeSemester.id));
                        return Text(
                          '${activeSemester.title} - ${subjectsAsync.valueOrNull?.length ?? 0} courses',
                          style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary),
                        );
                      }
                    ),
                  ],
                ],
              ),
              AppPrimaryButton(
                onPressed: activeSemester == null
                    ? null
                    : () => _showAddSubjectDialog(context, ref,
                        activeSemester.id, activeSemester.driveFolderId),
                icon: Icons.add,
                label: 'Add Subject',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Divider(color: Colors.white.withValues(alpha: 0.05)),
          const SizedBox(height: 24),
          Expanded(
            child: subjectsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => RiverpodErrorState(
                error: e,
                customMessage: 'Failed to load subjects',
                onRetry: () => ref.invalidate(subjectsProvider(activeSemester!.id)),
              ),
              data: (subjects) => subjects.isEmpty
                  ? Center(
                      child: Text(
                        'No subjects yet. Add your first subject!',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: AppTheme.textSecondary),
                      ),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 250,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                        childAspectRatio: 1.25,
                      ),
                      itemCount: subjects.length,
                      itemBuilder: (context, index) =>
                          _SubjectCard(subject: subjects[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSubjectDialog(
    BuildContext context,
    WidgetRef ref,
    String semesterId,
    String semesterDriveFolderId,
  ) {
    final titleController = TextEditingController();
    bool hasError = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceVariant,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              titlePadding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
              contentPadding: const EdgeInsets.symmetric(horizontal: 32),
              actionsPadding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
              title: const Text('Add Subject', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 420,
                child: TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Subject Name',
                    hintText: 'e.g. Physics, Mathematics',
                    prefixIcon: const Icon(Icons.subject),
                    errorText: hasError ? 'Please enter a subject name' : null,
                  ),
                  onChanged: (val) {
                    if (hasError && val.trim().isNotEmpty) {
                      setDialogState(() => hasError = false);
                    }
                  },
                  onSubmitted: (_) {
                    if (titleController.text.trim().isEmpty) {
                      setDialogState(() => hasError = true);
                      return;
                    }
                    Navigator.pop(ctx);
                    _createSubject(ref, semesterId, semesterDriveFolderId, titleController.text);
                  },
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
                      setDialogState(() => hasError = true);
                      return;
                    }
                    Navigator.pop(ctx);
                    _createSubject(ref, semesterId, semesterDriveFolderId, titleController.text);
                  },
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF346BD9)),
                  child: const Text('Add'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _createSubject(
    WidgetRef ref,
    String semesterId,
    String semesterDriveFolderId,
    String title,
  ) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;

    final isOnline = ref.read(networkStatusProvider).value ?? true;
    if (!isOnline) {
      AppErrorHandler.showMessage('You are offline. Adding a subject requires an internet connection.');
      return;
    }

    try {
      final uid = ref.read(currentUidProvider);
      final authClient = GoogleAuthService().authClient;
      if (authClient == null) {
        AppErrorHandler.showDriveReconnect();
        return;
      }

      // 1. Create subject folder in Drive inside semester folder
      final drive = DriveService(authClient);
      final driveFolderId =
          await drive.createSubjectFolder(semesterDriveFolderId, trimmed);

      // 2. Save subject to Firestore
      final subject = Subject(
        id: '',
        semesterId: semesterId,
        title: trimmed,
        driveFolderId: driveFolderId,
        createdAt: AppTime.now(),
      );
      await FirestoreService().createSubject(uid, subject);

      // subjectsProvider stream auto-updates — no setState needed
    } catch (e) {
      if (e is DriveException || e is FirestoreException) {
        AppErrorHandler.show(e as AppException);
      } else {
        AppErrorHandler.show(
          DriveException('Failed to add subject: $e',
              code: 'subject-create-failed'),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subject Card — with hover-revealed rename / delete options
// ─────────────────────────────────────────────────────────────────────────────

enum _SubjectAction { rename, delete }

class _SubjectCard extends ConsumerStatefulWidget {
  final Subject subject;
  const _SubjectCard({required this.subject});

  @override
  ConsumerState<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends ConsumerState<_SubjectCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subject = widget.subject;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        fit: StackFit.expand, // fill the GridView cell — keeps Card & button aligned
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0.0, _hovered ? -2.0 : 0.0, 0.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _hovered ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.go('/subjects/${subject.id}'),
                  hoverColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  splashColor: Colors.white.withValues(alpha: 0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOutCubic,
                          color: _hovered ? const Color(0xFF141414) : const Color(0xFF0F0F0F),
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subject.title,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                      Container(
                        color: const Color(0xFF0F0F0F),
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Consumer(
                              builder: (context, ref, child) {
                                final filesAsync = ref.watch(filesProvider(subject.id));
                                return Text(
                                  filesAsync.when(
                                    data: (files) => '${files.length} files',
                                    loading: () => 'Loading...',
                                    error: (e, _) => 'Error',
                                  ),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                            Icon(
                              Icons.play_arrow,
                              size: 16,
                              color: AppTheme.textSecondary.withValues(alpha: 0.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Options button — fades in on hover (always visible on Android) ────────────────────
          Positioned(
            top: 8,
            right: 8,
            child: AnimatedOpacity(
              opacity: (Platform.isAndroid || _hovered) ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: IgnorePointer(
                ignoring: !(Platform.isAndroid || _hovered),
                child: PopupMenuButton<_SubjectAction>(
                  tooltip: 'Options',
                  offset: const Offset(0, 36),
                  onSelected: (action) {
                    if (action == _SubjectAction.rename) {
                      _showRenameDialog(context);
                    } else if (action == _SubjectAction.delete) {
                      _showDeleteDialog(context);
                    }
                  },
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  color: AppTheme.surfaceVariant,
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: _SubjectAction.rename,
                      child: ListTile(
                        leading: Icon(Icons.drive_file_rename_outline,
                            size: 20),
                        title: Text('Rename'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: _SubjectAction.delete,
                      child: ListTile(
                        leading: Icon(Icons.delete_outline,
                            size: 20, color: AppTheme.primary),
                        title: Text('Delete',
                            style: const TextStyle(
                                color: AppTheme.primary)),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.textSecondary
                              .withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.more_horiz,
                        size: 16, color: AppTheme.textSecondary),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Rename ─────────────────────────────────────────────────────────

  void _showRenameDialog(BuildContext context) {
    final controller =
        TextEditingController(text: widget.subject.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename Subject'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration:
              const InputDecoration(labelText: 'Subject Name'),
          onSubmitted: (_) {
            Navigator.pop(ctx);
            _renameSubject(controller.text);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _renameSubject(controller.text);
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameSubject(String newTitle) async {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty || trimmed == widget.subject.title) return;

    final isOnline = ref.read(networkStatusProvider).value ?? true;
    if (!isOnline) {
      AppErrorHandler.showMessage('You are offline. Renaming a subject requires an internet connection.');
      return;
    }

    try {
      final uid = ref.read(currentUidProvider);

      // 1. Update Firestore
      await FirestoreService()
          .updateSubject(uid, widget.subject.id, {'title': trimmed});

      // 2. Rename Drive folder if session is available
      final authClient = GoogleAuthService().authClient;
      if (authClient == null) {
        // Firestore already updated — Drive rename is deferred; user can reconnect
        AppErrorHandler.showDriveReconnect();
        return;
      }
      if (widget.subject.driveFolderId.isNotEmpty) {
        await DriveService(authClient)
            .renameFolder(widget.subject.driveFolderId, trimmed);
      }
      // subjectsProvider stream auto-updates
    } catch (e) {
      if (e is FirestoreException || e is DriveException) {
        AppErrorHandler.show(e as AppException);
      } else {
        AppErrorHandler.show(FirestoreException(
            'Failed to rename subject: $e',
            code: 'subject-rename-failed'));
      }
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppTheme.primary),
            SizedBox(width: 12),
            Text('Delete Subject?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deleting "${widget.subject.title}" will:',
                style:
                    const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
                '• Remove this subject from your semester'),
            const SizedBox(height: 4),
            const Text(
                '• Move its Drive folder to Trash (recoverable from Google Drive)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteSubject();
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSubject() async {
    final isOnline = ref.read(networkStatusProvider).value ?? true;
    if (!isOnline) {
      AppErrorHandler.showMessage('You are offline. Deleting a subject requires an internet connection.');
      return;
    }

    try {
      final uid = ref.read(currentUidProvider);

      // 1. Delete Firestore document AND all its file metadata documents.
      //    (Firestore does not cascade-delete subcollections automatically)
      await FirestoreService().deleteSubjectWithFiles(uid, widget.subject.id);

      // 2. Trash Drive folder if session is available
      final authClient = GoogleAuthService().authClient;
      if (authClient == null) {
        AppErrorHandler.showDriveReconnect();
        return;
      }
      if (widget.subject.driveFolderId.isNotEmpty) {
        await DriveService(authClient)
            .trashFolder(widget.subject.driveFolderId);
      }

      // 3. Clear the SQLite cache records for all files in this subject.
      await CacheDatabase().clearSubjectCache(widget.subject.id);

      // 4. Delete the physical cache directory for this subject
      final appSupportDir = await getApplicationSupportDirectory();
      final subjectDir = Directory(p.join(appSupportDir.path, 'cache', widget.subject.id));
      if (subjectDir.existsSync()) {
        subjectDir.deleteSync(recursive: true);
      }

      // subjectsProvider stream auto-updates — card disappears automatically
    } catch (e) {
      if (e is FirestoreException || e is DriveException) {
        AppErrorHandler.show(e as AppException);
      } else {
        AppErrorHandler.show(FirestoreException(
            'Failed to delete subject: $e',
            code: 'subject-delete-failed'));
      }
    }
  }
}
