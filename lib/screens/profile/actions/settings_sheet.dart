import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../services/notification_alert_preference.dart';
import 'logout_dialog.dart';

/// Settings bottom sheet.
///
/// Started as five toggles extracted verbatim from
/// `_ProfileScreenState._showSettingsScreen` — Dark Mode, Push Notifications,
/// Location Services, Language and Email Updates — every one a hard-coded
/// value with an empty `(value) {}` callback. None of them changed anything;
/// picking a switch just visually flipped it and forgot the choice on the
/// next open.
///
/// Checked against what this app actually has (no `ThemeMode`/dark palette,
/// no `flutter_localizations`/ARB files, no `profiles` email-preference
/// column or digest sender, and `geolocator`'s own `LocationService` wrapper
/// with nothing in the app calling it for a "nearby properties" feature) —
/// four of the five had nothing real to connect to and were removed rather
/// than kept as decoration. Only "Push Notifications" had a genuine, already
/// -running behavior underneath it — the Notification Centre's arrival sound
/// and vibration (`NotificationProvider._onInserted`) — so it stays,
/// retitled to describe that honestly and wired to
/// [NotificationAlertPreference] instead of a switch that reset itself.
void showSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _SettingsSheetBody(),
  );
}

class _SettingsSheetBody extends StatefulWidget {
  const _SettingsSheetBody();

  @override
  State<_SettingsSheetBody> createState() => _SettingsSheetBodyState();
}

class _SettingsSheetBodyState extends State<_SettingsSheetBody> {
  /// Null while the persisted value is still loading — [_buildSettingItem]
  /// renders that as a plain chevron rather than guessing a switch position.
  bool? _alertsEnabled;

  @override
  void initState() {
    super.initState();
    NotificationAlertPreference.isEnabled().then((value) {
      if (mounted) setState(() => _alertsEnabled = value);
    });
  }

  Future<void> _setAlertsEnabled(bool value) async {
    setState(() => _alertsEnabled = value);
    await NotificationAlertPreference.setEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Settings',
                  style: AppTextStyles.heading3.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSettingItem(
                  Icons.notifications_outlined,
                  'Notification Alerts',
                  'Sound and vibration for new activity',
                  _alertsEnabled,
                  (value) => _setAlertsEnabled(value),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.logout,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.red,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      showLogoutDialog(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildSettingItem(
  IconData icon,
  String title,
  String subtitle,
  bool? value,
  Function(bool) onChanged,
) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.textHint.withOpacity(0.1)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (value != null)
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          )
        else
          const Icon(Icons.chevron_right, color: AppColors.textHint),
      ],
    ),
  );
}
