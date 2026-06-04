import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/semester_provider.dart';
import '../../core/providers/assignment_provider.dart';
import '../../core/themes/app_theme.dart';
import '../../core/utils/app_time.dart';
import '../widgets/assignment_card.dart';
import '../widgets/riverpod_error_state.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Platform.isAndroid) return _buildAndroid(context, ref);
    return _buildWindows(context, ref);
  }

  // ── Android Layout ──────────────────────────────────────────────────────────
  Widget _buildAndroid(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeSemester = ref.watch(activeSemesterProvider);
    if (activeSemester == null) {
      return const SizedBox.shrink();
    }

    final assignmentsAsync = ref.watch(assignmentsProvider(activeSemester.id));

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                activeSemester.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              const _TimeBox(),
              const SizedBox(height: 32),
              Text('Pending Assignments', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              assignmentsAsync.when(
                loading: () => const Center(child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                )),
                error: (e, _) => RiverpodErrorState(
                  error: e,
                  customMessage: 'Failed to load assignments',
                  onRetry: () => ref.invalidate(assignmentsProvider(activeSemester.id)),
                ),
                data: (assignments) {
                  final pendingAssignments = assignments
                      .where((a) => !a.isDone && !a.isMissed)
                      .toList();

                  return Column(
                    children: [
                      if (pendingAssignments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32.0),
                          child: Center(
                            child: Text(
                              'No pending assignments',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        )
                      else
                        ...pendingAssignments.map((a) => Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: AssignmentCard(
                                assignment: a,
                                isReadOnly: true,
                              ),
                            )),
                      const SizedBox(height: 24),
                      // Stats Grid
                      Builder(
                        builder: (context) {
                          final doneCount = assignments.where((a) => a.isDone).length;
                          final missedCount = assignments.where((a) => a.isMissed).length;
                          final activeCount = assignments.length - doneCount - missedCount;
                          final completionRate = assignments.isEmpty ? 0 : ((doneCount / assignments.length) * 100).round();

                          return Column(
                            children: [
                              Row(
                                children: [
                                  _StatCard(
                                    title: 'ACTIVE',
                                    value: '$activeCount',
                                  ),
                                  const SizedBox(width: 12),
                                  _StatCard(
                                    title: 'DONE',
                                    value: '$doneCount',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _StatCard(
                                    title: 'MISSED',
                                    value: '$missedCount',
                                  ),
                                  const SizedBox(width: 12),
                                  _StatCard(
                                    title: 'COMPLETION',
                                    value: '$completionRate%',
                                  ),
                                ],
                              ),
                            ],
                          );
                        }
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Windows Layout (unchanged) ──────────────────────────────────────────────
  Widget _buildWindows(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // activeSemesterProvider is guaranteed non-null here — the router
    // redirects to /no-semester if it's null, so this screen is never
    // shown without an active semester.
    final activeSemester = ref.watch(activeSemesterProvider);
    if (activeSemester == null) {
      return const SizedBox.shrink(); // Guarded by router — should not show
    }

    final assignmentsAsync = ref.watch(assignmentsProvider(activeSemester.id));

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dashboard', style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    activeSemester.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const _TimeBox(),
            ],
          ),
          const SizedBox(height: 32),
          Text('Pending Assignments', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: assignmentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => RiverpodErrorState(
                error: e,
                customMessage: 'Failed to load assignments',
                onRetry: () => ref.invalidate(assignmentsProvider(activeSemester.id)),
              ),
              data: (assignments) {
                final pendingAssignments = assignments
                    .where((a) => !a.isDone && !a.isMissed)
                    .toList();

                return Column(
                  children: [
                    Expanded(
                      child: pendingAssignments.isEmpty
                          ? Center(
                              child: Text(
                                'No pending assignments',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: pendingAssignments.length,
                              itemBuilder: (context, index) => AssignmentCard(
                                assignment: pendingAssignments[index],
                                isReadOnly: true,
                              ),
                            ),
                    ),
                    const SizedBox(height: 32),
                    // Stats Row
                    Builder(
                      builder: (context) {
                        final doneCount = assignments.where((a) => a.isDone).length;
                        final missedCount = assignments.where((a) => a.isMissed).length;
                        final activeCount = assignments.length - doneCount - missedCount;
                        final completionRate = assignments.isEmpty ? 0 : ((doneCount / assignments.length) * 100).round();

                        return Row(
                          children: [
                            _StatCard(
                              title: 'ACTIVE',
                              value: '$activeCount',
                            ),
                            const SizedBox(width: 12),
                            _StatCard(
                              title: 'DONE',
                              value: '$doneCount',
                            ),
                            const SizedBox(width: 12),
                            _StatCard(
                              title: 'MISSED',
                              value: '$missedCount',
                            ),
                            const SizedBox(width: 12),
                            _StatCard(
                              title: 'COMPLETION',
                              value: '$completionRate%',
                            ),
                          ],
                        );
                      }
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatefulWidget {
  final String title;
  final String value;

  const _StatCard({
    required this.title,
    required this.value,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          transform: Matrix4.translationValues(0.0, _isHovered ? -4.0 : 0.0, 0.0),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant.withValues(alpha: _isHovered ? 0.8 : 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: _isHovered ? 0.15 : 0.05)),
            boxShadow: _isHovered 
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeBox extends StatefulWidget {
  const _TimeBox();

  @override
  State<_TimeBox> createState() => _TimeBoxState();
}

class _TimeBoxState extends State<_TimeBox> {
  late Timer _timer;
  late DateTime _currentTime;

  @override
  void initState() {
    super.initState();
    _currentTime = AppTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = AppTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) return _buildAndroid(context);
    return _buildWindows(context);
  }

  Widget _buildAndroid(BuildContext context) {
    final dateFormatter = DateFormat('MM/dd/yyyy');
    final timeFormatter = DateFormat('hh:mm a');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateFormatter.format(_currentTime),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            timeFormatter.format(_currentTime),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWindows(BuildContext context) {
    final dateFormatter = DateFormat('dd/MM/yyyy');
    final timeFormatter = DateFormat('hh:mm a');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            dateFormatter.format(_currentTime),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            timeFormatter.format(_currentTime),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
