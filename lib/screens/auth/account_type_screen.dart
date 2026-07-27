import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';
import '../profile_completion/builder_registration/builder_registration_screen.dart';
import '../profile_completion/broker_registration/broker_registration_screen.dart';
import '../profile_completion/influencer_registration/influencer_registration_screen.dart';

/// Shown when an authenticated user has no user_type — typically a first-time
/// Google Sign-In user. The user picks their account type here, which stores
/// pending_user_type in SharedPreferences exactly like the email signup flow,
/// then routes into the same registration / home destinations.
class AccountTypeScreen extends StatefulWidget {
  final String userId;
  const AccountTypeScreen({required this.userId, super.key});

  @override
  State<AccountTypeScreen> createState() => _AccountTypeScreenState();
}

class _AccountTypeScreenState extends State<AccountTypeScreen> {
  bool _isLoading = false;

  Future<void> _selectType(String type) async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();

      if (type == 'individual') {
        // Individual users have no registration form — write profile immediately.
        await Supabase.instance.client
            .from('profiles')
            .update({'user_type': 'individual', 'profile_complete': true})
            .eq('user_id', widget.userId);
        await prefs.remove('pending_user_type');
        if (mounted) {
          await context.read<AuthProvider>().refreshProfile();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      } else {
        // Business types: store the pending type so the registration screen
        // and splash screen can route correctly, then push the registration form.
        await prefs.setString('pending_user_type', type);
        if (mounted) {
          final Widget screen = switch (type) {
            'builder'    => const BuilderRegistrationScreen(),
            'broker'     => const BrokerRegistrationScreen(),
            'influencer' => const InfluencerRegistrationScreen(),
            _            => const HomeScreen(),
          };
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => screen),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Something went wrong: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 56),
              Text(
                'What best describes you?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A2E),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'This helps us personalise your experience.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 40),
              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: Column(
                    children: [
                      _TypeTile(
                        icon: Icons.person_rounded,
                        label: 'Individual',
                        subtitle: 'Browse and save properties',
                        color: Colors.grey.shade700,
                        onTap: () => _selectType('individual'),
                      ),
                      const SizedBox(height: 12),
                      _TypeTile(
                        icon: Icons.business_rounded,
                        label: 'Builder',
                        subtitle: 'List and manage your projects',
                        color: const Color(0xFF3F51B5),
                        onTap: () => _selectType('builder'),
                      ),
                      const SizedBox(height: 12),
                      _TypeTile(
                        icon: Icons.home_work_rounded,
                        label: 'Broker',
                        subtitle: 'List properties and find clients',
                        color: const Color(0xFF009688),
                        onTap: () => _selectType('broker'),
                      ),
                      const SizedBox(height: 12),
                      _TypeTile(
                        icon: Icons.play_circle_fill_rounded,
                        label: 'Influencer',
                        subtitle: 'Promote projects and earn',
                        color: const Color(0xFF9C27B0),
                        onTap: () => _selectType('influencer'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _TypeTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
