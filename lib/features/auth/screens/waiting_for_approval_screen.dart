import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/models/tourist_session.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../screens/terms_and_conditions_screen.dart';
import '../screens/tourist_login_screen.dart';

/// Screen displayed to a tourist after submitting their join request,
/// waiting for the tour guide to approve or reject. (REV-002 Section 6.1)
class WaitingForApprovalScreen extends StatefulWidget {
  final String tourId;
  final String tourName;
  final String guideName;
  final String touristId;
  final String touristName;
  final String accessCode;

  const WaitingForApprovalScreen({
    super.key,
    required this.tourId,
    required this.tourName,
    required this.guideName,
    required this.touristId,
    required this.touristName,
    required this.accessCode,
  });

  @override
  State<WaitingForApprovalScreen> createState() =>
      _WaitingForApprovalScreenState();
}

class _WaitingForApprovalScreenState extends State<WaitingForApprovalScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _requestSub;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _listenToRequestStatus();
  }

  void _listenToRequestStatus() {
    _requestSub = FirebaseFirestore.instance
        .collection('tours')
        .doc(widget.tourId)
        .collection('join_requests')
        .doc(widget.touristId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted || _hasNavigated) return;

      if (snapshot.exists) {
        final data = snapshot.data();
        final status = data?['status'] as String? ?? 'pending';

        if (status == 'approved') {
          _handleApproved();
        }
      }
    });
  }

  Future<void> _handleApproved() async {
    if (_hasNavigated) return;
    _hasNavigated = true;

    final session = TouristSession(
      code: widget.accessCode,
      touristName: widget.touristName,
      sessionId: widget.tourId,
      codeDocId: widget.touristId,
    );

    await TouristSessionManager.set(session);

    NotificationService.saveTokenForTourist(
      widget.tourId,
      widget.touristId,
    );

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const TermsAndConditionsScreen(),
      ),
      (r) => false,
    );
  }

  Future<void> _cancelRequest() async {
    try {
      await FirebaseFirestore.instance
          .collection('tours')
          .doc(widget.tourId)
          .collection('join_requests')
          .doc(widget.touristId)
          .delete();
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const TouristLoginScreen()),
      (r) => false,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _requestSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Join Tour Request'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _cancelRequest,
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('tours')
            .doc(widget.tourId)
            .collection('join_requests')
            .doc(widget.touristId)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          final status = data?['status'] as String? ?? 'pending';

          if (status == 'rejected') {
            return _buildRejectedState();
          }

          return _buildPendingState();
        },
      ),
    );
  }

  Widget _buildPendingState() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.hourglass_top_rounded,
                      size: 48,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Request Sent!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Waiting for your Tour Guide to approve your join request.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // Tour Details Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tour_rounded,
                            color: Color(0xFF0284C7), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.tourName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tour Guide:',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                        ),
                        Text(
                          widget.guideName.isNotEmpty
                              ? widget.guideName
                              : 'Assigned Guide',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tourist Name:',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                        ),
                        Text(
                          widget.touristName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Status:',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Pending Approval',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'You will automatically enter once approved',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0284C7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Cancel button
              OutlinedButton.icon(
                onPressed: _cancelRequest,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Cancel Request'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedState() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.cancel_rounded,
                    size: 48,
                    color: AppColors.error,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Request Declined',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your tour guide has declined this join request. Please verify your tour details or contact your guide.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => const TouristLoginScreen()),
                  (r) => false,
                ),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Return to Login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
