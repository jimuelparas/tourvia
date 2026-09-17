import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourvia/core/models/tour_model.dart';
import 'package:tourvia/core/theme/app_colors.dart';

Widget _buildStatusBadge(String status) {
  Color bg;
  Color fg;
  String label;

  switch (status) {
    case 'active':
      bg = AppColors.success.withValues(alpha: 0.12);
      fg = AppColors.success;
      label = 'Active';
      break;
    case 'completed':
      bg = AppColors.textSecondary.withValues(alpha: 0.12);
      fg = AppColors.textSecondary;
      label = 'Completed';
      break;
    default:
      bg = AppColors.primary.withValues(alpha: 0.12);
      fg = AppColors.primary;
      label = 'Upcoming';
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
    ),
  );
}

Widget _buildTourHeader(BuildContext context, Tour tour) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tour.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusBadge(tour.status),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tour.formattedDateRange,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${tour.totalDays} ${tour.totalDays == 1 ? 'Day' : 'Days'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        if (tour.schedule.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Text(
            tour.schedule,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ],
    ),
  );
}

Widget _buildAccessCodeCard(BuildContext context, Tour tour) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          AppColors.primarySurface,
          AppColors.primary.withValues(alpha: 0.08),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tour Access Code',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tour.accessCode,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.copy_rounded, size: 15),
              label: const Text('Copy Code', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Tourists enter this code in their app to submit a join request for your review.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

Widget _buildModuleCard(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required Color color,
  required VoidCallback onTap,
  int badgeCount = 0,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      height: 105,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildModulesGrid(BuildContext context, Tour tour) {
  return Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _buildModuleCard(
              context,
              icon: Icons.map_rounded,
              title: 'Itinerary',
              subtitle: 'Destinations & Time',
              color: const Color(0xFF4A90E2),
              onTap: () {},
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildModuleCard(
              context,
              icon: Icons.people_alt_rounded,
              title: 'Tourist Manage',
              subtitle: 'Join Requests & Roster',
              color: const Color(0xFFF5A623),
              onTap: () {},
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _buildModuleCard(
              context,
              icon: Icons.how_to_reg_rounded,
              title: 'Attendance',
              subtitle: 'Check-in Tourists',
              color: const Color(0xFF7ED321),
              onTap: () {},
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildModuleCard(
              context,
              icon: Icons.forum_rounded,
              title: 'Group Chat',
              subtitle: 'Tour Discussion',
              color: const Color(0xFF9013FE),
              onTap: () {},
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _buildModuleCard(
              context,
              icon: Icons.navigation_rounded,
              title: 'Live Tracking',
              subtitle: 'Synchronized GPS',
              color: const Color(0xFF50E3C2),
              onTap: () {},
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildModuleCard(
              context,
              icon: Icons.emergency_rounded,
              title: 'SOS Monitor',
              subtitle: 'Emergency Alerts',
              color: AppColors.error,
              onTap: () {},
            ),
          ),
        ],
      ),
    ],
  );
}

void main() {
  testWidgets('Tour hub full layout renders without error', (WidgetTester tester) async {
    final tour = Tour(
      id: 'test_tour_1',
      name: 'gg',
      startDate: DateTime(2026, 9, 15),
      endDate: DateTime(2026, 9, 15),
      totalDays: 1,
      guideId: 'guide_1',
      guideName: 'Test Guide',
      status: 'upcoming',
      accessCode: 'TRV-DEE',
      touristCount: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: Text(tour.name)),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(builder: (ctx) => _buildTourHeader(ctx, tour)),
                  const SizedBox(height: 16),
                  Builder(builder: (ctx) => _buildAccessCodeCard(ctx, tour)),
                  const SizedBox(height: 20),
                  const Text('Tour Modules'),
                  const SizedBox(height: 12),
                  Builder(builder: (ctx) => _buildModulesGrid(ctx, tour)),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('gg'), findsWidgets);
    expect(find.text('Tour Access Code'), findsOneWidget);
    expect(find.text('TRV-DEE'), findsOneWidget);
    expect(find.text('Itinerary'), findsOneWidget);
    expect(find.text('Tourist Manage'), findsOneWidget);
    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('Group Chat'), findsOneWidget);
    expect(find.text('Live Tracking'), findsOneWidget);
    expect(find.text('SOS Monitor'), findsOneWidget);
  });
}
