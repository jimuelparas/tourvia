import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/tour_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/tour_service.dart';
import '../../../core/theme/app_colors.dart';
import 'tour_hub_screen.dart';
import 'tour_guide_itinerary_screen.dart';

/// Screen for creating a new tour (REV-002 Section 3).
///
/// Collects Tour Name, Start Date, End Date, computed Days, and Schedule.
/// Automatically runs date overlap/conflict checks before saving.
/// On save, auto-generates a unique 6-character Access Code.
class CreateTourScreen extends StatefulWidget {
  final Tour? tourToEdit;
  const CreateTourScreen({super.key, this.tourToEdit});

  @override
  State<CreateTourScreen> createState() => _CreateTourScreenState();
}

class _CreateTourScreenState extends State<CreateTourScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _scheduleCtrl = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  int _totalDays = 1;

  bool _isCheckingConflict = false;
  Tour? _scheduleConflict;
  bool _isSubmitting = false;

  bool get _isEditing => widget.tourToEdit != null;

  @override
  void initState() {
    super.initState();
    if (widget.tourToEdit != null) {
      final t = widget.tourToEdit!;
      _nameCtrl.text = t.name;
      _scheduleCtrl.text = t.schedule;
      _startDate = t.startDate.toLocal();
      _endDate = t.endDate.toLocal();
      _totalDays = t.totalDays;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _scheduleCtrl.dispose();
    super.dispose();
  }

  // ── Date Pickers & Auto Calculation ──────────────────────

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final initial = _startDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      helpText: 'Select Tour Start Date',
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate == null || _endDate!.isBefore(_startDate!)) {
          _endDate = _startDate;
        }
        _calculateDays();
      });
      await _checkConflict();
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final first = _startDate ?? DateTime(now.year, now.month, now.day);
    final initial = (_endDate != null && !_endDate!.isBefore(first)) ? _endDate! : first;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(now.year + 5),
      helpText: 'Select Tour End Date',
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
        _calculateDays();
      });
      await _checkConflict();
    }
  }

  void _calculateDays() {
    if (_startDate != null && _endDate != null) {
      final s = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      final e = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
      _totalDays = (e.difference(s).inDays + 1).clamp(1, 365);
    }
  }

  // ── Conflict Check ───────────────────────────────────────

  Future<void> _checkConflict() async {
    if (_startDate == null || _endDate == null) return;
    final guideId = AuthService.currentUser?.uid;
    if (guideId == null) return;

    setState(() => _isCheckingConflict = true);
    final conflict = await TourService.findScheduleConflict(
      guideId: guideId,
      startDate: _startDate!,
      endDate: _endDate!,
      excludeTourId: widget.tourToEdit?.id,
    );

    if (!mounted) return;
    setState(() {
      _isCheckingConflict = false;
      _scheduleConflict = conflict;
    });
  }

  // ── Submit ──────────────────────────────────────────────

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both Start Date and End Date.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_scheduleConflict != null) {
      _showConflictDialog(_scheduleConflict!);
      return;
    }

    final guide = AuthService.currentUser;
    if (guide == null) return;

    setState(() => _isSubmitting = true);

    try {
      if (_isEditing) {
        final updated = widget.tourToEdit!.copyWith(
          name: _nameCtrl.text.trim(),
          startDate: _startDate!,
          endDate: _endDate!,
          totalDays: _totalDays,
          schedule: _scheduleCtrl.text.trim(),
        );

        await TourService.updateTour(updated);

        if (!mounted) return;
        setState(() => _isSubmitting = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tour "${updated.name}" updated successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
        return;
      }

      final tour = await TourService.createTour(
        name: _nameCtrl.text.trim(),
        startDate: _startDate!,
        endDate: _endDate!,
        totalDays: _totalDays,
        schedule: _scheduleCtrl.text.trim(),
        guideId: guide.uid,
        guideName: guide.displayName ?? 'Tour Guide',
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      _showSuccessDialog(tour);
    } on TourConflictException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (e.conflictingTour != null) {
        _showConflictDialog(e.conflictingTour!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create tour: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  void _showConflictDialog(Tour conflict) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_busy_rounded, color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Schedule Conflict')),
          ],
        ),
        content: Text(
          'You already have an existing tour "${conflict.name}" scheduled from ${conflict.formattedDateRange}.\n\nPlease adjust the dates so tours do not overlap.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Adjust Dates'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(Tour tour) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded,
                  color: AppColors.success, size: 26),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Tour Created!')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${tour.name} has been scheduled successfully.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Unique Tour Access Code',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tour.accessCode,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: tour.accessCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Access Code "${tour.accessCode}" copied to clipboard!'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy Access Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx); // close dialog
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TourHubScreen(
                          tourId: tour.id,
                          initialTour: tour,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Manage Tour'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx); // close dialog
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TourGuideItineraryScreen(
                          tourId: tour.id,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_location_alt_rounded, size: 16),
                  label: const Text('Add Itinerary'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Build UI ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Tour' : 'Create Tour'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildTourNameField(),
                const SizedBox(height: 18),
                _buildDateRangeSelectors(),
                const SizedBox(height: 14),
                _buildDurationBadge(),
                if (_isCheckingConflict) ...[
                  const SizedBox(height: 14),
                  const LinearProgressIndicator(minHeight: 3),
                ] else if (_scheduleConflict != null) ...[
                  const SizedBox(height: 14),
                  _buildConflictBanner(),
                ],
                const SizedBox(height: 18),
                _buildScheduleField(),
                const SizedBox(height: 30),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isEditing ? 'Edit Tour Details' : 'Pre-Plan Tour',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          _isEditing
              ? 'Update the tour name or schedule dates. The access code, itinerary, and tourists remain unchanged.'
              : 'Schedule a new tour in advance. The system will automatically generate an access code and prevent date conflicts.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }

  Widget _buildTourNameField() {
    return TextFormField(
      controller: _nameCtrl,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: 'Tour Name',
        hintText: 'e.g. Coron Island Expedition',
        prefixIcon: const Icon(Icons.tour_outlined, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.6),
      ),
      validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter a tour name' : null,
    );
  }

  Widget _buildDateRangeSelectors() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _pickStartDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _startDate != null
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Start Date',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _startDate != null
                              ? '${_startDate!.month}/${_startDate!.day}/${_startDate!.year}'
                              : 'Select',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: _startDate != null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: _pickEndDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _endDate != null
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('End Date',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.event_available_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _endDate != null
                              ? '${_endDate!.month}/${_endDate!.day}/${_endDate!.year}'
                              : 'Select',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: _endDate != null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.timelapse_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            'Duration: $_totalDays ${_totalDays == 1 ? 'Day' : 'Days'}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Schedule Conflict Detected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Overlaps with "${_scheduleConflict!.name}" (${_scheduleConflict!.formattedDateRange}). Please select different dates.',
                  style: const TextStyle(fontSize: 11, color: AppColors.error, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleField() {
    return TextFormField(
      controller: _scheduleCtrl,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: 'Tour Schedule & Description',
        hintText: 'Provide general itinerary briefing, timetable, or meeting guidelines...',
        alignLabelWithHint: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final hasConflict = _scheduleConflict != null;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: (_isSubmitting || hasConflict) ? null : _onSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Text(
                _isEditing ? 'Save Changes' : 'Save & Create Tour',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
