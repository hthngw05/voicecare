import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';
import '../api/care_voice_api.dart';
import '../data/sample_data.dart';
import '../models/senior.dart';
import '../theme/app_theme.dart';
import '../widgets/senior_avatar.dart';
import '../widgets/status_chip.dart';

class SeniorDetailScreen extends StatelessWidget {
  final Senior senior;
  const SeniorDetailScreen({super.key, required this.senior});

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${senior.name}?'),
        content: const Text(
            'This deletes the person and all their medications, reminders, '
            'check-ins and alerts.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.statusRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CareVoiceApi.instance.deleteSenior(senior.id);
      if (context.mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'delete') _confirmDelete(context);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: AppColors.statusRed, size: 20),
                    SizedBox(width: 8),
                    Text('Remove'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Center(
            child: Column(
              children: [
                SeniorAvatar(senior: senior, size: 84),
                const SizedBox(height: 12),
                Text(
                  senior.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Age ${senior.age} · ${senior.languages.join(" · ")}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                StatusChip(level: senior.status),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Today',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.phone_in_talk_rounded,
                  label: 'Last check-in',
                  value:
                      '${fmtTimeSgt(senior.lastCheckIn)} (${relativeTime(senior.lastCheckIn)})',
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.mood_rounded,
                  label: 'Mood',
                  value: '${(senior.sentimentScore * 100).round()}%',
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    senior.lastCheckInSummary,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _WellnessCard(
            seniorId: senior.id,
            preferredTime: senior.preferredCheckInTime,
            enabled: senior.wellnessEnabled,
          ),
          const SizedBox(height: 16),
          _MedicationsCard(seniorId: senior.id, medications: senior.medications),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Emergency contacts',
            child: Column(
              children: senior.contacts.map((c) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.person_rounded,
                            color: AppColors.brandDark, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${c.relation} · ${c.phone}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.call_rounded,
                            color: AppColors.statusGreen),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Calling ${c.name}...')),
                          );
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.home_rounded,
                  label: 'Address',
                  value: senior.address,
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.schedule_rounded,
                  label: 'Preferred check-in',
                  value: '${senior.preferredCheckInTime} daily',
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.translate_rounded,
                  label: 'Languages',
                  value: senior.languages.join(', '),
                ),
                if (senior.rcVolunteer != null) ...[
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.volunteer_activism_rounded,
                    label: 'RC volunteer',
                    value: senior.rcVolunteer!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

}

class _WellnessCard extends StatefulWidget {
  final String seniorId;
  final String preferredTime;
  final bool enabled;
  const _WellnessCard({
    required this.seniorId,
    required this.preferredTime,
    required this.enabled,
  });

  @override
  State<_WellnessCard> createState() => _WellnessCardState();
}

class _WellnessCardState extends State<_WellnessCard> {
  late String _time = widget.preferredTime;
  late bool _enabled = widget.enabled;
  bool _busy = false;

  Future<void> _apply({String? time, bool? enabled}) async {
    setState(() => _busy = true);
    try {
      await CareVoiceApi.instance
          .updateSenior(widget.seniorId, preferredCheckInTime: time, wellnessEnabled: enabled);
      if (!mounted) return;
      setState(() {
        if (time != null) _time = time;
        if (enabled != null) _enabled = enabled;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _MedicationsCardState._parse(_time),
      helpText: 'Daily wellness check-in time',
    );
    if (picked != null) {
      await _apply(time: _MedicationsCardState._fmt(picked), enabled: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Daily wellness check-in',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A friendly "How are you feeling today?" message is sent on WhatsApp '
            'each day at this time.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.wb_sunny_rounded, size: 18, color: AppColors.brandDark),
              const SizedBox(width: 8),
              const Text('Check-in time',
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
              const Spacer(),
              if (_busy)
                const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else ...[
                GestureDetector(
                  onTap: _pickTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _enabled
                          ? AppColors.brand.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.brandDark.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 14, color: AppColors.brandDark),
                        const SizedBox(width: 4),
                        Text(_time,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.brandDark)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Switch(
                  value: _enabled,
                  activeThumbColor: AppColors.brandDark,
                  onChanged: (v) => _apply(enabled: v),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MedicationsCard extends StatefulWidget {
  final String seniorId;
  final List<Medication> medications;
  const _MedicationsCard({required this.seniorId, required this.medications});

  @override
  State<_MedicationsCard> createState() => _MedicationsCardState();
}

class _MedicationsCardState extends State<_MedicationsCard> {
  late List<Medication> _meds = List.of(widget.medications);
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh alarm statuses (Scheduled -> Awaiting -> Taken) every 15s.
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _silentRefresh() async {
    if (_busy) return; // don't clobber an in-flight edit
    try {
      final senior = await CareVoiceApi.instance.getSenior(widget.seniorId);
      if (!mounted) return;
      setState(() => _meds = senior.medications);
    } catch (_) {
      // keep current data on a transient failure
    }
  }

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay _parse(String? hhmm) {
    if (hhmm != null && hhmm.contains(':')) {
      final p = hhmm.split(':');
      return TimeOfDay(hour: int.tryParse(p[0]) ?? 9, minute: int.tryParse(p[1]) ?? 0);
    }
    return const TimeOfDay(hour: 9, minute: 0);
  }

  /// Run an API mutation then refetch the senior's medications.
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      final senior = await CareVoiceApi.instance.getSenior(widget.seniorId);
      if (!mounted) return;
      setState(() => _meds = senior.medications);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addAlarm(Medication m) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Add a reminder time for ${m.name}',
    );
    if (picked != null) {
      await _run(() => CareVoiceApi.instance.addAlarm(m.id, _fmt(picked)));
    }
  }

  Future<void> _editAlarm(Alarm a) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _parse(a.time),
      helpText: 'Change reminder time',
    );
    if (picked != null) {
      await _run(() => CareVoiceApi.instance.updateAlarm(a.id, time: _fmt(picked)));
    }
  }

  Future<void> _addMedicine() async {
    final result = await showDialog<_NewMed>(
      context: context,
      builder: (_) => const _AddMedicineDialog(),
    );
    if (result != null) {
      await _run(() => CareVoiceApi.instance.addMedication(
            widget.seniorId,
            result.name,
            result.dose,
            result.times,
            photoBase64: result.photoBase64,
            photoMime: result.photoMime,
          ));
    }
  }

  Future<void> _confirmDeleteMed(Medication m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${m.name}?'),
        content: const Text('This deletes the medicine and all its reminders.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.statusRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _run(() => CareVoiceApi.instance.deleteMedication(m.id));
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
                const Text('Medications',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (_busy)
                  const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  TextButton.icon(
                    onPressed: _addMedicine,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.brandDark),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (_meds.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No medicines yet. Tap "Add" to create one.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              )
            else
              ..._meds.map(_medTile),
          ],
        ),
      ),
    );
  }

  Widget _medTile(Medication m) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (m.hasPhoto)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    CareVoiceApi.instance.medicationPhotoUrl(m.id),
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                        Icons.medication_rounded, color: AppColors.brandDark, size: 20),
                  ),
                )
              else
                const Icon(Icons.medication_rounded, color: AppColors.brandDark, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${m.name}  ·  ${m.dose}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 20, color: AppColors.textSecondary),
                onPressed: _busy ? null : () => _confirmDeleteMed(m),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...m.alarms.map(_alarmRow),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _busy ? null : () => _addAlarm(m),
              icon: const Icon(Icons.add_alarm_rounded, size: 18),
              label: const Text('Add reminder time'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brandDark,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _alarmRow(Alarm a) {
    final (label, color, bg) = switch (a.status) {
      'done' => ('Taken', AppColors.statusGreen, AppColors.statusGreenSoft),
      'awaiting' => ('Awaiting reply', AppColors.statusAmber, AppColors.statusAmberSoft),
      _ => ('Scheduled', AppColors.textSecondary, Colors.black.withValues(alpha: 0.04)),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: _busy ? null : () => _editAlarm(a),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: a.enabled ? 0.12 : 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.brandDark.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_rounded, size: 14, color: AppColors.brandDark),
                  const SizedBox(width: 4),
                  Text(a.time,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.brandDark)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (a.enabled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
              child: Text(label,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            )
          else
            const Text('Off',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const Spacer(),
          Switch(
            value: a.enabled,
            activeThumbColor: AppColors.brandDark,
            onChanged: _busy
                ? null
                : (v) => _run(() => CareVoiceApi.instance.updateAlarm(a.id, enabled: v)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
            onPressed: _busy ? null : () => _run(() => CareVoiceApi.instance.deleteAlarm(a.id)),
          ),
        ],
      ),
    );
  }
}

class _NewMed {
  final String name;
  final String dose;
  final List<String> times;
  final String? photoBase64;
  final String? photoMime;
  _NewMed(this.name, this.dose, this.times, {this.photoBase64, this.photoMime});
}

class _AddMedicineDialog extends StatefulWidget {
  const _AddMedicineDialog();

  @override
  State<_AddMedicineDialog> createState() => _AddMedicineDialogState();
}

class _AddMedicineDialogState extends State<_AddMedicineDialog> {
  final _name = TextEditingController();
  final _tablets = TextEditingController(text: '1');
  final List<String> _times = [];
  final _picker = ImagePicker();
  Uint8List? _photoBytes;
  String? _photoMime;
  bool _picking = false;
  bool _ocrBusy = false;

  @override
  void dispose() {
    _name.dispose();
    _tablets.dispose();
    super.dispose();
  }

  static String _formatDose(String raw) {
    final n = raw.trim().isEmpty ? '1' : raw.trim();
    return n == '1' ? '1 tablet' : '$n tablets';
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_picking) return; // ignore double-taps while a pick is in progress
    _picking = true;
    try {
      XFile? x;
      try {
        x = await _picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );
      } on PlatformException catch (e) {
        if (e.code == 'already_active') {
          // The Android activity was recreated mid-pick; recover the result.
          final lost = await _picker.retrieveLostData();
          if (!lost.isEmpty && lost.file != null) {
            x = lost.file;
          } else {
            return; // nothing to recover; let the user try again
          }
        } else {
          rethrow;
        }
      }
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final mime = x.mimeType ??
          (x.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _photoMime = mime;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load photo: $e')),
        );
      }
    } finally {
      _picking = false;
    }
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Add a reminder time',
    );
    if (picked != null) {
      final t = _MedicationsCardState._fmt(picked);
      if (!_times.contains(t)) setState(() => _times.add(t));
    }
  }

  static String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');

  Future<void> _autofillFromPhoto() async {
    if (_photoBytes == null || _ocrBusy) return;
    setState(() => _ocrBusy = true);
    try {
      final r = await CareVoiceApi.instance.ocrMedication(
        base64Encode(_photoBytes!),
        photoMime: _photoMime ?? 'image/jpeg',
      );
      if (!mounted) return;
      setState(() {
        if (r.name.isNotEmpty) _name.text = _titleCase(r.name);
        final n = RegExp(r'\d+').firstMatch(r.dose)?.group(0);
        if (n != null) _tablets.text = n;
        if (r.times.isNotEmpty) {
          _times
            ..clear()
            ..addAll(r.times);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Filled from photo — please review before saving.')),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not read photo: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _ocrBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add medicine'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name (e.g. Metformin)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tablets,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number of tablets',
                hintText: 'e.g. 1',
                suffixText: 'tablet(s)',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Photo (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_photoBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(_photoBytes!, width: 56, height: 56, fit: BoxFit.cover),
                  )
                else
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
                  ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Camera',
                  icon: const Icon(Icons.photo_camera_rounded, color: AppColors.brandDark),
                  onPressed: () => _pickPhoto(ImageSource.camera),
                ),
                IconButton(
                  tooltip: 'Gallery',
                  icon: const Icon(Icons.photo_library_rounded, color: AppColors.brandDark),
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                ),
                if (_photoBytes != null)
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    onPressed: () => setState(() {
                      _photoBytes = null;
                      _photoMime = null;
                    }),
                  ),
              ],
            ),
            if (_photoBytes != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _ocrBusy ? null : _autofillFromPhoto,
                  icon: _ocrBusy
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text(_ocrBusy ? 'Reading photo…' : 'Autofill from photo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brandDark,
                    side: BorderSide(color: AppColors.brandDark.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text('Reminder times', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._times.map((t) => Chip(
                      label: Text(t),
                      onDeleted: () => setState(() => _times.remove(t)),
                    )),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add time'),
                  onPressed: _addTime,
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
                const SnackBar(content: Text('Please enter a medicine name')),
              );
              return;
            }
            Navigator.pop(
              context,
              _NewMed(
                name,
                _formatDose(_tablets.text),
                List.of(_times),
                photoBase64: _photoBytes != null ? base64Encode(_photoBytes!) : null,
                photoMime: _photoMime,
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.brandDark),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
