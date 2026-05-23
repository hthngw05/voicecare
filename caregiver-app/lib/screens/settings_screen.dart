import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        const Text(
          'Settings',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'ML',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandDark,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lim Mei Ling',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Family caregiver · meiling@example.com',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: const [
              _SettingsTile(
                icon: Icons.notifications_active_rounded,
                title: 'Notifications',
                subtitle: 'Push, SMS, WhatsApp',
              ),
              _Divider(),
              _SettingsTile(
                icon: Icons.language_rounded,
                title: 'Check-in language',
                subtitle: 'Auto-detect (Hokkien, Mandarin, Malay, Tamil, English)',
              ),
              _Divider(),
              _SettingsTile(
                icon: Icons.access_time_rounded,
                title: 'Quiet hours',
                subtitle: '22:00 — 07:00',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: const [
              _SettingsTile(
                icon: Icons.volunteer_activism_rounded,
                title: 'Linked RC volunteers',
                subtitle: '3 Tampines volunteers',
              ),
              _Divider(),
              _SettingsTile(
                icon: Icons.shield_rounded,
                title: 'Privacy & data',
                subtitle: 'Manage what is shared',
              ),
              _Divider(),
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                title: 'Help & support',
                subtitle: 'How CareVoice works',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'CareVoice v0.1',
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.brand.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: AppColors.brandDark, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textSecondary),
      onTap: () {},
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.black.withValues(alpha: 0.05),
      indent: 60,
    );
  }
}
