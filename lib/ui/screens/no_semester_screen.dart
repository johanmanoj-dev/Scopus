import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/errors/app_exception.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/semester_provider.dart';
import '../../core/services/drive_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/google_auth_service.dart';
import '../../core/themes/app_theme.dart';
import '../../core/utils/app_time.dart';
import '../../models/semester_model.dart';
import '../widgets/app_primary_button.dart';

/// Shown when there is no active semester.
/// The user must create a new semester to access the main shell.
class NoSemesterScreen extends ConsumerStatefulWidget {
  const NoSemesterScreen({super.key});

  @override
  ConsumerState<NoSemesterScreen> createState() => _NoSemesterScreenState();
}

class _NoSemesterScreenState extends ConsumerState<NoSemesterScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _showCreateSemesterDialog() async {
    final titleController = TextEditingController();
    final isAndroid = Platform.isAndroid;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceVariant,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: EdgeInsets.fromLTRB(isAndroid ? 24 : 32, isAndroid ? 24 : 32, isAndroid ? 24 : 32, 16),
          contentPadding: EdgeInsets.symmetric(horizontal: isAndroid ? 24 : 32),
          actionsPadding: EdgeInsets.fromLTRB(isAndroid ? 24 : 32, isAndroid ? 16 : 24, isAndroid ? 24 : 32, isAndroid ? 24 : 32),
          title: Text(
            'New Semester',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Give your semester a name.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Semester Name',
                  hintText: 'e.g. Semester 4',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                onSubmitted: (_) {
                  Navigator.pop(context);
                  _createSemester(titleController.text);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _createSemester(titleController.text);
              },
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
              child: const Text('Start Semester'),
            ),
          ],
        );
      },
    );
    await Future.delayed(const Duration(milliseconds: 300));
    titleController.dispose();
  }

  Future<void> _createSemester(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;

    setState(() => _isCreating = true);
    try {
      final uid = ref.read(currentUidProvider);
      final authClient = GoogleAuthService().authClient;
      if (authClient == null) {
        AppErrorHandler.showDriveReconnect(
          onReconnected: () => _createSemester(trimmed),
        );
        setState(() => _isCreating = false);
        return;
      }

      // 1. Get root Drive folder ID from Firestore
      final rootFolderId = await FirestoreService().getRootFolderId(uid);
      if (rootFolderId == null || rootFolderId.isEmpty) {
        throw DriveException(
          'Workspace folder not found. Please sign out and sign in again.',
          code: 'no-root-folder',
        );
      }

      // 2. Create semester folder in Drive
      final drive = DriveService(authClient);
      final driveFolderId =
          await drive.createSemesterFolder(rootFolderId, trimmed);

      // 3. Save semester to Firestore
      final semester = Semester(
        id: '',         // Firestore auto-generates the ID
        title: trimmed,
        driveFolderId: driveFolderId,
        createdAt: AppTime.now(),
        isActive: true,
      );
      await FirestoreService().createSemester(uid, semester);

      // 4. No explicit navigation — activeSemesterProvider will emit the new
      //    semester, which triggers ScopusApp's ref.listen → router refreshes
      //    → redirect sends user to '/' automatically.
    } catch (e) {
      if (e is DriveException || e is FirestoreException) {
        AppErrorHandler.show(e as AppException);
      } else {
        AppErrorHandler.show(
          DriveException('Failed to create semester: $e',
              code: 'semester-create-failed'),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAndroid = Platform.isAndroid;

    // Read archived count from Riverpod — no dummy data
    final archivedCount =
        ref.watch(archivedSemestersProvider).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.textSecondary),
            tooltip: 'Sign out',
            onPressed: () async {
              await GoogleAuthService().signOut();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isAndroid ? double.infinity : 480),
                  child: Padding(
                    padding: EdgeInsets.all(isAndroid ? 24.0 : 48.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.account_balance,
                            color: AppTheme.primary,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Scopus',
                          style: theme.textTheme.displayMedium?.copyWith(
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No active semester',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Create a semester to start organising your subjects, files, and assignments.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppTheme.textSecondary,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          child: AppPrimaryButton(
                            onPressed: _isCreating ? null : _showCreateSemesterDialog,
                            icon: Icons.add,
                            label: 'Create Semester',
                            isLoading: _isCreating,
                            loadingLabel: 'Creating...',
                          ),
                        ),
                        if (archivedCount > 0) ...[
                          const SizedBox(height: 24),
                          Text(
                            '$archivedCount archived semester${archivedCount > 1 ? 's' : ''} available in Settings.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
