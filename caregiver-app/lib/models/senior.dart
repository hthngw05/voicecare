import '../theme/app_theme.dart';

class Senior {
  final String id;
  final String name;
  final int age;
  final String address;
  final List<String> languages;
  final String preferredCheckInTime;
  final bool wellnessEnabled;
  final List<Medication> medications;
  final List<EmergencyContact> contacts;
  final String? rcVolunteer;
  final String? phone;
  final String avatarInitials;

  final AlertLevel status;
  final double sentimentScore;
  final String lastCheckInSummary;
  final DateTime lastCheckIn;
  final ActiveAlert? activeAlert;

  final List<double> moodHistory;
  final List<bool> medsHistory;
  final List<String> chartLabels;

  const Senior({
    required this.id,
    required this.name,
    required this.age,
    required this.address,
    required this.languages,
    required this.preferredCheckInTime,
    this.wellnessEnabled = true,
    required this.medications,
    required this.contacts,
    required this.avatarInitials,
    required this.status,
    required this.sentimentScore,
    required this.lastCheckInSummary,
    required this.lastCheckIn,
    required this.moodHistory,
    required this.medsHistory,
    this.chartLabels = const [],
    this.activeAlert,
    this.rcVolunteer,
    this.phone,
  });
}

class Alarm {
  final int id;
  final String time; // "HH:MM"
  final bool enabled;
  final String status; // "scheduled" | "awaiting" | "done"

  const Alarm({
    required this.id,
    required this.time,
    required this.enabled,
    required this.status,
  });
}

class Medication {
  final int id;
  final String name;
  final String dose;
  final bool takenToday;
  final bool hasPhoto;
  final List<Alarm> alarms;

  const Medication({
    required this.id,
    required this.name,
    required this.dose,
    required this.takenToday,
    this.hasPhoto = false,
    this.alarms = const [],
  });
}

class EmergencyContact {
  final String name;
  final String relation;
  final String phone;

  const EmergencyContact({
    required this.name,
    required this.relation,
    required this.phone,
  });
}

class ActiveAlert {
  final String message;
  final AlertLevel level;
  final DateTime triggeredAt;

  const ActiveAlert({
    required this.message,
    required this.level,
    required this.triggeredAt,
  });
}

class EscalationStep {
  final String label;
  final bool done;
  final DateTime? at;
  const EscalationStep({required this.label, required this.done, this.at});
}

class AlertRecord {
  final String id;
  final String seniorId;
  final String seniorName;
  final AlertLevel level;
  final String trigger;
  final String action;
  final String? respondedBy;
  final DateTime triggeredAt;
  final DateTime? resolvedAt;
  final List<EscalationStep> escalation;

  const AlertRecord({
    required this.id,
    required this.seniorId,
    required this.seniorName,
    required this.level,
    required this.trigger,
    required this.action,
    required this.triggeredAt,
    this.respondedBy,
    this.resolvedAt,
    this.escalation = const [],
  });

  bool get resolved => resolvedAt != null;
}

class CommunityEvent {
  final String id;
  final String title;
  final String date;
  final String time;
  final String location;
  final String category;
  final String description;
  final String url;

  const CommunityEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    required this.location,
    required this.category,
    required this.description,
    this.url = '',
  });
}

class CheckIn {
  final int id;
  final String seniorId;
  final String transcript;
  final String summary;
  final double sentimentScore;
  final AlertLevel alertLevel;
  final List<String> riskFlags;
  final String? language;
  final String source;
  final DateTime createdAt;

  const CheckIn({
    required this.id,
    required this.seniorId,
    required this.transcript,
    required this.summary,
    required this.sentimentScore,
    required this.alertLevel,
    required this.riskFlags,
    required this.source,
    required this.createdAt,
    this.language,
  });
}
