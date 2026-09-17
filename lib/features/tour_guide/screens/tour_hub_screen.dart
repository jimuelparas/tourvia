import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/join_request_model.dart';
import '../../../core/models/tour_model.dart';
import '../../../core/services/tour_service.dart';
import '../../../core/services/itinerary_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/chat_badge_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../chat/screens/group_chat_screen.dart';
import '../../itinerary/models/itinerary_item.dart';
import '../../sos/screens/sos_screen.dart';
import '../../tracking/screens/tour_guide_map_screen.dart';
import 'add_edit_itinerary_screen.dart';
import 'tour_guide_attendance_screen.dart';
import 'tour_guide_home_screen.dart';
import 'tour_guide_itinerary_screen.dart';
import 'tour_join_requests_screen.dart';

/// Manage Tour Hub (REV-002 Section 2).
///
/// Master screen for a specific tour container. Houses:
/// - Tour metadata & auto-generated Access Code (with Copy Access Code only)
/// - Itinerary & Destination management
/// - Tourist Join Requests (Pending / Approved / Rejected)
/// - Attendance tracking
/// - Tour-isolated Group Chat (Read-only when completed)
/// - Live Tracking & SOS monitoring
class TourHubScreen extends StatefulWidget {
  final String tourId;
  final Tour? initialTour;

  const TourHubScreen({
    super.key,
    required this.tourId,
    this.initialTour,
  });

  @override
  State<TourHubScreen> createState() => _TourHubScreenState();
}

class _TourHubScreenState extends State<TourHubScreen> {
  Tour? _tour;
  bool _isLoading = true;
  late final Stream<Tour?> _tourStream;
  late final Stream<List<ItineraryItem>> _itineraryStream;
  late final Stream<List<JoinRequest>> _joinRequestsStream;
  late final Stream<int> _unreadStream;

  @override
  void initState() {
    super.initState();
    _tour = widget.initialTour;
    _tourStream = TourService.watchTour(widget.tourId);
    _itineraryStream = ItineraryService.watchItinerary(widget.tourId);
    _joinRequestsStream = TourService.watchJoinRequests(widget.tourId);
    _unreadStream = ChatBadgeService.watchUnreadCount(
      widget.tourId,
      AuthService.currentUser?.uid ?? widget.initialTour?.guideId ?? '',
    );
    _fetchTour();
  }

