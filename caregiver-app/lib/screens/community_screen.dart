import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/care_voice_api.dart';
import '../models/senior.dart';
import '../theme/app_theme.dart';
import '../widgets/polling_view.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PollingView<List<CommunityEvent>>(
      period: const Duration(minutes: 5),
      fetch: () => CareVoiceApi.instance.listEvents(),
      builder: (context, events, refresh) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            const Text('Community',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Activities around Tampines to keep your loved one active',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 16),
            ...events.map(_eventCard),
            if (events.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text('No events right now',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _eventCard(CommunityEvent e) {
    final (icon, color) = _categoryStyle(e.category);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: e.url.isEmpty ? null : () => _open(e.url),
          child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15, height: 1.2)),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(e.category,
                              style: TextStyle(
                                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _row(Icons.event_rounded, '${e.date} · ${e.time}'),
              const SizedBox(height: 6),
              _row(Icons.place_rounded, e.location),
              const SizedBox(height: 10),
              Text(e.description,
                  style: const TextStyle(fontSize: 13, height: 1.4)),
              if (e.url.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.open_in_new_rounded, size: 13, color: AppColors.brandDark),
                    const SizedBox(width: 6),
                    Text(
                      e.url.contains('eventbrite')
                          ? 'Tap to open on Eventbrite'
                          : 'Tap to open',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.brandDark,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ],
          ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _row(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  (IconData, Color) _categoryStyle(String category) {
    switch (category.toLowerCase()) {
      case 'exercise':
        return (Icons.fitness_center_rounded, AppColors.statusGreen);
      case 'health':
        return (Icons.favorite_rounded, AppColors.statusRed);
      case 'learning':
        return (Icons.school_rounded, AppColors.brandDark);
      case 'social':
      default:
        return (Icons.groups_rounded, AppColors.statusAmber);
    }
  }
}
