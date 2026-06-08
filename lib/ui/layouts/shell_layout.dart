import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/themes/app_theme.dart';
import '../../core/utils/network_monitor.dart';
import '../../core/utils/sync_manager.dart';
import '../widgets/sidebar.dart';

class _OfflineBanner extends ConsumerWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize global SyncManager
    ref.watch(syncManagerProvider);

    final isOnline = ref.watch(networkStatusProvider).value ?? true;
    if (isOnline) return const SizedBox.shrink();
    if (!Platform.isAndroid) return const SizedBox.shrink(); // Windows already has an offline indicator

    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        color: Colors.grey.shade800, // Grey background for Android
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: const Text(
          'Offline - Changes will sync when reconnected',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class ShellLayout extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ShellLayout({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) return _buildAndroid(context);
    return _buildWindows(context);
  }

  Widget _buildAndroid(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (currentIndex != 0) {
          // If not on Dashboard, pressing back goes to Dashboard
          navigationShell.goBranch(0);
        } else {
          // If on Dashboard, close the app
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            const _OfflineBanner(),
            Expanded(child: navigationShell),
          ],
        ), // The navigationShell widget holds the AndroidSwipeShell we defined in app_router
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            backgroundColor: AppTheme.surface,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFF60A5FA),
            unselectedItemColor: AppTheme.textSecondary,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            elevation: 8,
            currentIndex: currentIndex,
            onTap: (index) {
              navigationShell.goBranch(
                index,
                // A common pattern: if tapping the current tab, reset the stack to the initial location
                initialLocation: index == navigationShell.currentIndex,
              );
            },
            items: const [
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.bar_chart),
                ),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.folder_copy_outlined),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.folder_copy),
                ),
                label: 'Subjects',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.assignment_outlined),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.assignment),
                ),
                label: 'Assignments',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.settings_outlined),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.settings),
                ),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWindows(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const _OfflineBanner(),
          Expanded(
            child: Row(
              children: [
                const Sidebar(),
                Expanded(
                  child: navigationShell, // On Windows, navigationShell just renders the active branch
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A custom widget that wraps the GoRouter branches in a swipeable PageView for Android.
class AndroidSwipeShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  const AndroidSwipeShell({
    super.key,
    required this.navigationShell,
    required this.children,
  });

  @override
  State<AndroidSwipeShell> createState() => _AndroidSwipeShellState();
}

class _AndroidSwipeShellState extends State<AndroidSwipeShell> {
  late PageController _pageController;
  bool _isNavigatingFromTap = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.navigationShell.currentIndex);
  }

  @override
  void didUpdateWidget(covariant AndroidSwipeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex != widget.navigationShell.currentIndex) {
      _isNavigatingFromTap = true;
      final int diff = (oldWidget.navigationShell.currentIndex - widget.navigationShell.currentIndex).abs();
      
      if (diff == 1) {
        // Only animate if adjacent, to prevent PageView from firing onPageChanged for middle pages
        _pageController.animateToPage(
          widget.navigationShell.currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ).then((_) {
          if (mounted) setState(() => _isNavigatingFromTap = false);
        });
      } else {
        _pageController.jumpToPage(widget.navigationShell.currentIndex);
        setState(() => _isNavigatingFromTap = false);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      onPageChanged: (index) {
        // Only trigger GoRouter branch change if the page change was a physical swipe, not a tap
        if (!_isNavigatingFromTap && index != widget.navigationShell.currentIndex) {
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        }
      },
      children: widget.children,
    );
  }
}
