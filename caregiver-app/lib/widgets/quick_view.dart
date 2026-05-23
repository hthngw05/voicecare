import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/care_voice_api.dart';
import '../data/sample_data.dart';
import '../models/senior.dart';
import '../theme/app_theme.dart';

enum QuickViewType {
  moodTrend,
  medCompliance,
  nextReminder,
  recentCheckin,
  upcomingEvent,
  activeAlerts,
}

extension QuickViewMeta on QuickViewType {
  String get title => switch (this) {
        QuickViewType.moodTrend => 'Mood this week',
        QuickViewType.medCompliance => 'Medication compliance',
        QuickViewType.nextReminder => 'Next reminder',
        QuickViewType.recentCheckin => 'Latest check-in',
        QuickViewType.upcomingEvent => 'Upcoming event',
        QuickViewType.activeAlerts => 'Active alerts',
      };

  String get blurb => switch (this) {
        QuickViewType.moodTrend => 'Average mood over the last 7 days',
        QuickViewType.medCompliance => 'How often medication was taken',
        QuickViewType.nextReminder => 'The next medication reminder due',
        QuickViewType.recentCheckin => 'The most recent check-in message',
        QuickViewType.upcomingEvent => 'The next Tampines community event',
        QuickViewType.activeAlerts => 'How many alerts need attention',
      };

  IconData get icon => switch (this) {
        QuickViewType.moodTrend => Icons.mood_rounded,
        QuickViewType.medCompliance => Icons.medication_rounded,
        QuickViewType.nextReminder => Icons.alarm_rounded,
        QuickViewType.recentCheckin => Icons.record_voice_over_rounded,
        QuickViewType.upcomingEvent => Icons.event_rounded,
        QuickViewType.activeAlerts => Icons.notifications_active_rounded,
      };
}

const _prefsKey = 'quick_view_selection_v1';
const _maxSelected = 2;
const _defaultSelection = [QuickViewType.moodTrend, QuickViewType.nextReminder];

Future<List<QuickViewType>> loadQuickView() async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getStringList(_prefsKey);
  if (raw == null) return List.of(_defaultSelection);
  final out = <QuickViewType>[];
  for (final s in raw) {
    final match = QuickViewType.values.where((e) => e.name == s);
    if (match.isNotEmpty) out.add(match.first);
  }
  return out.isEmpty ? List.of(_defaultSelection) : out.take(_maxSelected).toList();
}

Future<void> saveQuickView(List<QuickViewType> sel) async {
  final p = await SharedPreferences.getInstance();
  await p.setStringList(_prefsKey, sel.map((e) => e.name).toList());
}

class QuickViewSection extends StatefulWidget {
  final List<Senior> seniors;
  const QuickViewSection({super.key, required this.seniors});

  @override
  State<QuickViewSection> createState() => _QuickViewSectionState();
}

class _QuickViewSectionState extends State<QuickViewSection> {
  List<QuickViewType>? _selected;

  @override
  void initState() {
    super.initState();
    loadQuickView().then((v) {
      if (mounted) setState(() => _selected = v);
    });
  }

