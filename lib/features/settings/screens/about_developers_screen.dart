import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// About the Developers screen (US-23).
/// Displays developer cards with roles and contributions.
class AboutDevelopersScreen extends StatelessWidget {
  const AboutDevelopersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('About the Developers'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(Icons.groups_rounded,
                      color: Colors.white, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'Meet the Team',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'The passionate developers behind Tourvia',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildDeveloperCard(
              context,
              name: 'Collarga, Raniel Rayen C.',
              role: 'Project Manager',
              description:
                  'Led the development sprint planning, task assignments, and coordinated across the team to deliver features on schedule.',
              color: AppColors.primary,
              icon: Icons.assignment_rounded,
            ),
            _buildDeveloperCard(
              context,
              name: 'Paras, Jimuel S.',
              role: 'Programmer',
              description:
                  'Handled Flutter UI implementation, state management, API integration, and developed dynamic client-side logic.',
              color: AppColors.primary,
              icon: Icons.code_rounded,
            ),
            _buildDeveloperCard(
              context,
              name: 'Capunpun, Samantha M.',
              role: 'UX & UI Designer',
              description:
                  'Designed the user flows, typography, color palette, and high-fidelity mockups to ensure a seamless and intuitive user experience.',
              color: AppColors.accentTeal,
              icon: Icons.palette_rounded,
            ),
            _buildDeveloperCard(
              context,
              name: 'Lavarias, Dexter',
              role: 'System Analyst',
              description:
                  'Conducted database schema design, analyzed application requirements, and mapped logical flows for the system.',
              color: AppColors.accent,
              icon: Icons.analytics_rounded,
            ),
            _buildDeveloperCard(
              context,
              name: 'Lozano, John Roel A.',
              role: 'QA & Tester',
              description:
                  'Executed user acceptance tests, identified performance bottlenecks, and verified core features to ensure high reliability.',
              color: AppColors.accentTeal,
              icon: Icons.bug_report_rounded,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite_rounded,
                      color: AppColors.primary, size: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Built with passion for improving Philippine tourism experiences.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
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

  Widget _buildDeveloperCard(
    BuildContext context, {
    required String name,
    required String role,
    required String description,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  role,
                  style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
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
