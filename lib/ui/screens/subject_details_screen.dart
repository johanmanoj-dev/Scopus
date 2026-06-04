import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/database/cache_database.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/file_provider.dart';
import '../../core/providers/semester_provider.dart';
import '../../core/providers/subject_provider.dart';
import '../../core/services/drive_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/google_auth_service.dart';
import '../../core/themes/app_theme.dart';
import '../../core/utils/app_time.dart';
import '../../core/utils/network_monitor.dart';
import '../../models/subject_model.dart';
import '../widgets/app_primary_button.dart';

/// Shows the details of a single subject — file list and upload button.
///
/// Loads the subject from the live [subjectsProvider] by matching [subjectId].
/// File listing and upload are Phase 3 features; this screen shows the
/// subject name and an empty state until then.
class SubjectDetailsScreen extends ConsumerWidget {
  final String subjectId;
  const SubjectDetailsScreen({super.key, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeSemester = ref.watch(activeSemesterProvider);

    final subjectsAsync = activeSemester != null
        ? ref.watch(subjectsProvider(activeSemester.id))
        : const AsyncValue<List<Subject>>.data([]);

    return subjectsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error loading subject: $e',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppTheme.textSecondary)),
      ),
      data: (subjects) {
        final subject = subjects.where((s) => s.id == subjectId).firstOrNull;

        if (subject == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Subject not found.',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => context.go('/subjects'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Subjects'),
                ),
              ],
            ),
          );
        }

        return _SubjectDetailsBody(subject: subject);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body — extracted so it only builds when subject is available
// ─────────────────────────────────────────────────────────────────────────────