  Future<void> _customize() async {
    final current = List<QuickViewType>.of(_selected ?? _defaultSelection);
    final result = await showModalBottomSheet<List<QuickViewType>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CustomizeSheet(initial: current),
    );
    if (result != null) {
      await saveQuickView(result);
      if (mounted) setState(() => _selected = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Quick view',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton.icon(
              onPressed: selected == null ? null : _customize,
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Customize'),
              style: TextButton.styleFrom(foregroundColor: AppColors.brandDark),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (selected == null)
          const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (selected.isEmpty)
          _emptyHint()
        else
          ...selected.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _QuickCard(type: t, seniors: widget.seniors),
              )),
      ],
    );
  }

  Widget _emptyHint() {
    return GestureDetector(
      onTap: _customize,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: const Text(
          'Tap "Customize" to pick up to 2 quick-view widgets.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final QuickViewType type;
  final List<Senior> seniors;
  const _QuickCard({required this.type, required this.seniors});

  @override
  Widget build(BuildContext context) {
    if (type == QuickViewType.upcomingEvent) {
      return _EventQuickCard();
    }
    final (value, sub, color) = _compute();
    return _shell(value: value, sub: sub, color: color);
  }

  Widget _shell({required String value, required String sub, required Color color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(type.icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type.title,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800, color: color)),
                if (sub.isNotEmpty)
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (String, String, Color) _compute() {
    switch (type) {
      case QuickViewType.moodTrend:
        final vals = [for (final s in seniors) ...s.moodHistory];
        if (vals.isEmpty) return ('—', 'No data yet', AppColors.brandDark);
        final avg = vals.reduce((a, b) => a + b) / vals.length;
        final pct = (avg * 100).round();
        final color = avg >= 0.6
            ? AppColors.statusGreen
            : avg >= 0.4
                ? AppColors.statusAmber
                : AppColors.statusRed;
        return ('$pct%', 'Average mood (7 days)', color);
      case QuickViewType.medCompliance:
        final vals = [for (final s in seniors) ...s.medsHistory];
        if (vals.isEmpty) return ('—', 'No data yet', AppColors.brandDark);
        final pct = (vals.where((v) => v).length / vals.length * 100).round();
        final color = pct >= 80
            ? AppColors.statusGreen
            : pct >= 60
                ? AppColors.statusAmber
                : AppColors.statusRed;
        return ('$pct%', 'Medication taken (7 days)', color);
      case QuickViewType.nextReminder:
        return _nextReminder();
      case QuickViewType.recentCheckin:
        if (seniors.isEmpty) return ('—', 'No check-ins', AppColors.brandDark);
        final latest = seniors.reduce(
            (a, b) => a.lastCheckIn.isAfter(b.lastCheckIn) ? a : b);
        return (
          relativeTime(latest.lastCheckIn),
          '${latest.name.split(' ').take(2).join(' ')} · ${latest.lastCheckInSummary}',
          AppColors.brandDark,
        );
      case QuickViewType.activeAlerts:
        final n = seniors.where((s) => s.activeAlert != null).length;
        return (
          '$n',
          n == 0 ? 'All clear' : 'Need attention',
          n == 0 ? AppColors.statusGreen : AppColors.statusRed,
        );
      case QuickViewType.upcomingEvent:
        return ('', '', AppColors.brandDark); // handled by _EventQuickCard
    }
  }

  (String, String, Color) _nextReminder() {
    final nowSgt = DateTime.now().toUtc().add(const Duration(hours: 8));
    final nowMin = nowSgt.hour * 60 + nowSgt.minute;
    int? bestMin;
    String bestLabel = '';
    for (final s in seniors) {
      for (final m in s.medications) {
        for (final a in m.alarms) {
          if (!a.enabled) continue;
          final parts = a.time.split(':');
          if (parts.length != 2) continue;
          final mins = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
          if (mins >= nowMin && (bestMin == null || mins < bestMin)) {
            bestMin = mins;
            bestLabel = '${a.time} · ${m.name} (${s.name.split(' ').take(2).join(' ')})';
          }
        }
      }
    }
    if (bestMin == null) {
      return ('All done', 'No more reminders today', AppColors.statusGreen);
    }
    final hh = (bestMin ~/ 60).toString().padLeft(2, '0');
    final mm = (bestMin % 60).toString().padLeft(2, '0');
    return ('$hh:$mm', bestLabel.replaceFirst('${bestLabel.split(' · ').first} · ', ''), AppColors.brandDark);
  }
}

class _EventQuickCard extends StatefulWidget {
  @override
  State<_EventQuickCard> createState() => _EventQuickCardState();
}

class _EventQuickCardState extends State<_EventQuickCard> {
  late Future<List<CommunityEvent>> _future;

  @override
  void initState() {
    super.initState();
    _future = CareVoiceApi.instance.listEvents();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CommunityEvent>>(
      future: _future,
      builder: (context, snap) {
        final ev = (snap.data ?? const []).isNotEmpty ? snap.data!.first : null;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.statusAmber.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.event_rounded, color: AppColors.statusAmber, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Upcoming event',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(ev?.title ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    if (ev != null)
                      Text('${ev.date} · ${ev.time}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CustomizeSheet extends StatefulWidget {
  final List<QuickViewType> initial;
  const _CustomizeSheet({required this.initial});

  @override
  State<_CustomizeSheet> createState() => _CustomizeSheetState();
}

class _CustomizeSheetState extends State<_CustomizeSheet> {
  late final List<QuickViewType> _sel = List.of(widget.initial);

  void _toggle(QuickViewType t) {
    setState(() {
      if (_sel.contains(t)) {
        _sel.remove(t);
      } else if (_sel.length < _maxSelected) {
        _sel.add(t);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Quick view widgets',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('${_sel.length}/$_maxSelected',
                      style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 4),
              const Text('Choose up to two to show on your home screen.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: QuickViewType.values.map((t) {
                      final on = _sel.contains(t);
                      final disabled = !on && _sel.length >= _maxSelected;
                      return Opacity(
                        opacity: disabled ? 0.4 : 1,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Icon(t.icon, color: AppColors.brandDark, size: 20),
                          ),
                          title: Text(t.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                          subtitle: Text(t.blurb,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary)),
                          trailing: Checkbox(
                            value: on,
                            activeColor: AppColors.brandDark,
                            onChanged: disabled ? null : (_) => _toggle(t),
                          ),
                          onTap: disabled ? null : () => _toggle(t),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.brandDark),
                  onPressed: () => Navigator.pop(context, _sel),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
