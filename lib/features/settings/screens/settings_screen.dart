import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/tourist_session.dart';
import '../../auth/screens/terms_and_conditions_screen.dart';
import '../../auth/screens/role_selection_screen.dart';
import 'about_app_screen.dart';
import 'about_developers_screen.dart';
import 'profile_screen.dart';

/// Screen for Application Settings and Information (US-22, US-23, US-24, US-25).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Log Out'),
        content: const Text(
          'Are you sure you want to log out? You will need to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // close dialog
              final navigator = Navigator.of(context);

              // Perform real logout
              if (TouristSessionManager.isLoggedIn) {
                await TouristSessionManager.clear();
              } else if (AuthService.currentUser != null) {
                await AuthService.signOut();
              }

              navigator.pushAndRemoveUntil(
                MaterialPageRoute(
                    builder: (_) => const RoleSelectionScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Settings & Info'),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!TouristSessionManager.isLoggedIn &&
                AuthService.currentUser != null) ...[
              _buildSectionHeader('Account'),
              _buildListTile(
                context,
                icon: Icons.person_outline_rounded,
                title: 'My Profile',
                subtitle: 'View and edit your personal information',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _buildSectionHeader('Application'),
            _buildListTile(
              context,
              icon: Icons.info_outline_rounded,
              title: 'About the Application',
              subtitle: 'Purpose, features, and scope',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutAppScreen()),
              ),
            ),
            _buildListTile(
              context,
              icon: Icons.code_rounded,
              title: 'About the Developers',
              subtitle: 'Meet the team behind Tourvia',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AboutDevelopersScreen()),
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionHeader('Legal & Resources'),
            _buildListTile(
              context,
              icon: Icons.gavel_rounded,
              title: 'Terms and Conditions',
              subtitle: 'Usage rules and guidelines',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const TermsAndConditionsScreen(isReadOnly: true),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            // Logout button
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text('Log Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Tourvia Version 1.0.0',
                style: TextStyle(
                  color: AppColors.textHint,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.textHint,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style:
              const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: AppColors.textHint),
        onTap: onTap,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