class _SubjectDetailsBody extends ConsumerWidget {
  final Subject subject;
  const _SubjectDetailsBody({required this.subject});

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Platform.isAndroid) return _buildAndroid(context, ref);
    return _buildWindows(context, ref);
  }

  Widget _buildAndroid(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filesAsync = ref.watch(filesProvider(subject.id));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _uploadFile(context, ref),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go('/subjects'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      subject.title,
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── File List ────────────────────────────────────────────
              Expanded(
                child: filesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text('Error loading files: $e',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppTheme.textSecondary)),
                  ),
                  data: (files) {
                    if (files.isEmpty) {
                      return Center(
                        child: Text(
                          'No files yet.\nTap + to upload your first file.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: files.length,
                      itemBuilder: (context, index) {
                        final file = files[index];
                        final isPdf = file.mimeType == 'application/pdf';

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppTheme.secondary.withValues(alpha: 0.2),
                              child: Icon(
                                isPdf ? Icons.picture_as_pdf : Icons.image,
                                color: AppTheme.secondary,
                              ),
                            ),
                            title: Text(
                              file.name,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                '${file.mimeType} • ${file.displaySize}\nUploaded: ${_formatDate(file.uploadedAt)}',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: AppTheme.textSecondary),
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: theme.colorScheme.error,
                              onPressed: () => _deleteFile(context, file, ref),
                            ),
                            onTap: () => _openFile(context, file),
                          ),
                        );
                      },
                    );
                  },
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
    final filesAsync = ref.watch(filesProvider(subject.id));

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/subjects'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  subject.title,
                  style: theme.textTheme.displayMedium,
                ),
              ),
              AppPrimaryButton(
                onPressed: () => _uploadFile(context, ref),
                icon: Icons.upload_file,
                label: 'Add Notes / PDF',
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ── File List ────────────────────────────────────────────
          Expanded(
            child: filesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Error loading files: $e',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppTheme.textSecondary)),
              ),
              data: (files) {
                if (files.isEmpty) {
                  return Center(
                    child: Text(
                      'No files yet.\nTap + to upload your first file.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: AppTheme.textSecondary),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index];
                    final isPdf = file.mimeType == 'application/pdf';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.secondary.withValues(alpha: 0.2),
                          child: Icon(
                            isPdf ? Icons.picture_as_pdf : Icons.image,
                            color: AppTheme.secondary,
                          ),
                        ),
                        title: Text(
                          file.name,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            '${file.mimeType} • ${file.displaySize} • Uploaded: ${_formatDate(file.uploadedAt)}',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Open'),
                              onPressed: () => _openFile(context, file),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: theme.colorScheme.error,
                              onPressed: () => _deleteFile(context, file, ref),
                            ),
                          ],
                        ),
                        onTap: () => _openFile(context, file),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadFile(BuildContext context, WidgetRef ref) async {
    final isOnline = ref.read(networkStatusProvider).value ?? true;
    if (!isOnline) {
      AppErrorHandler.showMessage('You are offline. Uploading files requires an internet connection.');
      return;
    }

    final authClient = GoogleAuthService().authClient;
    if (authClient == null) {
      AppErrorHandler.showDriveReconnect(
        onReconnected: () => _uploadFile(context, ref),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path!;
    final file = File(path);
    final size = file.lengthSync();

    if (size > 30 * 1024 * 1024) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File too large. Maximum size is 30 MB.')),
      );
      return;
    }

    final fileName = result.files.single.name;
    final extension = fileName.split('.').last.toLowerCase();
    String mimeType = 'application/pdf';
    if (extension == 'jpg' || extension == 'jpeg') mimeType = 'image/jpeg';
    if (extension == 'png') mimeType = 'image/png';

    if (!context.mounted) return;
    final progressNotifier = ValueNotifier<({int sent, int total})>((sent: 0, total: size));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        title: Text('Uploading $fileName'),
        content: ValueListenableBuilder<({int sent, int total})>(
          valueListenable: progressNotifier,
          builder: (context, progress, child) {
            final sentMB = (progress.sent / (1024 * 1024)).toStringAsFixed(2);
            final totalMB = (progress.total / (1024 * 1024)).toStringAsFixed(2);
            final percent = progress.total > 0 ? progress.sent / progress.total : 0.0;
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: percent),
                const SizedBox(height: 8),
                Text('$sentMB MB / $totalMB MB', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
              ],
            );
          },
        ),
      ),
    );

    try {
      final bytes = await file.readAsBytes();
      final uploadResult = await DriveService(authClient).uploadFile(
        parentFolderId: subject.driveFolderId,
        fileName: fileName,
        mimeType: mimeType,
        fileBytes: bytes,
        onProgress: (sent, total) {
          progressNotifier.value = (sent: sent, total: total);
        },
      );

      final subjectFile = SubjectFile(
        id: '',
        name: fileName,
        driveFileId: uploadResult.driveFileId,
        mimeType: mimeType,
        sizeBytes: size,
        uploadedAt: AppTime.now(),
      );

      final uid = ref.read(currentUidProvider);
      await FirestoreService().createFileMetadata(uid, subject.id, subjectFile);
    } catch (e) {
      if (context.mounted) {
        AppErrorHandler.showMessage('Upload failed: $e');
      }
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  Future<void> _openFile(BuildContext context, SubjectFile file) async {
    final authClient = GoogleAuthService().authClient;
    if (authClient == null) {
      AppErrorHandler.showDriveReconnect(
        onReconnected: () => _openFile(context, file),
      );
      return;
    }

    bool dialogOpen = false;
    try {
      final cacheDb = CacheDatabase();
      final localPath = await cacheDb.getLocalPath(file.driveFileId);

      if (localPath != null && File(localPath).existsSync()) {
        if (Platform.isAndroid) {
          final result = await OpenFilex.open(localPath);
          if (result.type != ResultType.done && context.mounted) {
            AppErrorHandler.showMessage('No application found to open this file type.');
          }
        } else {
          final cacheUri = Uri.file(localPath);
          if (!await canLaunchUrl(cacheUri)) {
            if (context.mounted) {
              AppErrorHandler.showMessage('No application found to open this file type.');
            }
            return;
          }
          await launchUrl(cacheUri, mode: LaunchMode.platformDefault);
        }
        return;
      }

      if (!context.mounted) return;
      dialogOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surfaceVariant,
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              Expanded(child: Text('Downloading ${file.name}...')),
            ],
          ),
        ),
      );

      final url = Uri.parse(
          'https://www.googleapis.com/drive/v3/files/${file.driveFileId}?alt=media');
      final response = await authClient.get(url);

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final appSupportDir = await getApplicationSupportDirectory();
      final subjectDir =
          Directory(p.join(appSupportDir.path, 'cache', subject.id));
      await subjectDir.create(recursive: true);

      final newLocalPath =
          p.join(subjectDir.path, '${file.driveFileId}_${file.name}');
      await File(newLocalPath).writeAsBytes(response.bodyBytes);

      await cacheDb.insertCache(
          file.driveFileId, newLocalPath, subject.id, file.name);

      if (context.mounted && dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }

      if (Platform.isAndroid) {
        final result = await OpenFilex.open(newLocalPath);
        if (result.type != ResultType.done && context.mounted) {
          AppErrorHandler.showMessage('No application found to open this file type.');
        }
      } else {
        final fileUri = Uri.file(newLocalPath);
        if (!await canLaunchUrl(fileUri)) {
          if (context.mounted) {
            AppErrorHandler.showMessage('No application found to open this file type.');
          }
          return;
        }
        await launchUrl(fileUri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (context.mounted) {
        if (dialogOpen) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        AppErrorHandler.showMessage('Download failed: $e');
      }
    }
  }

  void _deleteFile(BuildContext context, SubjectFile file, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            const Text('Delete File?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deleting "${file.name}" will:',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('• Remove this file from your subject'),
            const SizedBox(height: 4),
            const Text('• Move it to Google Drive Trash (recoverable)'),
            const SizedBox(height: 4),
            const Text('• Delete any downloaded local copy'),
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
              _performFileDeletion(context, file, ref);
            },
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _performFileDeletion(
      BuildContext context, SubjectFile file, WidgetRef ref) async {
    final isOnline = ref.read(networkStatusProvider).value ?? true;
    if (!isOnline) {
      AppErrorHandler.showMessage('You are offline. Deleting files requires an internet connection.');
      return;
    }

    final authClient = GoogleAuthService().authClient;
    if (authClient == null) {
      AppErrorHandler.showDriveReconnect(
        onReconnected: () => _performFileDeletion(context, file, ref),
      );
      return;
    }

    try {
      // 1. Trash in Drive
      await DriveService(authClient).trashFile(file.driveFileId);

      // 2. Delete Firestore Metadata
      final uid = ref.read(currentUidProvider);
      await FirestoreService().deleteFileMetadata(uid, subject.id, file.id);

      // 3. Delete Physical Cached File
      final cacheDb = CacheDatabase();
      final localPath = await cacheDb.getLocalPath(file.driveFileId);
      if (localPath != null) {
        final localFile = File(localPath);
        if (localFile.existsSync()) {
          localFile.deleteSync();
        }
      }

      // 4. Clear SQLite Cache Record
      await cacheDb.deleteCache(file.driveFileId);
    } catch (e) {
      if (context.mounted) {
        AppErrorHandler.showMessage('Failed to delete file: $e');
      }
    }
  }
}
