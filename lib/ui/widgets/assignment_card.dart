import 'package:flutter/material.dart';
import '../../models/assignment_model.dart';
import '../../core/themes/app_theme.dart';
import '../../core/utils/app_time.dart';
import 'package:intl/intl.dart';

class AssignmentCard extends StatefulWidget {
  final Assignment assignment;
  final bool isReadOnly;
  final ValueChanged<bool?>? onChanged;
  final VoidCallback? onDelete;

  const AssignmentCard({
    super.key,
    required this.assignment,
    this.isReadOnly = false,
    this.onChanged,
    this.onDelete,
  });

  @override
  State<AssignmentCard> createState() => _AssignmentCardState();
}

class _AssignmentCardState extends State<AssignmentCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = AppTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(widget.assignment.dueDate.year, widget.assignment.dueDate.month, widget.assignment.dueDate.day);
    final daysUntilDue = due.difference(today).inDays;
    
    Color statusColor;
    if (widget.assignment.isDone) {
      statusColor = AppTheme.accent; // Deep Green for done
    } else if (widget.assignment.isMissed) {
      statusColor = Colors.grey; // Grey for missed
    } else if (daysUntilDue <= 2) {
      statusColor = AppTheme.primaryVariant; // Red for urgent (<= 2 days)
    } else if (daysUntilDue <= 6) {
      statusColor = AppTheme.secondary; // Yellow for moderate (3-6 days)
    } else {
      statusColor = Colors.green.shade600; // Traffic light green for ample time (>= 7 days)
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.isReadOnly || widget.assignment.isPendingSync ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: Opacity(
        opacity: widget.assignment.isPendingSync ? 0.6 : 1.0,
        child: IgnorePointer(
          ignoring: widget.assignment.isPendingSync,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(20.0),
            transform: Matrix4.diagonal3Values(
              _isHovered && !widget.assignment.isPendingSync ? 1.01 : 1.0, 
              _isHovered && !widget.assignment.isPendingSync ? 1.01 : 1.0, 
              1.0
            ),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
          color: statusColor.withValues(alpha: _isHovered ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: statusColor.withValues(alpha: _isHovered ? 0.4 : 0.2),
            width: 1,
          ),
          boxShadow: _isHovered 
              ? [BoxShadow(color: statusColor.withValues(alpha: 0.15), blurRadius: 16, spreadRadius: 2)]
              : [],
        ),
        child: Row(
          children: [
          // Custom Checkbox / Status Indicator (Only on Assignments screen)
          if (!widget.isReadOnly) ...[
            GestureDetector(
              onTap: () {
                if (widget.onChanged != null) {
                  widget.onChanged!(!widget.assignment.isDone);
                }
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.assignment.isDone 
                        ? statusColor.withValues(alpha: 0.8)
                        : statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: widget.assignment.isDone
                      ? const Icon(Icons.check, size: 20, color: Colors.white)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 20),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.assignment.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    decoration: widget.assignment.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (widget.assignment.subjectName != null && widget.assignment.subjectName!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.assignment.subjectName!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                widget.assignment.isDone 
                    ? 'Done' 
                    : widget.assignment.isMissed 
                        ? 'Missed' 
                        : daysUntilDue == 0 
                            ? 'Due Today'
                            : 'Due in $daysUntilDue days',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.assignment.isDone && widget.assignment.doneAt != null
                    ? DateFormat('MMM d, yyyy').format(widget.assignment.doneAt!)
                    : DateFormat('MMM d, yyyy').format(widget.assignment.dueDate),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              if (widget.assignment.isPendingSync) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'To be synced',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (!widget.isReadOnly && widget.onDelete != null) ...[
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
              hoverColor: theme.colorScheme.error.withValues(alpha: 0.1),
              onPressed: widget.onDelete,
            ),
          ],
        ],
      ),
          ),
        ),
      ),
    );
  }
}
