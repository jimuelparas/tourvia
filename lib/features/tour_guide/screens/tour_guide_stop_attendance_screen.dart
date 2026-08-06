import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/attendance_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../attendance/models/tourist_attendance.dart';
import '../../itinerary/models/itinerary_item.dart' hide AttendanceStatus;

/// Full attendance sheet for a single itinerary stop (US-26).
///
/// Loads the session roster from Firestore and listens to per-stop
/// attendance records in real-time. Each status tap writes to Firestore
/// immediately — no "Save" button needed.
class TourGuideStopAttendanceScreen extends StatefulWidget {
  final ItineraryItem stop;
  final String sessionId;

  const TourGuideStopAttendanceScreen({
    super.key,
    required this.stop,
    this.sessionId = 'demo-session-001',
  });

  @override
  State<TourGuideStopAttendanceScreen> createState() =>
      _TourGuideStopAttendanceScreenState();
}

class _TourGuideStopAttendanceScreenState
    extends State<TourGuideStopAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Combined live state: roster + per-stop records
  List<TouristRecord> _roster = [];
  Map<String, AttendanceRecord> _records = {};

  StreamSubscription? _rosterSub;
  StreamSubscription? _recordsSub;

  // Tracks which tourist is currently being saved to show a spinner
  final Set<String> _savingIds = {};

  static const _tabs = ['All', 'Present', 'Late', 'Absent'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() => setState(() {}));

    // Subscribe to roster (all tourists who joined the session)
    _rosterSub = AttendanceService.watchRoster(widget.sessionId).listen((r) {
      if (mounted) setState(() => _roster = r);
    });

    // Subscribe to per-stop attendance records
    _recordsSub = AttendanceService.watchAttendance(
            widget.sessionId, widget.stop.id)
        .listen((recs) {
      if (mounted) setState(() => _records = recs);
    });
  }

  @override
  void dispose() {
    _rosterSub?.cancel();
    _recordsSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // ── Derived helpers ──────────────────────────────────────

  AttendanceStatus _statusFor(TouristRecord tourist) =>
      _records[tourist.codeDocId]?.status ?? AttendanceStatus.pending;

  String? _checkInTimeFor(TouristRecord tourist) {
    final dt = _records[tourist.codeDocId]?.checkInTime;
    if (dt == null) return null;
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  List<TouristRecord> get _filteredList {
    switch (_tabController.index) {
      case 1:
        return _roster
            .where((t) => _statusFor(t) == AttendanceStatus.present)
            .toList();
      case 2:
        return _roster
            .where((t) => _statusFor(t) == AttendanceStatus.absent)
            .toList();
      case 3:
        return _roster
            .where((t) => _statusFor(t) == AttendanceStatus.pending)
            .toList();
      default:
        return _roster;
    }
  }

  int get _presentCount =>
      _roster.where((t) => _statusFor(t) == AttendanceStatus.present).length;
  int get _lateCount =>
      _roster.where((t) => _statusFor(t) == AttendanceStatus.absent).length;
  int get _pendingCount =>
      _roster.where((t) => _statusFor(t) == AttendanceStatus.pending).length;

  // ── Actions ──────────────────────────────────────────────

  Future<void> _setStatus(TouristRecord tourist, AttendanceStatus status) async {
    if (_savingIds.contains(tourist.codeDocId)) return;
    setState(() => _savingIds.add(tourist.codeDocId));

    try {
      await AttendanceService.markAttendance(
        sessionId: widget.sessionId,
        stopId: widget.stop.id,
        touristId: tourist.codeDocId,
        touristName: tourist.touristName,
        touristCode: tourist.code,
        status: status,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingIds.remove(tourist.codeDocId));
    }
  }

  Future<void> _markAllPresent() async {
    final unmarked =
        _roster.where((t) => _statusFor(t) == AttendanceStatus.pending).toList();
    for (final t in unmarked) {
      await _setStatus(t, AttendanceStatus.present);
    }
  }

  // ── Color/icon helpers ───────────────────────────────────

  Color _statusColor(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present:
        return AppColors.success;
      case AttendanceStatus.absent:
        return AppColors.error;
      case AttendanceStatus.pending:
        return AppColors.textHint;
    }
  }

  IconData _statusIcon(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present:
        return Icons.check_circle_rounded;
      case AttendanceStatus.absent:
        return Icons.cancel_rounded;
      case AttendanceStatus.pending:
        return Icons.help_outline_rounded;
    }
  }

  String _statusLabel(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.pending:
        return 'Pending';
    }
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final total = _roster.length;
    final present = _presentCount;
    final late = _lateCount;
    final pending = _pendingCount;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(widget.stop.destinationName,
            overflow: TextOverflow.ellipsis),
        iconTheme: const IconThemeData(color: AppColors.primary),
        actions: [
          if (_pendingCount > 0)
            TextButton.icon(
              onPressed: _markAllPresent,
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Mark All Present'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          indicatorColor: AppColors.primary,
          isScrollable: true,
          tabs: [
            Tab(text: 'All ($total)'),
            Tab(text: 'Present ($present)'),
            Tab(text: 'Absent ($late)'),
            Tab(text: 'Pending ($pending)'),
          ],
        ),
      ),
      body: _roster.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                // ── Stats bar ───────────────────────────────────
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      _statCard(Icons.people_rounded, '$total', 'Total',
                          AppColors.primary),
                      const SizedBox(width: 10),
                      _statCard(Icons.check_circle_rounded, '$present',
                          'Present', AppColors.success),
                      const SizedBox(width: 10),
                      _statCard(Icons.cancel_rounded, '$late', 'Absent',
                          AppColors.error),
                      const SizedBox(width: 10),
                      _statCard(Icons.help_outline_rounded, '$pending',
                          'Pending', AppColors.textHint),
                    ],
                  ),
                ),
                // ── Progress bar ────────────────────────────────
                if (total > 0)
                  Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    height: 8,
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4)),
                    child: Row(
                      children: [
                        Flexible(
                          flex: present == 0 && late == 0 && pending == 0
                              ? 0
                              : present,
                          child: Container(color: AppColors.success),
                        ),
                        Flexible(
                          flex: late,
                          child: Container(color: AppColors.error),
                        ),
                        Flexible(
                          flex: pending == 0 && present == 0 && late == 0
                              ? 1
                              : pending,
                          child: Container(color: AppColors.border),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 1, color: AppColors.border),
                // ── List ────────────────────────────────────────
                Expanded(
                  child: _filteredList.isEmpty
                      ? Center(
                          child: Text(
                            'No tourists in this category.',
                            style: TextStyle(color: AppColors.textHint),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredList.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) =>
                              _touristCard(_filteredList[i]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline_rounded,
                  size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'No tourists have joined this session yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Share access codes so tourists can join.',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppColors.textHint, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
      IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _touristCard(TouristRecord tourist) {
    final status = _statusFor(tourist);
    final color = _statusColor(status);
    final checkIn = _checkInTimeFor(tourist);
    final isSaving = _savingIds.contains(tourist.codeDocId);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Text(
                tourist.touristName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color, fontSize: 16),
              ),
            ),
            const SizedBox(width: 14),
            // Name, code & status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tourist.touristName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(tourist.code,
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace')),
                      ),
                      const SizedBox(width: 8),
                      Icon(_statusIcon(status), size: 12, color: color),
                      const SizedBox(width: 4),
                      Text(
                        checkIn != null
                            ? '${_statusLabel(status)} · $checkIn'
                            : _statusLabel(status),
                        style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Status buttons or spinner
            isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _statusButton(AttendanceStatus.present, status, tourist,
                          Icons.check_rounded, AppColors.success),
                      const SizedBox(width: 6),
                      _statusButton(AttendanceStatus.absent, status, tourist,
                          Icons.close_rounded, AppColors.error),
                      const SizedBox(width: 6),
                      _statusButton(AttendanceStatus.pending, status, tourist,
                          Icons.help_outline_rounded, AppColors.textHint),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _statusButton(
    AttendanceStatus target,
    AttendanceStatus current,
    TouristRecord tourist,
    IconData icon,
    Color color,
  ) {
    final isSelected = current == target;
    return Tooltip(
      message: _statusLabel(target),
      child: GestureDetector(
        onTap: () => _setStatus(tourist, target),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isSelected ? color : color.withValues(alpha: 0.2)),
          ),
          child:
              Icon(icon, size: 16, color: isSelected ? Colors.white : color),
        ),
      ),
    );
  }
}
