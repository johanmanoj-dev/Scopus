import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/semester_provider.dart';
import '../../core/themes/app_theme.dart';
import '../../core/services/google_auth_service.dart';
import '../../core/utils/network_monitor.dart';
import '../../core/utils/sync_manager.dart';

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String location = GoRouterState.of(context).uri.toString();
    final activeSemester = ref.watch(activeSemesterProvider);
    final isOnline = ref.watch(networkStatusProvider).value ?? true;
    
    // Keep sync manager alive and listening
    ref.watch(syncManagerProvider);

    return Container(
      width: 250,
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Logo + Active Semester
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6), // Specific blue from mockup
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'S',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Scopus',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (activeSemester != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    activeSemester.title,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 8),
          // Navigation Items
          _SidebarItem(
            icon: Icons.bar_chart,
            activeIcon: Icons.bar_chart,
            label: 'Dashboard',
            isSelected: location == '/',
            onTap: () => context.go('/'),
          ),
          _SidebarItem(
            icon: Icons.folder_copy_outlined,
            activeIcon: Icons.folder_copy,
            label: 'Subjects',
            isSelected: location.startsWith('/subjects'),
            onTap: () => context.go('/subjects'),
          ),
          _SidebarItem(
            icon: Icons.assignment_outlined,
            activeIcon: Icons.assignment,
            label: 'Assignments',
            isSelected: location.startsWith('/assignments'),
            onTap: () => context.go('/assignments'),
          ),
          const Spacer(),
          _SidebarItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            label: 'Settings',
            isSelected: location.startsWith('/settings'),
            onTap: () => context.go('/settings'),
          ),
          if (!isOnline)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, size: 14, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      'Offline',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const _ProfileSidebarItem(
            label: 'Profile',
            isSelected: false,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHovered = ValueNotifier(false);

    return MouseRegion(
      onEnter: (_) => isHovered.value = true,
      onExit: (_) => isHovered.value = false,
      cursor: SystemMouseCursors.click,
      child: ValueListenableBuilder<bool>(
        valueListenable: isHovered,
        builder: (context, hovered, child) {
          final backgroundColor = isSelected 
              ? const Color(0xFF1E293B) // Slate 800 for active
              : hovered 
                  ? Colors.white.withValues(alpha: 0.05) 
                  : Colors.transparent;
          
          final contentColor = isSelected ? const Color(0xFF60A5FA) : AppTheme.textSecondary; // Blue 400 for active content
          final borderColor = isSelected ? const Color(0xFF3B82F6).withValues(alpha: 0.5) : Colors.transparent;

          return GestureDetector(
            onTap: onTap,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    color: contentColor,
                    size: 20,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: contentColor,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileSidebarItem extends StatelessWidget {
  final String label;
  final bool isSelected;

  const _ProfileSidebarItem({
    required this.label,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHovered = ValueNotifier(false);
    final currentUser = GoogleAuthService().currentUser;

    return MouseRegion(
      onEnter: (_) => isHovered.value = true,
      onExit: (_) => isHovered.value = false,
      cursor: SystemMouseCursors.click,
      child: ValueListenableBuilder<bool>(
        valueListenable: isHovered,
        builder: (context, hovered, child) {
          final backgroundColor = isSelected 
              ? AppTheme.primary.withValues(alpha: 0.15) 
              : hovered 
                  ? Colors.white.withValues(alpha: 0.05) 
                  : Colors.transparent;

          return GestureDetector(
            onTap: () {
              final RenderBox renderBox = context.findRenderObject() as RenderBox;
              final Offset offset = renderBox.localToGlobal(Offset.zero);
              
              final overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;

              showMenu(
                context: context,
                position: RelativeRect.fromSize(
                  Rect.fromLTWH(
                    offset.dx + 16, // Start inside the sidebar instead of right of it
                    offset.dy, // Anchor to the top edge of the profile button
                    renderBox.size.width - 32, // Width of the item
                    0,
                  ),
                  overlay.size,
                ),
                color: AppTheme.surfaceVariant,
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                items: <PopupMenuEntry<dynamic>>[
                  PopupMenuItem(
                    enabled: false,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (currentUser?.photoUrl != null)
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: NetworkImage(currentUser!.photoUrl!),
                          )
                        else
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                            child: const Icon(Icons.person, color: Color(0xFF60A5FA)),
                          ),
                        const SizedBox(width: 16),
                        Text(
                          currentUser?.name ?? 'Student User',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 24),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    onTap: () async {
                      // Close the menu first, then show confirmation dialog
                      await Future.delayed(const Duration(milliseconds: 200));
                      if (!context.mounted) return;
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
                              child: const Text('Cancel'),
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
                            SnackBar(content: Text('Failed to sign out: \$e')),
                          );
                        }
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.logout, size: 20, color: AppTheme.primaryVariant),
                        const SizedBox(width: 12),
                        Text(
                          'Logout',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.primaryVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  // ── Real Google profile photo ──────────────────
                  if (currentUser?.photoUrl != null)
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(currentUser!.photoUrl!),
                    )
                  else
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                      child: Text(
                        currentUser?.name.substring(0, 1).toUpperCase() ?? 'S',
                        style: const TextStyle(
                          color: Color(0xFF60A5FA),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentUser?.name ?? 'Student User',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (currentUser?.email != null)
                          Text(
                            currentUser!.email,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary.withValues(alpha: 0.7),
                              fontSize: 10,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
