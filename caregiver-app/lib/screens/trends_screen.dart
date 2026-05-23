import 'dart:async';

import 'package:flutter/material.dart';
import '../api/care_voice_api.dart';
import '../data/sample_data.dart';
import '../models/senior.dart';
import '../theme/app_theme.dart';
import '../widgets/mood_chart.dart';
import '../widgets/polling_view.dart';
import '../widgets/senior_avatar.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    return PollingView<List<Senior>>(
      // Auto-refreshes every 15s so mood/meds/status stay live.
      fetch: () => CareVoiceApi.instance.refreshSeniors(),
      builder: (context, seniors, refresh) {
        if (seniors.isEmpty) {
          return const Center(child: Text('No seniors yet'));
        }
        final selected = seniors.firstWhere(
          (s) => s.id == _selectedId,
          orElse: () => seniors.first,
        );
        return _TrendsBody(
          seniors: seniors,
          selected: selected,
          onSelect: (s) => setState(() => _selectedId = s.id),
        );
      },
    );
  }
}

class _TrendsBody extends StatelessWidget {
  final List<Senior> seniors;
  final Senior selected;
  final ValueChanged<Senior> onSelect;

  const _TrendsBody({
    required this.seniors,
    required this.selected,
    required this.onSelect,
  });

  static const _fallbackLabels = ['', '', '', '', '', '', ''];

  @override
  Widget build(BuildContext context) {
    final s = selected;
    final labels = s.chartLabels.length == s.moodHistory.length && s.chartLabels.isNotEmpty
        ? s.chartLabels
        : _fallbackLabels;
    final mood = s.moodHistory.isEmpty
        ? 0.0
        : s.moodHistory.reduce((a, b) => a + b) / s.moodHistory.length;
    final medsTaken = s.medsHistory.where((v) => v).length;
    final pct = s.medsHistory.isEmpty
        ? 0
        : (medsTaken / s.medsHistory.length * 100).round();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        const Text(
          'Trends',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Last 7 days',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: seniors.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final senior = seniors[i];
              final isSel = senior.id == s.id;
              return GestureDetector(
                onTap: () => onSelect(senior),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 100,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSel
                        ? AppColors.brand.withValues(alpha: 0.12)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSel
                          ? AppColors.brandDark
                          : Colors.black.withValues(alpha: 0.05),
                      width: isSel ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SeniorAvatar(senior: senior, size: 36),
                      const SizedBox(height: 6),
                      Text(
                        senior.name.split(' ').take(2).join(' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mood_rounded, color: AppColors.brandDark),
                    const SizedBox(width: 8),
                    const Text(
                      'Mood',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Avg ${(mood * 100).round()}%',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                MoodChart(
                  values: s.moodHistory,
                  labels: labels,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.medication_rounded,
                        color: AppColors.brandDark),
                    const SizedBox(width: 8),
                    const Text(
                      'Medication compliance',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        color: pct >= 80
                            ? AppColors.statusGreen
                            : pct >= 60
                                ? AppColors.statusAmber
                                : AppColors.statusRed,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                MedsComplianceBar(
                  values: s.medsHistory,
                  labels: labels,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _DailySummaries(
          key: ValueKey(s.id),
          seniorId: s.id,
        ),
      ],
    );
  }
}

/// Loads the real check-in history for a senior from the backend
/// (GET /api/seniors/{id}/checkins) and renders it. These rows are produced by
/// the voicecare service whenever the elderly person sends a WhatsApp message.
class _DailySummaries extends StatefulWidget {
  final String seniorId;
  const _DailySummaries({super.key, required this.seniorId});

  @override
  State<_DailySummaries> createState() => _DailySummariesState();
}

class _DailySummariesState extends State<_DailySummaries> {
  List<CheckIn>? _items;
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    // Auto-refresh check-in history every 15s so it stays live.
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await CareVoiceApi.instance.listCheckins(widget.seniorId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Keep showing any existing data on a transient failure.
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Check-in history',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.record_voice_over_rounded,
                    size: 16, color: AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: 12),
            _buildBody(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final items = _items;
    if (items == null && _loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (items == null) {
      return const Text(
        "Couldn't load check-ins",
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      );
    }
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No check-ins yet. They appear here when this person '
          'sends a WhatsApp message to CareVoice.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      );
    }
    return Column(
      children: items
          .map((c) => _summaryRow(
                _fmt(c.createdAt),
                c.summary.isNotEmpty ? c.summary : c.transcript,
                c.alertLevel,
                c.source,
              ))
          .toList(),
    );
  }

  String _fmt(DateTime d) {
    return '${relativeTime(d)} · ${fmtTimeSgt(d)}';
  }

  static (IconData, String) _sourceTag(String source) {
    switch (source) {
      case 'voice':
        return (Icons.mic_rounded, 'Voice note');
      case 'whatsapp':
        return (Icons.chat_rounded, 'WhatsApp');
      case 'reminder':
        return (Icons.medication_rounded, 'Reminder reply');
      case 'system':
        return (Icons.settings_suggest_rounded, 'System');
      case 'simulated':
        return (Icons.science_rounded, 'Test');
      default:
        return (Icons.chat_bubble_outline_rounded, source);
    }
  }

  Widget _summaryRow(String time, String text, AlertLevel level, String source) {
    final (srcIcon, srcLabel) = _sourceTag(source);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: level.soft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(level.icon, color: level.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(time,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Icon(srcIcon, size: 12, color: AppColors.brandDark),
                    const SizedBox(width: 3),
                    Text(srcLabel,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.brandDark)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(text,
                    style: const TextStyle(fontSize: 13, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
