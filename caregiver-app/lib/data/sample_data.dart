// Time helpers shared by the screens. The hardcoded `Senior` / `AlertRecord`
// lists that used to live here have moved to the backend — see
// `backend/app/seed.py` and `lib/api/care_voice_api.dart`.

String relativeTime(DateTime from) {
  // Relative time is timezone-agnostic (compares absolute instants), so it's
  // correct regardless of the device's timezone.
  final diff = DateTime.now().difference(from);
  if (diff.inSeconds < 0) return 'just now'; // tiny clock skew
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

// CareVoice is Singapore-based, so absolute times are always shown in SGT
// (UTC+8) no matter what timezone the phone/emulator is set to.
const Duration _sgtOffset = Duration(hours: 8);
const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

DateTime _toSgt(DateTime d) => d.toUtc().add(_sgtOffset);

/// "14:05" in Singapore time.
String fmtTimeSgt(DateTime d) {
  final s = _toSgt(d);
  final hh = s.hour.toString().padLeft(2, '0');
  final mm = s.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

/// "22 May 14:05" in Singapore time.
String fmtDateTimeSgt(DateTime d) {
  final s = _toSgt(d);
  return '${s.day} ${_months[s.month - 1]} ${fmtTimeSgt(d)}';
}
