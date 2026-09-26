import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/tour_model.dart';
import '../../../core/models/tourist_session.dart';
import '../../../core/services/access_code_service.dart';
import '../../../core/services/lockout_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../tourist/screens/tourist_dashboard_screen.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/tour_qr_scanner_screen.dart';
import 'terms_and_conditions_screen.dart';
import 'waiting_for_approval_screen.dart';

/// Tourist login screen via access code (US-04).
///
/// Collects an access code from the tourist. Provides:
/// - Inline validation.
/// - Status-aware error banners for invalid/expired codes.
/// - 5-attempt rate-limiting with 15-minute temporary lockout.
/// - Navigation back to role selection or into the tour session.
class TouristLoginScreen extends StatefulWidget {
  const TouristLoginScreen({super.key});

  @override
  State<TouristLoginScreen> createState() => _TouristLoginScreenState();
}

class _TouristLoginScreenState extends State<TouristLoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _accessCodeCtrl = TextEditingController();

  bool _isSubmitting = false;
  String? _loginError;

  /// Lockout status state for 5-attempt rate-limiting.
  LockoutStatus? _lockoutStatus;
  Timer? _lockoutTimer;

  // ── Animations ──────────────────────────────────────────
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();
    _checkInitialLockout();
  }

  Future<void> _checkInitialLockout() async {
    final status = await LockoutService.checkLockout(LockoutType.touristCode);
    if (!mounted) return;
    setState(() => _lockoutStatus = status);
    if (status.isLocked) {
      _startLockoutCountdown();
    }
  }

  void _startLockoutCountdown() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final status = await LockoutService.checkLockout(LockoutType.touristCode);
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _lockoutStatus = status);
      if (!status.isLocked) {
        timer.cancel();
        setState(() => _loginError = null);
      }
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    _accessCodeCtrl.dispose();
    super.dispose();
  }

  // ── Validators ──────────────────────────────────────────

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.fieldRequired;
    return null;
  }


  // ── QR Scanner Handler ───────────────────────────────────

  Future<void> _onScanQr() async {
    final scanned = await TourQrScannerScreen.scan(context);
    if (scanned == null || scanned.trim().isEmpty) return;

    setState(() {
      _loginError = null;
      _isSubmitting = true;
    });

    try {
      await _validateAndProcessQr(scanned.trim());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _validateAndProcessQr(String scanned) async {
    String? parsedTourId;
    String? parsedAccessCode;

    // 1. Parse payload: JSON or raw code
    if (scanned.startsWith('{') && scanned.endsWith('}')) {
      try {
        final Map<String, dynamic> map =
            jsonDecode(scanned) as Map<String, dynamic>;
        parsedTourId = map['tourId'] as String?;
        parsedAccessCode = map['accessCode'] as String?;
      } catch (_) {}
    } else if (scanned.toUpperCase().startsWith('TRV-')) {
      parsedAccessCode = scanned.toUpperCase();
    } else if (scanned.contains('tourId=') || scanned.contains('code=')) {
      final uri = Uri.tryParse(scanned);
      if (uri != null) {
        parsedTourId = uri.queryParameters['tourId'];
        parsedAccessCode =
            uri.queryParameters['code'] ?? uri.queryParameters['accessCode'];
      }
    } else {
      if (scanned.length >= 4 && scanned.length <= 12) {
        parsedAccessCode = scanned.toUpperCase();
      } else {
        parsedTourId = scanned;
      }
    }

    DocumentSnapshot<Map<String, dynamic>>? tourDoc;

    // 2. Lookup tour by ID
    if (parsedTourId != null && parsedTourId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('tours')
            .doc(parsedTourId)
            .get();
        if (doc.exists) {
          tourDoc = doc;
        }
      } catch (_) {}
    }

    // 3. Lookup tour by Access Code if not found by ID
    if (tourDoc == null &&
        parsedAccessCode != null &&
        parsedAccessCode.isNotEmpty) {
      try {
        final query = await FirebaseFirestore.instance
            .collection('tours')
            .where('accessCode', isEqualTo: parsedAccessCode)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          tourDoc = query.docs.first;
        }
      } catch (_) {}
    }

    // 4. Fallback lookup via AccessCodeService
    if (tourDoc == null &&
        parsedAccessCode != null &&
        parsedAccessCode.isNotEmpty) {
      try {
        tourDoc = await AccessCodeService.validateCode(parsedAccessCode);
      } on AccessCodeException catch (e) {
        if (e.code == 'tour-completed') {
          setState(() => _loginError = 'This tour has already ended.');
          return;
        }
      } catch (_) {}
    }

    // Verify: QR format is valid & Tour exists
    if (tourDoc == null || !tourDoc.exists) {
      setState(() => _loginError = 'Invalid Tour QR Code.');
      return;
    }

    final data = tourDoc.data() ?? {};

    // Verify: Tour is not deleted
    if (data['isDeleted'] == true) {
      setState(() => _loginError = 'Invalid Tour QR Code.');
      return;
    }

    // Verify: Access Code matches that Tour
    final tourCode = (data['accessCode'] as String? ?? '').toUpperCase();
    if (parsedAccessCode != null && parsedAccessCode.isNotEmpty) {
      if (tourCode != parsedAccessCode.toUpperCase()) {
        setState(() => _loginError = 'Invalid Tour QR Code.');
        return;
      }
    }

    // Verify: Tour is not Completed
    final status = (data['status'] as String? ?? 'active').toLowerCase();
    final isEnded = data['isEnded'] == true;
    if (status == 'completed' || status == 'ended' || isEnded) {
      setState(() => _loginError = 'This tour has already ended.');
      return;
    }

    // Valid tour found! Pre-fill access code field
    _accessCodeCtrl.text = tourCode;

    // Reset lockout attempts on valid scan
    await LockoutService.resetAttempts(LockoutType.touristCode);

    // Display Tour Information sheet to continue join request
    if (!mounted) return;
    _showTourInfoAndJoinSheet(tourDoc);
  }

  // ── Submit Manual Code ───────────────────────────────────

  Future<void> _onSubmit() async {
    // Check lockout before validating access code
    final currentStatus =
        await LockoutService.checkLockout(LockoutType.touristCode);
    if (currentStatus.isLocked) {
      setState(() {
        _lockoutStatus = currentStatus;
        _loginError =
            'Access code input is temporarily locked due to 5 consecutive failed attempts. Please try again in ${currentStatus.formattedRemainingTime}.';
      });
      _startLockoutCountdown();
      return;
    }

    setState(() => _loginError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final codeDoc =
          await AccessCodeService.validateCode(_accessCodeCtrl.text);
      if (!mounted) return;

      // Reset lockout attempts on valid access code
      await LockoutService.resetAttempts(LockoutType.touristCode);

      final data = codeDoc.data() ?? {};
      final status = (data['status'] as String? ?? 'active').toLowerCase();
      final isEnded = data['isEnded'] == true;
      if (status == 'completed' || status == 'ended' || isEnded) {
        setState(() {
          _isSubmitting = false;
          _loginError = 'This tour has already ended.';
        });
        return;
      }

      setState(() {
        _isSubmitting = false;
      });

      _showTourInfoAndJoinSheet(codeDoc);
    } on AccessCodeException catch (e) {
      if (!mounted) return;
      await _handleLoginFailure(e.message);
    } catch (e) {
      if (!mounted) return;
      await _handleLoginFailure('Something went wrong. Please try again.');
    }
  }

  Future<void> _handleLoginFailure(String baseMessage) async {
    final status = await LockoutService.recordFailure(LockoutType.touristCode);
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _lockoutStatus = status;
      if (status.isLocked) {
        _loginError =
            'Too many failed attempts (5/5). You have been locked out for 15 minutes. Try again in ${status.formattedRemainingTime}.';
        _startLockoutCountdown();
      } else {
        _loginError =
            '$baseMessage (${status.remainingAttempts} attempt${status.remainingAttempts == 1 ? '' : 's'} remaining before 15-minute lockout)';
      }
    });
  }

  // ── Tour Information & Join Request Sheet ───────────────

  void _showTourInfoAndJoinSheet(
      DocumentSnapshot<Map<String, dynamic>> codeDoc) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedName = prefs.getString('tourist_cached_name') ?? '';

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _buildTourInfoAndJoinWidget(ctx, codeDoc,
            initialName: cachedName),
      ),
    );
  }

  Widget _buildTourInfoAndJoinWidget(
    BuildContext sheetCtx,
    DocumentSnapshot<Map<String, dynamic>> codeDoc, {
    String initialName = '',
  }) {
    final nameCtrl = TextEditingController(text: initialName);
    bool isClaiming = false;
    String? sheetError;
    DocumentSnapshot<Map<String, dynamic>>? existingMemberDoc;

    final isTourDoc = codeDoc.reference.parent.id == 'tours';
    final tourId = isTourDoc
        ? codeDoc.id
        : (codeDoc.data()?['tourId'] as String? ?? codeDoc.id);
    final tourData = codeDoc.data() ?? {};
    final tourName = tourData['name'] as String? ?? 'Tour';
    final guideName = tourData['guideName'] as String? ?? 'Tour Guide';
    final accessCode =
        (tourData['accessCode'] as String? ?? _accessCodeCtrl.text)
            .toUpperCase();
    final totalDays = (tourData['totalDays'] as num?)?.toInt() ?? 1;

    String? formatTourDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) {
        return Tour.formatDate(val.toDate());
      }
      if (val is DateTime) {
        return Tour.formatDate(val);
      }
      if (val is String && val.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(val.trim());
        if (parsed != null) {
          return Tour.formatDate(parsed);
        }
        return val.trim();
      }
      return null;
    }

    final startDateStr = formatTourDate(tourData['startDate']);
    final endDateStr = formatTourDate(tourData['endDate']);

    String dateText = '$totalDays ${totalDays == 1 ? 'Day' : 'Days'}';
    if (startDateStr != null &&
        endDateStr != null &&
        startDateStr.isNotEmpty &&
        endDateStr.isNotEmpty) {
      if (startDateStr == endDateStr) {
        dateText = '$startDateStr • $dateText';
      } else {
        dateText = '$startDateStr – $endDateStr • $dateText';
      }
    } else if (startDateStr != null && startDateStr.isNotEmpty) {
      dateText = '$startDateStr • $dateText';
    }

    return StatefulBuilder(
      builder: (context, setSheetState) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sheet Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.travel_explore_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Tour Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 20, color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Tour Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tourName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person_pin_rounded,
                            size: 15, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            guideName,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            dateText,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppColors.primary
                                    .withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            accessCode,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Name Input Prompt
              const Text(
                'Enter your full name so your tour guide can identify you:',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),

              CustomTextField(
                controller: nameCtrl,
                label: 'Full Name',
                hint: 'e.g. Juan Dela Cruz',
                prefixIcon: Icons.person_rounded,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {},
              ),

              // Inline Error in Sheet
              if (sheetError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          sheetError!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (existingMemberDoc != null) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton.icon(
                      onPressed: () async {
                        final memberData = existingMemberDoc!.data() ?? {};
                        final memberName = (memberData['touristName'] as String?)?.trim() ?? nameCtrl.text.trim();
                        final session = TouristSession(
                          code: accessCode,
                          touristName: memberName.isNotEmpty ? memberName : 'Tourist',
                          sessionId: tourId,
                          codeDocId: existingMemberDoc!.id,
                        );
                        await TouristSessionManager.set(session);
                        if (!context.mounted) return;
                        Navigator.of(sheetCtx).pop();
                        _showTermsAndConditions();
                      },
                      icon: const Icon(Icons.login_rounded, size: 16, color: AppColors.primary),
                      label: Text(
                        'Re-enter Tour as ${nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : "Member"}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 20),

              // Continue Join Request Button
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: isClaiming
                      ? null
                      : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                        ),
                  color: isClaiming ? AppColors.surfaceVariant : null,
                  boxShadow: isClaiming
                      ? []
                      : [
                          BoxShadow(
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: ElevatedButton(
                  onPressed: isClaiming
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            setSheetState(() => sheetError =
                                'Please enter your full name.');
                            return;
                          }

                          setSheetState(() {
                            isClaiming = true;
                            sheetError = null;
                          });

                          final rootContext = context;
                          final navigator = Navigator.of(sheetCtx);

                          try {
                            // 1. Check if tourist is already a member
                            final touristDocQuery = await FirebaseFirestore
                                .instance
                                .collection('tours')
                                .doc(tourId)
                                .collection('tourists')
                                .where('touristName', isEqualTo: name)
                                .limit(1)
                                .get();

                            if (touristDocQuery.docs.isNotEmpty) {
                              setSheetState(() {
                                isClaiming = false;
                                sheetError =
                                    'You have already joined this tour.';
                                existingMemberDoc = touristDocQuery.docs.first;
                              });
                              return;
                            }

                            // 2. Check if tourist already submitted a request
                            final pendingQuery = await FirebaseFirestore
                                .instance
                                .collection('tours')
                                .doc(tourId)
                                .collection('join_requests')
                                .where('touristName', isEqualTo: name)
                                .where('status', isEqualTo: 'pending')
                                .limit(1)
                                .get();

                            if (pendingQuery.docs.isNotEmpty) {
                              setSheetState(() {
                                isClaiming = false;
                                sheetError =
                                    'Your join request is already pending.';
                              });
                              return;
                            }

                            // Cache tourist name locally
                            final prefInstance =
                                await SharedPreferences.getInstance();
                            await prefInstance.setString(
                                'tourist_cached_name', name);

                            // 3. Create new join request under /tours/{tourId}/join_requests
                            final joinReqRef = FirebaseFirestore.instance
                                .collection('tours')
                                .doc(tourId)
                                .collection('join_requests')
                                .doc();

                            await joinReqRef.set({
                              'tourId': tourId,
                              'touristId': joinReqRef.id,
                              'touristName': name,
                              'contactNumber': '',
                              'emergencyContact': '',
                              'status': 'pending',
                              'createdAt': FieldValue.serverTimestamp(),
                            });

                            if (!rootContext.mounted) return;
                            navigator.pop(); // Close sheet

                            // Push to WaitingForApprovalScreen
                            Navigator.of(rootContext).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => WaitingForApprovalScreen(
                                  tourId: tourId,
                                  tourName: tourName,
                                  guideName: guideName,
                                  touristId: joinReqRef.id,
                                  touristName: name,
                                  accessCode: accessCode,
                                ),
                              ),
                            );
                          } catch (_) {
                            if (!rootContext.mounted) return;
                            setSheetState(() {
                              isClaiming = false;
                              sheetError =
                                  'Failed to submit join request. Please try again.';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isClaiming
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_forward_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Continue Join Request',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTermsAndConditions() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TermsAndConditionsScreen(
          onAccepted: () {
            // Pop the T&C screen, then navigate to the dashboard
            Navigator.of(context).pop();
            _navigateToDashboard();
          },
        ),
      ),
    );
  }

  void _navigateToDashboard() {
    // Save FCM token so the server can send push notifications to this tourist
    final session = TouristSessionManager.current;
    if (session != null) {
      NotificationService.saveTokenForTourist(
        session.sessionId,
        session.codeDocId,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text(AppStrings.touristLoginSuccess),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );

    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const TouristDashboardScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
      (route) => false,
    );
  }

  // ── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.getBackgroundGradient(context)),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      40,
                      24,
                      bottomInset > 0 ? bottomInset : 32,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildBackArrow(),
                        const SizedBox(height: 20),
                        _buildHeader(),
                        const SizedBox(height: 40),
                        if (_loginError != null) ...[
                          _buildErrorBanner(),
                          const SizedBox(height: 20),
                        ],
                        _buildForm(),
                        const SizedBox(height: 40),
                        _buildSubmitButton(),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Back Arrow ──────────────────────────────────────────

  Widget _buildBackArrow() {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.hiking_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          AppStrings.touristLoginTitle,
          style: Theme.of(context).textTheme.displayLarge,
        ),
        const SizedBox(height: 6),
        Text(
          AppStrings.touristLoginSubtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
      ],
    );
  }

  // ── Error Banner ────────────────────────────────────────

  Widget _buildErrorBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _loginError!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _loginError = null),
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.error.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ── Form ────────────────────────────────────────────────

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: CustomTextField(
        controller: _accessCodeCtrl,
        label: AppStrings.accessCodeLabel,
        hint: AppStrings.accessCodeHint,
        prefixIcon: Icons.qr_code_rounded,
        onPrefixIconTap: _onScanQr,
        prefixTooltip: 'Scan Tour Guide QR Code',
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.done,
        validator: _requiredValidator,
        onFieldSubmitted: (_) => _onSubmit(),
      ),
    );
  }

  // ── Submit Button ───────────────────────────────────────

  Widget _buildSubmitButton() {
    final isLocked = _lockoutStatus?.isLocked ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: (_isSubmitting || isLocked)
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
              ),
        color: isLocked ? AppColors.surfaceVariant : null,
        boxShadow: (_isSubmitting || isLocked)
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: (_isSubmitting || isLocked) ? null : _onSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.accent,
                ),
              )
            : isLocked
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_clock_rounded,
                          size: 20, color: AppColors.error),
                      const SizedBox(width: 8),
                      Text(
                        'Locked (${_lockoutStatus?.formattedRemainingTime})',
                        style: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.login_rounded, size: 22),
                      SizedBox(width: 10),
                      Text(AppStrings.joinTourButton),
                    ],
                  ),
      ),
    );
  }
}
