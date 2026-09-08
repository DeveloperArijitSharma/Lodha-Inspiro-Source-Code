import 'package:flutter/material.dart';

import '../app_preferences.dart';
import '../main.dart';

/// Drop-in settings section for the existing Settings page.
/// Every control updates the runtime immediately and persists its value.
class AdvancedSettingsSection extends StatelessWidget {
  final bool isDark;
  final Color accentColor;

  const AdvancedSettingsSection({
    super.key,
    required this.isDark,
    this.accentColor = const Color(0xFF32C5FF),
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: smoothMotionNotifier,
        builder: (context, smoothMotion, _) {
          return Column(
            children: [
              _settingSwitch(
                context,
                icon: Icons.auto_awesome_motion_rounded,
                title: 'Smooth animations',
                subtitle: 'Use short, fluid transitions and instant feedback.',
                value: smoothMotion,
                onChanged: setSmoothMotion,
                textColor: textColor,
              ),
              const Divider(height: 22),
              ValueListenableBuilder<bool>(
                valueListenable: hapticsNotifier,
                builder: (context, haptics, _) => _settingSwitch(
                  context,
                  icon: Icons.vibration_rounded,
                  title: 'Touch feedback',
                  subtitle: 'Use gentle haptics when controls are tapped.',
                  value: haptics,
                  onChanged: setHaptics,
                  textColor: textColor,
                ),
              ),
              const Divider(height: 22),
              ValueListenableBuilder<bool>(
                valueListenable: notificationsNotifier,
                builder: (context, notifications, _) => _settingSwitch(
                  context,
                  icon: Icons.notifications_active_outlined,
                  title: 'Notifications',
                  subtitle: 'Allow Inspiro to request notification permission.',
                  value: notifications,
                  onChanged: setNotifications,
                  textColor: textColor,
                ),
              ),
              const Divider(height: 22),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.restart_alt_rounded, color: accentColor),
                title: Text('Reset app appearance',
                    style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Google Sans Flex')),
                subtitle: Text('Return theme, motion and touch settings to defaults.',
                    style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontFamily: 'Google Sans Flex')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  themeNotifier.value = ThemeMode.light;
                  await setSmoothMotion(true);
                  await setHaptics(true);
                  await setNotifications(true);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _settingSwitch(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Future<void> Function(bool) onChanged,
    required Color textColor,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: accentColor),
      title: Text(title,
          style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontFamily: 'Google Sans Flex')),
      subtitle: Text(subtitle,
          style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
              fontSize: 12.5,
              fontFamily: 'Google Sans Flex')),
      value: value,
      activeColor: accentColor,
      onChanged: (next) => onChanged(next),
    );
  }
}
