import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// About the Developers screen (US-23).
/// Displays developer cards with roles and contributions.
/// Cards are expandable — tap to show/hide description.
class AboutDevelopersScreen extends StatefulWidget {
  const AboutDevelopersScreen({super.key});

  @override
  State<AboutDevelopersScreen> createState() => _AboutDevelopersScreenState();
}

class _AboutDevelopersScreenState extends State<AboutDevelopersScreen> {
  /// Tracks which developer card is currently expanded (-1 = none).
  int _expandedIndex = -1;

  static const _developers = [
    _DeveloperInfo(
      name: 'Collarga, Raniel Rayen C.',
      role: 'Project Manager',
      description:
          'Led the development sprint planning, task assignments, and coordinated across the team to deliver features on schedule.',
      imagePath: 'assets/audio/image/Collarga Raniel Rayen C..png',
    ),
    _DeveloperInfo(
      name: 'Paras, Jimuel S.',
      role: 'Programmer',
      description:
          'Handled Flutter UI implementation, state management, API integration, and developed dynamic client-side logic.',
      imagePath: 'assets/audio/image/Paras, Jimuel S..png',
    ),
    _DeveloperInfo(
      name: 'Capunpun, Samantha M.',
      role: 'UX & UI Designer',
      description:
          'Designed the user flows, typography, color palette, and high-fidelity mockups to ensure a seamless and intuitive user experience.',
      imagePath: 'assets/audio/image/Capunpun, Samantha M..png',
    ),
    _DeveloperInfo(
      name: 'Lavarias, Dexter',
      role: 'System Analyst',
      description:
          'Conducted database schema design, analyzed application requirements, and mapped logical flows for the system.',
      imagePath: 'assets/audio/image/Lavarias, Dexter.png',
    ),
    _DeveloperInfo(
      name: 'Lozano, John Roel A.',
      role: 'QA & Tester',
      description:
          'Executed user acceptance tests, identified performance bottlenecks, and verified core features to ensure high reliability.',
      imagePath: 'assets/audio/image/Lozano, John Roel A..png',
    ),
  ];

  static const _cardColors = [
    AppColors.primary,
    AppColors.primary,
    AppColors.accentTeal,
    AppColors.accent,
    AppColors.accentTeal,
  ];

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
            for (int i = 0; i < _developers.length; i++)
              _buildDeveloperCard(
                context,
                index: i,
                dev: _developers[i],
                color: _cardColors[i],
                isExpanded: _expandedIndex == i,
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
    required int index,
    required _DeveloperInfo dev,
    required Color color,
    required bool isExpanded,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _expandedIndex = _expandedIndex == index ? -1 : index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isExpanded ? color.withValues(alpha: 0.4) : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: isExpanded
                  ? color.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: isExpanded ? 12 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: color.withValues(alpha: 0.1),
                  backgroundImage: AssetImage(dev.imagePath),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dev.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dev.role,
                        style: TextStyle(
                          fontSize: 13,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  dev.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }
}

/// Data class for developer info.
class _DeveloperInfo {
  final String name;
  final String role;
  final String description;
  final String imagePath;

  const _DeveloperInfo({
    required this.name,
    required this.role,
    required this.description,
    required this.imagePath,
  });
}
