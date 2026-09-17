import 'package:flutter/material.dart';
import '../../../core/models/join_request_model.dart';
import '../../../core/services/tour_service.dart';
import '../../../core/theme/app_colors.dart';
import 'tour_guide_home_screen.dart';

/// Screen for managing tourist join requests for a specific tour (REV-002 Section 6).
///
/// Provides tabs:
/// - Pending (with Approve & Reject action buttons)
/// - Approved (active tour members)
/// - Rejected
class TourJoinRequestsScreen extends StatefulWidget {
  final String tourId;
  final String tourName;

  const TourJoinRequestsScreen({
    super.key,
    required this.tourId,
    required this.tourName,
  });

  @override
  State<TourJoinRequestsScreen> createState() => _TourJoinRequestsScreenState();
}

class _TourJoinRequestsScreenState extends State<TourJoinRequestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────

  Future<void> _approve(JoinRequest request) async {
    try {
      await TourService.approveJoinRequest(widget.tourId, request);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${request.touristName} has been approved and added to the tour!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve request: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _reject(JoinRequest request) async {
    try {
      await TourService.rejectJoinRequest(widget.tourId, request.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Join request from ${request.touristName} was rejected.'),
          backgroundColor: AppColors.textSecondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject request: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ── Build UI ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Join Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              widget.tourName,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const TourGuideHomeScreen()),
                (route) => false,
              );
            }
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: StreamBuilder<List<JoinRequest>>(
        stream: TourService.watchJoinRequests(widget.tourId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allRequests = snapshot.data ?? [];
          final pending = allRequests.where((r) => r.isPending).toList();
          final approved = allRequests.where((r) => r.isApproved).toList();
          final rejected = allRequests.where((r) => r.isRejected).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildRequestsList(pending, isPendingTab: true),
              _buildRequestsList(approved),
              _buildRequestsList(rejected),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRequestsList(List<JoinRequest> requests, {bool isPendingTab = false}) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPendingTab ? Icons.inbox_outlined : Icons.folder_open_outlined,
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              isPendingTab ? 'No pending join requests' : 'No requests in this category',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final req = requests[index];
        return _buildRequestCard(req, isPendingTab: isPendingTab);
      },
    );
  }

  Widget _buildRequestCard(JoinRequest request, {required bool isPendingTab}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primarySurface,
                radius: 20,
                child: Text(
                  request.touristName.isNotEmpty ? request.touristName[0].toUpperCase() : 'T',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.touristName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    if (request.contactNumber.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            request.contactNumber,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              _buildStatusBadge(request.status),
            ],
          ),
          if (request.emergencyContact.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.contact_emergency_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Emergency: ${request.emergencyContact}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isPendingTab) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _reject(request),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approve(request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'approved':
        bg = AppColors.success.withValues(alpha: 0.1);
        fg = AppColors.success;
        label = 'Approved';
        break;
      case 'rejected':
        bg = AppColors.error.withValues(alpha: 0.1);
        fg = AppColors.error;
        label = 'Rejected';
        break;
      default:
        bg = AppColors.primary.withValues(alpha: 0.1);
        fg = AppColors.primary;
        label = 'Pending';
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
}
