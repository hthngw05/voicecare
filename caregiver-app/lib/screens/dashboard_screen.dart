import 'package:flutter/material.dart';
import '../api/care_voice_api.dart';
import '../data/sample_data.dart';
import '../models/senior.dart';
import '../theme/app_theme.dart';
import '../widgets/polling_view.dart';
import '../widgets/quick_view.dart';
import '../widgets/senior_avatar.dart';
import '../widgets/status_chip.dart';
import 'senior_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PollingView<List<Senior>>(
      // Auto-refreshes every 15s so new check-ins appear without manual pull.
      fetch: () => CareVoiceApi.instance.refreshSeniors(),
      builder: (context, seniors, refresh) => _DashboardBody(
        seniors: seniors,
        onAckSuccess: refresh,
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final List<Senior> seniors;
  final Future<void> Function() onAckSuccess;
  const _DashboardBody({required this.seniors, required this.onAckSuccess});

  @override
  Widget build(BuildContext context) {
    final urgentCount = seniors
        .where((s) =>
            s.status == AlertLevel.urgent || s.status == AlertLevel.emergency)
        .length;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.record_voice_over_rounded,
                        size: 28, color: AppColors.brandDark),
                    const SizedBox(width: 8),
                    const Text(
                      'CareVoice',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandDark,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      onPressed: () => _showAddSenior(context, onAckSuccess),
                      tooltip: 'Add a loved one',
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: onAckSuccess,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Good afternoon, Mei Ling',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  urgentCount > 0
                      ? '$urgentCount alert${urgentCount > 1 ? "s" : ""} need attention'
                      : 'Everyone is doing well today',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _SummaryRow(seniors: seniors),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text(
              'Your loved ones',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          sliver: SliverList.separated(
            itemCount: seniors.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _SeniorCard(
              senior: seniors[i],
              onAckSuccess: onAckSuccess,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: QuickViewSection(seniors: seniors),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final List<Senior> seniors;
  const _SummaryRow({required this.seniors});

  @override
  Widget build(BuildContext context) {
    int countOf(AlertLevel l) => seniors.where((s) => s.status == l).length;
    final ok = countOf(AlertLevel.info);
    final concern = countOf(AlertLevel.concern);
    final urgent = countOf(AlertLevel.urgent) + countOf(AlertLevel.emergency);

    return Row(
      children: [
        Expanded(child: _StatTile(count: ok, label: 'OK', level: AlertLevel.info)),
        const SizedBox(width: 10),
        Expanded(
            child: _StatTile(
                count: concern, label: 'Concern', level: AlertLevel.concern)),
        const SizedBox(width: 10),
        Expanded(
            child: _StatTile(
                count: urgent, label: 'Urgent', level: AlertLevel.urgent)),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final int count;
  final String label;
  final AlertLevel level;
  const _StatTile({required this.count, required this.label, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: level.soft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: level.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: level.color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: level.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeniorCard extends StatelessWidget {
  final Senior senior;
  final Future<void> Function() onAckSuccess;
  const _SeniorCard({required this.senior, required this.onAckSuccess});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SeniorDetailScreen(senior: senior),
          ));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SeniorAvatar(senior: senior, size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          senior.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Age ${senior.age} · Last check-in ${relativeTime(senior.lastCheckIn)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(level: senior.status, compact: true),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                senior.lastCheckInSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, height: 1.35),
              ),
              if (senior.activeAlert != null) ...[
                const SizedBox(height: 12),
                _AlertBanner(
                  alert: senior.activeAlert!,
                  seniorId: senior.id,
                  onAckSuccess: onAckSuccess,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertBanner extends StatefulWidget {
  final ActiveAlert alert;
  final String seniorId;
  final Future<void> Function() onAckSuccess;
  const _AlertBanner({
    required this.alert,
    required this.seniorId,
    required this.onAckSuccess,
  });

  @override
  State<_AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<_AlertBanner> {
  bool _busy = false;

  Future<void> _ack() async {
    setState(() => _busy = true);
    try {
      // The backend exposes alerts by their own id, but the senior payload
      // only knows about the embedded ActiveAlert. We look up the matching
      // active alert from /api/alerts so we can call its /ack endpoint.
      final active = await CareVoiceApi.instance.listAlerts(state: 'active');
      final match = active.firstWhere(
        (a) => a.seniorId == widget.seniorId,
        orElse: () => throw ApiException('No active alert found to ack'),
      );
      await CareVoiceApi.instance.ackAlert(match.id, respondedBy: 'Mei Ling');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert acknowledged')),
      );
      await widget.onAckSuccess();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alert.level.soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alert.level.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(alert.level.icon, color: alert.level.color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              alert.message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: alert.level.color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: alert.level.color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _busy ? null : _ack,
            child: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white,
                    ),
                  )
                : const Text('OK',
                    style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

Future<void> _showAddSenior(
    BuildContext context, Future<void> Function() onDone) async {
  final result = await showDialog<_NewSenior>(
    context: context,
    builder: (_) => const _AddSeniorDialog(),
  );
  if (result == null) return;
  try {
    await CareVoiceApi.instance.addSenior(
      name: result.name,
      phone: result.phone,
      age: result.age,
      languages: result.languages,
      preferredCheckInTime: result.checkInTime,
    );
    await onDone();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.name} added')),
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _NewSenior {
  final String name;
  final String? phone;
  final int? age;
  final List<String> languages;
  final String checkInTime;
  _NewSenior(this.name, this.phone, this.age, this.languages, this.checkInTime);
}

class _AddSeniorDialog extends StatefulWidget {
  const _AddSeniorDialog();

  @override
  State<_AddSeniorDialog> createState() => _AddSeniorDialogState();
}

class _AddSeniorDialogState extends State<_AddSeniorDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _age = TextEditingController();
  final _languages = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _age.dispose();
    _languages.dispose();
    super.dispose();
  }

  String get _timeLabel =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a loved one'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp number',
                hintText: 'e.g. 6591234567 (with country code)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _age,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age (optional)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _languages,
              decoration: const InputDecoration(
                labelText: 'Languages (optional)',
                hintText: 'e.g. Hokkien, Mandarin',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.wb_sunny_rounded, size: 18, color: AppColors.brandDark),
                const SizedBox(width: 8),
                const Text('Daily check-in', style: TextStyle(fontSize: 14)),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final picked = await showTimePicker(context: context, initialTime: _time);
                    if (picked != null) setState(() => _time = picked);
                  },
                  child: Text(_timeLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: AppColors.brandDark)),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.brandDark),
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a name')),
              );
              return;
            }
            final langs = _languages.text
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            Navigator.pop(
              context,
              _NewSenior(
                name,
                _phone.text.trim().isEmpty ? null : _phone.text.trim(),
                int.tryParse(_age.text.trim()),
                langs,
                _timeLabel,
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