  Future<void> _fetchTour() async {
    try {
      final fetched = await TourService.getTour(widget.tourId);
      if (mounted && fetched != null) {
        setState(() {
          _tour = fetched;
          _isLoading = false;
        });
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Tour?>(
      initialData: _tour ?? widget.initialTour,
      stream: _tourStream,
      builder: (context, snapshot) {
        final tour = snapshot.data ?? _tour ?? widget.initialTour;

        if (tour == null) {
          if (_isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const TourGuideHomeScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
              title: const Text('Manage Tour'),
            ),
            body: const Center(child: Text('Tour not found.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(tour.name),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (_) => const TourGuideHomeScreen()),
                    (route) => false,
                  );
                }
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                tooltip: 'Delete Tour',
                onPressed: () => _confirmDelete(context, tour),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTourHeader(context, tour),
                  const SizedBox(height: 16),
                  _buildAccessCodeCard(context, tour),
                  const SizedBox(height: 20),
                  _buildItinerarySection(context, tour),
                  const SizedBox(height: 20),
                  _buildSectionTitle('Tour Modules'),
                  const SizedBox(height: 12),
                  _buildModulesGrid(context, tour),
                  const SizedBox(height: 24),
                  _buildLifecycleActions(context, tour),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Header ───────────────────────────────────────────────

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
              _buildStatusBadge(tour.effectiveStatus),
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

  // ── Access Code Card ─────────────────────────────────────

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
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: tour.accessCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Access Code "${tour.accessCode}" copied to clipboard!'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
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

  // ── Itinerary Section ─────────────────────────────────────

  Widget _buildItinerarySection(BuildContext context, Tour tour) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('Tour Itinerary'),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditItineraryScreen(
                    sessionId: tour.id,
                    tourId: tour.id,
                    tourStartDate: tour.startDate,
                    tourEndDate: tour.endDate,
                  ),
                ),
              ),
              icon: const Icon(Icons.add_location_alt_rounded, size: 15),
              label: const Text('Add Stop', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<ItineraryItem>>(
          stream: _itineraryStream,
          builder: (context, snapshot) {
            final stops = snapshot.data ?? [];

            if (stops.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.map_outlined,
                      size: 36,
                      color: AppColors.textSecondary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No destinations added yet.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Plan your schedule by adding stops with locations and times.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddEditItineraryScreen(
                            sessionId: tour.id,
                            tourId: tour.id,
                            tourStartDate: tour.startDate,
                            tourEndDate: tour.endDate,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add First Destination', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(8),
                    itemCount: stops.length > 3 ? 3 : stops.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final stop = stops[index];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        title: Text(
                          stop.destinationName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        subtitle: Text(
                          '${stop.startTime} - ${stop.endTime}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textHint),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TourGuideItineraryScreen(tourId: tour.id),
                          ),
                        ),
                      );
                    },
                  ),
                  InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TourGuideItineraryScreen(tourId: tour.id),
                      ),
                    ),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            stops.length > 3
                                ? 'View all ${stops.length} stops on Map'
                                : 'Manage Full Itinerary & Map',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Modules Grid ─────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildModulesGrid(BuildContext context, Tour tour) {
    return StreamBuilder<List<JoinRequest>>(
      stream: _joinRequestsStream,
      builder: (context, reqSnapshot) {
        final requests = reqSnapshot.data ?? [];
        final pendingCount = requests.where((r) => r.isPending).length;

        return StreamBuilder<int>(
          stream: _unreadStream,
          builder: (context, badgeSnap) {
            final unread = badgeSnap.data ?? 0;

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
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TourGuideItineraryScreen(tourId: tour.id),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildModuleCard(
                        context,
                        icon: Icons.people_alt_rounded,
                        title: 'Tourist Manage',
                        subtitle: pendingCount > 0
                            ? '$pendingCount Pending'
                            : 'Join Requests & Roster',
                        badgeCount: pendingCount,
                        color: const Color(0xFFF5A623),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TourJoinRequestsScreen(
                              tourId: tour.id,
                              tourName: tour.name,
                            ),
                          ),
                        ),
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
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TourGuideAttendanceScreen(sessionId: tour.id),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildModuleCard(
                        context,
                        icon: Icons.forum_rounded,
                        title: 'Group Chat',
                        subtitle: tour.isCompleted
                            ? 'Read-Only (Ended)'
                            : 'Tour Discussion',
                        color: const Color(0xFF9013FE),
                        badgeCount: unread,
                        onTap: () async {
                          final guideId =
                              AuthService.currentUser?.uid ?? tour.guideId;
                          ChatBadgeService.updateLastRead(tour.id, guideId);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GroupChatScreen(
                                sessionId: tour.id,
                                isCurrentUserGuide: true,
                                isReadOnly: tour.isCompleted,
                              ),
                            ),
                          );
                          ChatBadgeService.updateLastRead(tour.id, guideId);
                        },
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
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TourGuideMapScreen(sessionId: tour.id),
                          ),
                        ),
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
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SosScreen(sessionId: tour.id),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
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

  // ── Lifecycle Actions ─────────────────────────────────────

  Widget _buildLifecycleActions(BuildContext context, Tour tour) {
    if (tour.isCompleted) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'This tour is completed and archived. Chat is now Read-Only.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton.icon(
        onPressed: () => _confirmCompleteTour(context, tour),
        icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
        label: const Text('End & Complete Tour', style: TextStyle(fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────

  void _confirmCompleteTour(BuildContext context, Tour tour) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End Tour?'),
        content: const Text(
          'Marking this tour as Completed will archive the roster, preserve attendance records, and set the group chat to Read-Only mode.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await TourService.completeTour(tour.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('End Tour'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Tour tour) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Tour?'),
        content: Text(
          'Are you sure you want to permanently delete "${tour.name}" and all its itineraries and data?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await TourService.deleteTour(tour.id);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(TourStatus? status) {
    Color bg;
    Color fg;
    String labelText;

    switch (status) {
      case TourStatus.active:
        bg = AppColors.success.withValues(alpha: 0.12);
        fg = AppColors.success;
        labelText = 'Active';
        break;
      case TourStatus.completed:
        bg = AppColors.textSecondary.withValues(alpha: 0.12);
        fg = AppColors.textSecondary;
        labelText = 'Completed';
        break;
      case TourStatus.upcoming:
      default:
        bg = AppColors.primary.withValues(alpha: 0.12);
        fg = AppColors.primary;
        labelText = 'Upcoming';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        labelText,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
