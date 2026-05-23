import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/senior.dart';
import '../theme/app_theme.dart';
import 'api_config.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => 'ApiException: $message';
}

class CareVoiceApi {
  CareVoiceApi({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  static final CareVoiceApi instance = CareVoiceApi();

  final http.Client _client;
  final String _baseUrl;

  static const _timeout = Duration(seconds: 10);

  /// Cached `listSeniors` future so tab-switching doesn't re-fetch. Cleared
  /// by [refreshSeniors] and by [ackAlert] after a successful ack.
  Future<List<Senior>>? _seniorsCache;
  final Map<String, Future<List<AlertRecord>>> _alertsCache = {};

  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: q);

  void _invalidateCaches() {
    _seniorsCache = null;
    _alertsCache.clear();
  }

  /// Force a re-fetch of the seniors list on next call.
  Future<List<Senior>> refreshSeniors() {
    _invalidateCaches();
    return listSeniors();
  }

  Future<dynamic> _getJson(String path, [Map<String, String>? q]) async {
    final res = await _client.get(_u(path, q)).timeout(_timeout);
    if (res.statusCode >= 400) {
      throw ApiException('GET $path → ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body);
  }

  Future<dynamic> _postJson(String path, [Map<String, String>? q]) async {
    final res = await _client.post(_u(path, q)).timeout(_timeout);
    if (res.statusCode >= 400) {
      throw ApiException('POST $path → ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body);
  }

  // --- Endpoints --------------------------------------------------------

  Future<List<Senior>> listSeniors() {
    return _seniorsCache ??= _fetchSeniors();
  }

  Future<void> addSenior({
    required String name,
    String? phone,
    int? age,
    List<String> languages = const [],
    String preferredCheckInTime = '09:00',
  }) {
    final body = <String, dynamic>{
      'name': name,
      'preferred_check_in_time': preferredCheckInTime,
      'languages': languages,
    };
    if (phone != null && phone.isNotEmpty) body['phone'] = phone;
    if (age != null) body['age'] = age;
    return _send('POST', '/api/seniors', body);
  }

  Future<void> deleteSenior(String seniorId) => _send('DELETE', '/api/seniors/$seniorId');

  Future<List<Senior>> _fetchSeniors() async {
    final data = await _getJson('/api/seniors') as List<dynamic>;
    return data
        .cast<Map<String, dynamic>>()
        .map(_seniorFromJson)
        .toList(growable: false);
  }

  Future<Senior> getSenior(String id) async {
    final data = await _getJson('/api/seniors/$id') as Map<String, dynamic>;
    return _seniorFromJson(data);
  }

  Future<List<CheckIn>> listCheckins(String seniorId, {int limit = 20}) async {
    final data = await _getJson('/api/seniors/$seniorId/checkins', {
      'limit': '$limit',
    }) as List<dynamic>;
    return data
        .cast<Map<String, dynamic>>()
        .map(_checkInFromJson)
        .toList(growable: false);
  }

  Future<List<AlertRecord>> listAlerts({String state = 'all'}) {
    return _alertsCache[state] ??= _fetchAlerts(state);
  }

  Future<List<AlertRecord>> _fetchAlerts(String state) async {
    final data =
        await _getJson('/api/alerts', {'state': state}) as List<dynamic>;
    return data
        .cast<Map<String, dynamic>>()
        .map(_alertFromJson)
        .toList(growable: false);
  }

  Future<List<AlertRecord>> refreshAlerts({String state = 'all'}) {
    _alertsCache.remove(state);
    return listAlerts(state: state);
  }

  Future<AlertRecord> ackAlert(String id, {String respondedBy = 'You'}) async {
    final data = await _postJson('/api/alerts/$id/ack', {
      'responded_by': respondedBy,
    }) as Map<String, dynamic>;
    _invalidateCaches();
    return _alertFromJson(data);
  }

  Future<void> _send(String method, String path, [Map<String, dynamic>? body]) async {
    final req = http.Request(method, _u(path));
    req.headers['Content-Type'] = 'application/json';
    if (body != null) req.body = jsonEncode(body);
    final streamed = await _client.send(req).timeout(_timeout);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode >= 400) {
      throw ApiException('$method $path → ${res.statusCode}: ${res.body}');
    }
    _invalidateCaches();
  }

  Future<void> addMedication(
    String seniorId,
    String name,
    String dose,
    List<String> times, {
    String? photoBase64,
    String? photoMime,
  }) {
    final body = <String, dynamic>{'name': name, 'dose': dose, 'times': times};
    if (photoBase64 != null) {
      body['photo'] = photoBase64;
      body['photo_mime'] = photoMime ?? 'image/jpeg';
    }
    return _send('POST', '/api/seniors/$seniorId/medications', body);
  }

  /// Full URL to a medication's photo (for Image.network).
  String medicationPhotoUrl(int medId) => '$_baseUrl/api/medications/$medId/photo';

  /// Read a medication photo with AI → suggested {name, dose, times}.
  Future<({String name, String dose, List<String> times})> ocrMedication(
    String photoBase64, {
    String photoMime = 'image/jpeg',
  }) async {
    final data = await _postRawJson('/api/medications/ocr', {
      'photo': photoBase64,
      'photo_mime': photoMime,
    }) as Map<String, dynamic>;
    return (
      name: (data['name'] as String?) ?? '',
      dose: (data['dose'] as String?) ?? '',
      times: ((data['times'] as List<dynamic>?) ?? const []).cast<String>(),
    );
  }

  Future<dynamic> _postRawJson(String path, Map<String, dynamic> body) async {
    final res = await _client
        .post(_u(path),
            headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
        .timeout(const Duration(seconds: 60));
    if (res.statusCode >= 400) {
      // Surface the server's friendly detail (e.g. rate-limit message) if present.
      String msg = res.body;
      try {
        final j = jsonDecode(res.body);
        if (j is Map && j['detail'] != null) msg = j['detail'].toString();
      } catch (_) {}
      throw ApiException(msg);
    }
    return jsonDecode(res.body);
  }

  Future<void> deleteMedication(int medId) => _send('DELETE', '/api/medications/$medId');

  Future<void> addAlarm(int medId, String time) =>
      _send('POST', '/api/medications/$medId/alarms', {'time': time});

  Future<void> updateAlarm(int alarmId, {String? time, bool? enabled}) {
    final body = <String, dynamic>{};
    if (time != null) body['time'] = time;
    if (enabled != null) body['enabled'] = enabled;
    return _send('PATCH', '/api/alarms/$alarmId', body);
  }

  Future<void> deleteAlarm(int alarmId) => _send('DELETE', '/api/alarms/$alarmId');

  Future<void> updateSenior(
    String seniorId, {
    String? preferredCheckInTime,
    bool? wellnessEnabled,
  }) {
    final body = <String, dynamic>{};
    if (preferredCheckInTime != null) body['preferred_check_in_time'] = preferredCheckInTime;
    if (wellnessEnabled != null) body['wellness_enabled'] = wellnessEnabled;
    return _send('PATCH', '/api/seniors/$seniorId', body);
  }

  Future<List<CommunityEvent>> listEvents() async {
    final data = await _getJson('/api/events') as List<dynamic>;
    return data
        .cast<Map<String, dynamic>>()
        .map((e) => CommunityEvent(
              id: e['id'] as String,
              title: e['title'] as String,
              date: e['date'] as String,
              time: e['time'] as String,
              location: e['location'] as String,
              category: e['category'] as String,
              description: e['description'] as String,
              url: (e['url'] as String?) ?? '',
            ))
        .toList(growable: false);
  }

  // --- Parsing ----------------------------------------------------------

  static AlertLevel _parseLevel(String s) =>
      AlertLevel.values.firstWhere((e) => e.name == s, orElse: () => AlertLevel.info);

  static DateTime _parseDate(dynamic v) =>
      v == null ? DateTime.now() : DateTime.parse(v as String).toLocal();

  static Senior _seniorFromJson(Map<String, dynamic> j) {
    final meds = (j['medications'] as List<dynamic>?) ?? const [];
    final contacts = (j['contacts'] as List<dynamic>?) ?? const [];
    final activeAlertJson = j['activeAlert'] as Map<String, dynamic>?;

    return Senior(
      id: j['id'] as String,
      name: j['name'] as String,
      age: j['age'] as int,
      address: (j['address'] as String?) ?? '',
      avatarInitials: j['avatarInitials'] as String,
      languages:
          ((j['languages'] as List<dynamic>?) ?? const []).cast<String>(),
      preferredCheckInTime: (j['preferredCheckInTime'] as String?) ?? '',
      wellnessEnabled: (j['wellnessEnabled'] as bool?) ?? true,
      rcVolunteer: j['rcVolunteer'] as String?,
      phone: j['phone'] as String?,
      status: _parseLevel(j['status'] as String),
      sentimentScore: (j['sentimentScore'] as num).toDouble(),
      lastCheckInSummary: j['lastCheckInSummary'] as String,
      lastCheckIn: _parseDate(j['lastCheckIn']),
      medications: meds
          .cast<Map<String, dynamic>>()
          .map(_medicationFromJson)
          .toList(),
      contacts: contacts
          .cast<Map<String, dynamic>>()
          .map((c) => EmergencyContact(
                name: c['name'] as String,
                relation: c['relation'] as String,
                phone: c['phone'] as String,
              ))
          .toList(),
      moodHistory: ((j['moodHistory'] as List<dynamic>?) ?? const [])
          .map((v) => (v as num).toDouble())
          .toList(),
      medsHistory:
          ((j['medsHistory'] as List<dynamic>?) ?? const []).cast<bool>(),
      chartLabels:
          ((j['chartLabels'] as List<dynamic>?) ?? const []).cast<String>(),
      activeAlert: activeAlertJson == null
          ? null
          : ActiveAlert(
              message: activeAlertJson['message'] as String,
              level: _parseLevel(activeAlertJson['level'] as String),
              triggeredAt: _parseDate(activeAlertJson['triggeredAt']),
            ),
    );
  }

  static Medication _medicationFromJson(Map<String, dynamic> m) {
    final alarms = (m['alarms'] as List<dynamic>?) ?? const [];
    return Medication(
      id: m['id'] as int,
      name: m['name'] as String,
      dose: m['dose'] as String,
      takenToday: m['takenToday'] as bool,
      hasPhoto: (m['hasPhoto'] as bool?) ?? false,
      alarms: alarms
          .cast<Map<String, dynamic>>()
          .map((a) => Alarm(
                id: a['id'] as int,
                time: a['time'] as String,
                enabled: a['enabled'] as bool,
                status: a['status'] as String,
              ))
          .toList(),
    );
  }

  static AlertRecord _alertFromJson(Map<String, dynamic> j) {
    return AlertRecord(
      id: j['id'] as String,
      seniorId: j['seniorId'] as String,
      seniorName: j['seniorName'] as String,
      level: _parseLevel(j['level'] as String),
      trigger: j['trigger'] as String,
      action: j['action'] as String,
      respondedBy: j['respondedBy'] as String?,
      triggeredAt: _parseDate(j['triggeredAt']),
      resolvedAt:
          j['resolvedAt'] == null ? null : _parseDate(j['resolvedAt']),
      escalation: ((j['escalation'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map((e) => EscalationStep(
                label: e['label'] as String,
                done: e['done'] as bool,
                at: e['at'] == null ? null : _parseDate(e['at']),
              ))
          .toList(),
    );
  }

  static CheckIn _checkInFromJson(Map<String, dynamic> j) {
    return CheckIn(
      id: j['id'] as int,
      seniorId: j['seniorId'] as String,
      transcript: j['transcript'] as String,
      summary: j['summary'] as String,
      sentimentScore: (j['sentimentScore'] as num).toDouble(),
      alertLevel: _parseLevel(j['alertLevel'] as String),
      riskFlags: ((j['riskFlags'] as List<dynamic>?) ?? const []).cast<String>(),
      language: j['language'] as String?,
      source: j['source'] as String,
      createdAt: _parseDate(j['createdAt']),
    );
  }
}
