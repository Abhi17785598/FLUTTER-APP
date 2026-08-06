import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'logout_dialog.dart';

/// Settings bottom sheet.
///
/// Extracted verbatim from `_ProfileScreenState._showSettingsScreen` (and its
/// `_buildSettingItem` helper) so the Profile screen, the Workspace Drawer and
/// the More bottom sheet can all invoke one implementation — see blueprint
/// §1.2.4 and §6. The body is unchanged, including the fact that the toggles
/// are currently non-persisting no-ops; wiring them up is out of scope for
/// this workstream.
void showSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
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
                  style:
                      AppTextStyles.heading3.copyWith(fontWeight: FontWeight.bold),
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
                  Icons.dark_mode_outlined,
                  'Dark Mode',
                  'Enable dark theme',
                  false,
                  (value) {},
                ),
                const SizedBox(height: 8),
                _buildSettingItem(
                  Icons.notifications_outlined,
                  'Push Notifications',
                  'Receive visit alerts',
                  true,
                  (value) {},
                ),
                const SizedBox(height: 8),
                _buildSettingItem(
                  Icons.location_on_outlined,
                  'Location Services',
                  'Show nearby properties',
                  true,
                  (value) {},
                ),
                const SizedBox(height: 8),
                _buildSettingItem(
                  Icons.language_outlined,
                  'Language',
                  'English',
                  null,
                  (value) {},
                ),
                const SizedBox(height: 8),
                _buildSettingItem(
                  Icons.email_outlined,
                  'Email Updates',
                  'Weekly property digest',
                  true,
                  (value) {},
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
                      child: const Icon(Icons.logout,
                          color: Colors.red, size: 20),
                    ),
                    title: const Text(
                      'Logout',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                    trailing:
                        const Icon(Icons.chevron_right, color: Colors.red),
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
    ),
  );
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
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
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
