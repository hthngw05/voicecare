import 'package:flutter/material.dart';
import '../api/care_voice_api.dart';
import '../data/sample_data.dart';
import '../models/senior.dart';
import '../theme/app_theme.dart';
import '../widgets/polling_view.dart';
import '../widgets/status_chip.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _filter = 'all'; // 'all' | 'active' | 'resolved'

  void _setFilter(String f) => setState(() => _filter = f);

  @override
  Widget build(BuildContext context) {
    return PollingView<List<AlertRecord>>(
      // Keyed by filter so switching tabs refetches immediately.
      key: ValueKey(_filter),
      fetch: () => CareVoiceApi.instance.refreshAlerts(state: _filter),
      builder: (context, alerts, refresh) {
        final activeCount = alerts.where((a) => !a.resolved).length;
        final resolvedCount = alerts.where((a) => a.resolved).length;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            const Text(
              'Alerts',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              _filter == 'all'
                  ? '$activeCount active · $resolvedCount resolved'
                  : _filter == 'active'
                      ? '${alerts.length} active'
                      : '${alerts.length} resolved',
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filter == 'all',
                  onTap: () => _setFilter('all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Active',
                  selected: _filter == 'active',
                  onTap: () => _setFilter('active'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Resolved',
                  selected: _filter == 'resolved',
                  onTap: () => _setFilter('resolved'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...alerts.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AlertTile(record: a),
                )),
            if (alerts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text(
                    'No alerts in this view',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandDark : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.brandDark
                : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final AlertRecord record;
  const _AlertTile({required this.record});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.seniorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                StatusChip(level: record.level, compact: true),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.flag_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    record.trigger,
                    style: const TextStyle(fontSize: 13, height: 1.35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.bolt_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    record.action,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            // Show the live escalation ladder only for ACTIVE urgent/emergency
            // alerts. Once resolved, escalation is stood down (the resolved
            // chip below conveys that).
            if (!record.resolved &&
                (record.level == AlertLevel.urgent ||
                    record.level == AlertLevel.emergency) &&
                record.escalation.isNotEmpty) ...[
              const SizedBox(height: 12),
              _EscalationTimeline(record: record),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${fmtDateTimeSgt(record.triggeredAt)} · ${relativeTime(record.triggeredAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (record.resolved)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.statusGreenSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              size: 12, color: AppColors.statusGreen),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              record.respondedBy != null
                                  ? 'Resolved by ${record.respondedBy}'
                                  : 'Resolved',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.statusGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: record.level.soft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Active',
                      style: TextStyle(
                        color: record.level.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EscalationTimeline extends StatelessWidget {
  final AlertRecord record;
  const _EscalationTimeline({required this.record});

  String _time(DateTime d) => fmtTimeSgt(d);

  @override
  Widget build(BuildContext context) {
    final color = record.level.color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: record.level.soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.escalator_warning_rounded, size: 15, color: color),
              const SizedBox(width: 6),
              Text('Escalation',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(record.escalation.length, (i) {
            final step = record.escalation[i];
            final isLast = i == record.escalation.length - 1;
            return _stepRow(step, isLast, color);
          }),
        ],
      ),
    );
  }

  Widget _stepRow(EscalationStep step, bool isLast, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(
              step.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 16,
              color: step.done ? color : AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 16,
                color: (step.done ? color : AppColors.textSecondary).withValues(alpha: 0.25),
              ),
          ],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.2,
                      color: step.done ? AppColors.textPrimary : AppColors.textSecondary,
                      fontWeight: step.done ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (step.done && step.at != null) ...[
                  const SizedBox(width: 6),
                  Text(_time(step.at!),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ] else if (!step.done)
                  const Text('pending',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
