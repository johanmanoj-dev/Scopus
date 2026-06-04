import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/errors/app_exception.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/semester_provider.dart';
import '../../core/services/drive_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/google_auth_service.dart';
import '../../core/themes/app_theme.dart';
import '../../models/semester_model.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Platform.isAndroid) return _buildAndroid(context, ref);
    return _buildWindows(context, ref);
  }

  Widget _buildAndroid(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeSemester = ref.watch(activeSemesterProvider);
    final currentUser = GoogleAuthService().currentUser;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),

              // ── Account Section ───────────────────────────────────────────────
              Text('Account', style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F0F),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
                ),
                child: Row(
                  children: [
                    if (currentUser?.photoUrl != null)
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: NetworkImage(currentUser!.photoUrl!),
                      )
                    else
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                        child: Text(
                          currentUser?.name.substring(0, 1).toUpperCase() ?? 'S',
                          style: const TextStyle(
                            color: Color(0xFF60A5FA),
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUser?.name ?? 'Student User',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (currentUser?.email != null)
                            Text(
                              currentUser!.email,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _handleLogout(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.2)),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 32),

              // ── Active semester actions ───────────────────────────────────────
              if (activeSemester != null) ...[
                Text('Current Semester', style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildSettingsItem(
                  context: context,
                  icon: Icons.drive_file_rename_outline,
                  iconColor: const Color(0xFF346BD9),
                  title: 'Rename Semester',
                  subtitle: activeSemester.title,
                  onTap: () => _showRenameSemesterDialog(context, ref, activeSemester),
                ),
                const SizedBox(height: 12),
                _buildSettingsItem(
                  context: context,
                  icon: Icons.archive_outlined,
                  iconColor: Colors.redAccent,
                  title: 'Archive Semester',
                  subtitle: 'Move "${activeSemester.title}" to cold storage',
                  onTap: () => _showArchiveConfirmation(context, ref, activeSemester),
                ),
                const SizedBox(height: 48),
              ],
              
              // ── General ───────────────────────────────────────────────────────
              Text('General', style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildSettingsItem(
                context: context,
                icon: Icons.inventory_2_outlined,
                iconColor: Colors.white,
                title: 'Archived Semesters',
                subtitle: 'View past semesters (read-only)',
                onTap: () => _showArchivedSemesters(context, ref),
              ),
              const SizedBox(height: 12),
              _buildSettingsItem(
                context: context,
                icon: Icons.info_outline,
                iconColor: Colors.white,
                title: 'About',
                subtitle: 'Scopus — Academic Workspace',
                onTap: () => _showAboutDialog(context),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Sign out?',
          style: Theme.of(ctx).textTheme.titleLarge,
        ),
        content: Text(
          'You will need to sign in again to access your workspace.',
          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await GoogleAuthService().signOut();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign out: $e')),
        );
      }
    }
  }

  Widget _buildWindows(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeSemester = ref.watch(activeSemesterProvider);

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 48),

          // ── Active semester actions ─────────────────────────────────────────
          if (activeSemester != null) ...[
            Text('Current Semester', style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildSettingsItem(
              context: context,
              icon: Icons.drive_file_rename_outline,
              iconColor: const Color(0xFF346BD9),
              title: 'Rename Semester',
              subtitle: activeSemester.title,
              onTap: () => _showRenameSemesterDialog(context, ref, activeSemester),
            ),
            const SizedBox(height: 12),
            _buildSettingsItem(
              context: context,
              icon: Icons.archive_outlined,
              iconColor: Colors.redAccent,
              title: 'Archive Semester',
              subtitle: 'Move "${activeSemester.title}" to cold storage',
              onTap: () => _showArchiveConfirmation(context, ref, activeSemester),
            ),
            const SizedBox(height: 48),
          ],

          // ── General ───────────────────────────────────────────────────────
          Text('General', style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildSettingsItem(
            context: context,
            icon: Icons.inventory_2_outlined,
            iconColor: Colors.white,
            title: 'Archived Semesters',
            subtitle: 'View past semesters (read-only)',
            onTap: () => _showArchivedSemesters(context, ref),
          ),
          const SizedBox(height: 12),
          _buildSettingsItem(
            context: context,
            icon: Icons.info_outline,
            iconColor: Colors.white,
            title: 'About',
            subtitle: 'Scopus — Academic Workspace',
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          hoverColor: Colors.white.withValues(alpha: 0.02),
          splashColor: Colors.white.withValues(alpha: 0.05),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Rename Semester ─────────────────────────────────────────────────────────

  void _showRenameSemesterDialog(
      BuildContext context, WidgetRef ref, Semester semester) async {
    final controller = TextEditingController(text: semester.title);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 32),
        actionsPadding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
        title: const Text('Rename Semester', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Semester Name',
              prefixIcon: Icon(Icons.edit_outlined),
            ),
            onSubmitted: (_) {
              Navigator.pop(ctx);
              _renameSemester(ref, semester, controller.text);
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
              Navigator.pop(ctx);
              _renameSemester(ref, semester, controller.text);
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF346BD9)),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    await Future.delayed(const Duration(milliseconds: 300));
    controller.dispose();
  }

  Future<void> _renameSemester(
      WidgetRef ref, Semester semester, String newTitle) async {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty || trimmed == semester.title) return;
    try {
      final uid = ref.read(currentUidProvider);

      // 1. Update Firestore
      await FirestoreService()
          .updateSemester(uid, semester.id, {'title': trimmed});

      // 2. Rename Drive folder if Drive session available
      final authClient = GoogleAuthService().authClient;
      if (authClient == null) {
        AppErrorHandler.showDriveReconnect();
        return;
      }
      if (semester.driveFolderId.isNotEmpty) {
        await DriveService(authClient)
            .renameFolder(semester.driveFolderId, trimmed);
      }
      // semestersProvider stream auto-updates — sidebar + settings reflect new name
    } catch (e) {
      if (e is FirestoreException || e is DriveException) {
        AppErrorHandler.show(e as AppException);
      } else {
        AppErrorHandler.show(FirestoreException(
            'Failed to rename semester: $e',
            code: 'semester-rename-failed'));
      }
    }
  }

  // ── Archive Semester ────────────────────────────────────────────────────────

  void _showArchiveConfirmation(
      BuildContext context, WidgetRef ref, Semester semester) async {
    final confirmController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false, // force intentional cancel
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final inputMatches =
                confirmController.text.trim() == semester.title.trim();

            return AlertDialog(
              backgroundColor: AppTheme.surfaceVariant,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              titlePadding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
              contentPadding: const EdgeInsets.symmetric(horizontal: 32),
              actionsPadding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
              title: const Row(
                children: [
                  Icon(Icons.archive_outlined, color: Colors.redAccent),
                  SizedBox(width: 12),
                  Text('Archive Semester?', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Archiving this semester will:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _bulletPoint('Move all subjects and files to read-only cold storage'),
                      _bulletPoint('Require creating a new semester to continue'),
                      const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
                      ),
                      child: const Text(
                        'Archived semesters cannot be restored. You can view them and access files via Google Drive.',
                        style: TextStyle(fontSize: 13, height: 1.5, color: Colors.redAccent),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Type the semester name to confirm:',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: semester.title,
                        hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                        errorText: confirmController.text.isNotEmpty && !inputMatches ? 'Name does not match' : null,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                      onSubmitted: (_) {
                        if (inputMatches) {
                          Navigator.pop(ctx);
                          _archiveSemester(ref, semester);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                  },
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                FilledButton(
                  onPressed: inputMatches
                      ? () {
                          Navigator.pop(ctx);
                          _archiveSemester(ref, semester);
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    disabledBackgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                  ),
                  child: const Text('Archive Semester', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
    await Future.delayed(const Duration(milliseconds: 300));
    confirmController.dispose();
  }

  Future<void> _archiveSemester(WidgetRef ref, Semester semester) async {
    try {
      final uid = ref.read(currentUidProvider);
      await FirestoreService().archiveSemester(uid, semester.id);
      // Router auto-redirects to /no-semester when activeSemesterProvider
      // emits null (driven by ScopusApp's ref.listen).
    } catch (e) {
      AppErrorHandler.show(
        FirestoreException('Failed to archive semester: $e',
            code: 'semester-archive-failed'),
      );
    }
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 4),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  // ── Archived Semesters Dialog ───────────────────────────────────────────────

  void _showArchivedSemesters(BuildContext context, WidgetRef ref) {
    final archivedSemesters = ref.read(archivedSemestersProvider);
    final theme = Theme.of(context);
    final isAndroid = Platform.isAndroid;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceVariant,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: EdgeInsets.fromLTRB(isAndroid ? 24 : 32, isAndroid ? 24 : 32, isAndroid ? 24 : 32, 16),
          contentPadding: EdgeInsets.symmetric(horizontal: isAndroid ? 24 : 32),
          actionsPadding: EdgeInsets.fromLTRB(isAndroid ? 24 : 32, isAndroid ? 16 : 24, isAndroid ? 24 : 32, isAndroid ? 24 : 32),
          title: Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Archived Semesters', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SizedBox(
            width: isAndroid ? double.maxFinite : 460,
            child: archivedSemesters.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: Center(
                      child: Text(
                        'No archived semesters yet.',
                        style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.textSecondary),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: archivedSemesters.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (ctx, index) {
                      final s = archivedSemesters[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F0F0F),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: isAndroid ? 12 : 20, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: Colors.white.withValues(alpha: 0.05),
                            child: const Icon(Icons.school_outlined, color: Colors.white),
                          ),
                          title: Text(s.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          trailing: isAndroid
                              ? Icon(Icons.lock_outline, size: 20, color: AppTheme.textSecondary)
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock_outline, size: 14, color: AppTheme.textSecondary),
                                      const SizedBox(width: 6),
                                      Text('Read-only', style: theme.textTheme.labelMedium?.copyWith(color: AppTheme.textSecondary)),
                                    ],
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    final isAndroid = Platform.isAndroid;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceVariant,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: EdgeInsets.fromLTRB(isAndroid ? 24 : 32, isAndroid ? 24 : 32, isAndroid ? 24 : 32, 16),
          contentPadding: EdgeInsets.symmetric(horizontal: isAndroid ? 24 : 32),
          actionsPadding: EdgeInsets.fromLTRB(isAndroid ? 24 : 32, isAndroid ? 16 : 24, isAndroid ? 24 : 32, isAndroid ? 24 : 32),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.school, size: 64, color: Color(0xFF346BD9)),
              const SizedBox(height: 24),
              Text(
                'Scopus',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'v1.0.0',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 32),
              const Text(
                'Academic workspace powered by Google Drive & Firebase.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F0F),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Made by',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Johan P Manoj',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        final url = Uri.parse('https://github.com/johanmanoj-dev');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                        child: Text(
                          'github.com/johanmanoj-dev',
                          style: TextStyle(
                            color: Color(0xFF346BD9),
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFF346BD9),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                showLicensePage(
                  context: context,
                  applicationName: 'Scopus',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Icon(Icons.school, size: 48, color: Color(0xFF346BD9)),
                );
              },
              child: const Text('View Licenses', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
