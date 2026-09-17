import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/philippine_locations_data.dart';
import '../../../core/services/itinerary_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/widgets/custom_text_field.dart';
import '../../itinerary/models/itinerary_item.dart';

/// Screen to add or edit an itinerary stop (US-07 / US-08).
///
/// Writes directly to Firestore via [ItineraryService] and returns
/// an [ItineraryItem] (or null if cancelled) to the caller.
class AddEditItineraryScreen extends StatefulWidget {
  final ItineraryItem? itemToEdit;

  /// Session or Tour ID used to write to the correct Firestore path.
  final String sessionId;
  final String? tourId;

  /// Optional tour start/end dates for date picker constraint.
  final DateTime? tourStartDate;
  final DateTime? tourEndDate;

  const AddEditItineraryScreen({
    super.key,
    this.itemToEdit,
    String? sessionId,
    String? tourId,
    this.tourStartDate,
    this.tourEndDate,
  })  : sessionId = sessionId ?? tourId ?? '',
        tourId = tourId ?? sessionId;

  @override
  State<AddEditItineraryScreen> createState() => _AddEditItineraryScreenState();
}

class _AddEditItineraryScreenState extends State<AddEditItineraryScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _destController;
  late TextEditingController _startController;
  late TextEditingController _endController;
  late TextEditingController _notesController;
  final TextEditingController _searchController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isSaving = false;
  bool _showSuggestions = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final item = widget.itemToEdit;
    if (item != null && item.effectiveStatus == ItineraryStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Completed destinations are read-only and cannot be edited.'),
              backgroundColor: AppColors.textSecondary,
            ),
          );
          Navigator.pop(context);
        }
      });
    }

    _destController = TextEditingController(text: item?.destinationName ?? '');
    _startController = TextEditingController(text: item?.startTime ?? '');
    _endController = TextEditingController(text: item?.endTime ?? '');
    _notesController = TextEditingController(text: item?.notes ?? '');
    if (item != null) {
      _selectedDate = item.date;
      if (item.startTime.isNotEmpty) {
        final startMins = ItineraryService.parseTimeToMinutes(item.startTime);
        _startTime = TimeOfDay(hour: startMins ~/ 60, minute: startMins % 60);
      }
      if (item.endTime.isNotEmpty) {
        final endMins = ItineraryService.parseTimeToMinutes(item.endTime);
        _endTime = TimeOfDay(hour: endMins ~/ 60, minute: endMins % 60);
      }
    } else {
      if (widget.tourStartDate != null) {
        _selectedDate = widget.tourStartDate!;
      }
      _loadNextAvailableSlot();
    }
  }

  Future<void> _loadNextAvailableSlot() async {
    try {
      final stops = await ItineraryService.getStops(widget.sessionId);
      if (stops.isNotEmpty) {
        // Find latest end time on the selected date
        final sameDayStops = stops.where((s) =>
            s.date.year == _selectedDate.year &&
            s.date.month == _selectedDate.month &&
            s.date.day == _selectedDate.day).toList();

        if (sameDayStops.isNotEmpty) {
          int latestEndMins = 0;
          for (final s in sameDayStops) {
            final eMins = ItineraryService.parseTimeToMinutes(s.endTime);
            if (eMins > latestEndMins) latestEndMins = eMins;
          }

          if (latestEndMins > 0 && latestEndMins < 23 * 60) {
            final nextStartHour = latestEndMins ~/ 60;
            final nextStartMinute = latestEndMins % 60;
            final nextEndHour = (nextStartHour + 1) % 24;

            final startTod = TimeOfDay(hour: nextStartHour, minute: nextStartMinute);
            final endTod = TimeOfDay(hour: nextEndHour, minute: nextStartMinute);

            if (mounted) {
              setState(() {
                _startTime = startTod;
                _endTime = endTod;
                _startController.text = _formatTimeOfDay(startTod);
                _endController.text = _formatTimeOfDay(endTod);
              });
            }
            return;
          }
        }
      }
    } catch (_) {}

    // Default 09:00 AM - 10:00 AM if no prior stops
    if (mounted && _startController.text.isEmpty) {
      const startTod = TimeOfDay(hour: 9, minute: 0);
      const endTod = TimeOfDay(hour: 10, minute: 0);
      setState(() {
        _startTime = startTod;
        _endTime = endTod;
        _startController.text = _formatTimeOfDay(startTod);
        _endController.text = _formatTimeOfDay(endTod);
      });
    }
  }

  @override
  void dispose() {
    _destController.dispose();
    _startController.dispose();
    _endController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart
        ? (_startTime ?? const TimeOfDay(hour: 9, minute: 0))
        : (_endTime ??
            (_startTime != null
                ? TimeOfDay(
                    hour: (_startTime!.hour + 1) % 24,
                    minute: _startTime!.minute,
                  )
                : const TimeOfDay(hour: 10, minute: 0)));

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked == null) return;

    if (isStart) {
      setState(() {
        _startTime = picked;
        _startController.text = _formatTimeOfDay(picked);

        // Auto-advance End Time if it is now earlier or equal to Start Time
        if (_endTime != null) {
          final sMins = picked.hour * 60 + picked.minute;
          final eMins = _endTime!.hour * 60 + _endTime!.minute;
          if (eMins <= sMins) {
            final adjustedEnd = TimeOfDay(
              hour: (picked.hour + 1) % 24,
              minute: picked.minute,
            );
            _endTime = adjustedEnd;
            _endController.text = _formatTimeOfDay(adjustedEnd);
          }
        }
      });
    } else {
      // End Time selected
      if (_startTime != null) {
        final sMins = _startTime!.hour * 60 + _startTime!.minute;
        final eMins = picked.hour * 60 + picked.minute;
        if (eMins <= sMins) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'End Time (${_formatTimeOfDay(picked)}) cannot be earlier than Start Time (${_formatTimeOfDay(_startTime!)}).',
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
          return;
        }
      }

      setState(() {
        _endTime = picked;
        _endController.text = _formatTimeOfDay(picked);
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final startStr = _startController.text.trim();
    final endStr = _endController.text.trim();

    // Validate chronological order: End Time > Start Time
    final startMins = ItineraryService.parseTimeToMinutes(startStr);
    final endMins = ItineraryService.parseTimeToMinutes(endStr);
    if (endMins <= startMins) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End Time must be later than Start Time.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Check for Time Slot Overlap against existing stops (REV-002 Section 7.2)
    final conflict = await ItineraryService.findTimeOverlap(
      widget.sessionId,
      _selectedDate,
      startStr,
      endStr,
      excludeStopId: widget.itemToEdit?.id,
    );

    if (conflict != null) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.event_busy_rounded, color: AppColors.error, size: 24),
              SizedBox(width: 10),
              Expanded(child: Text('Time Slot Conflict')),
            ],
          ),
          content: Text(
            'The selected time ($startStr – $endStr) overlaps with existing stop "${conflict.destinationName}" (${conflict.startTime} – ${conflict.endTime}).\n\nPlease choose a different time slot.',
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
              child: const Text('Adjust Time'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final item = ItineraryItem(
      id: widget.itemToEdit?.id ?? '',
      destinationName: _destController.text.trim(),
      date: _selectedDate,
      startTime: startStr,
      endTime: endStr,
      notes: _notesController.text.trim(),
      status: widget.itemToEdit?.status ?? ItineraryStatus.upcoming,
    );

    try {
      if (widget.itemToEdit == null) {
        // New stop — add to Firestore
        final newId = await ItineraryService.addStop(widget.sessionId, item);
        if (!mounted) return;
        Navigator.of(context)
            .pop(item.copyWith(id: newId)); // return with real Firestore ID
      } else {
        // Existing stop — update in Firestore
        await ItineraryService.updateStop(
            widget.sessionId, widget.itemToEdit!.id, item);
        if (!mounted) return;
        Navigator.of(context).pop(item);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.itemToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? AppStrings.editStopTitle : AppStrings.addStopTitle,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomTextField(
                  controller: _destController,
                  label: AppStrings.destNameLabel,
                  prefixIcon: Icons.place_rounded,
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),

                // ── Suggested Locations toggle ─────────────
                GestureDetector(
                  onTap: () => setState(
                      () => _showSuggestions = !_showSuggestions),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_outline_rounded,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Suggested Tourist Locations',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Icon(
                          _showSuggestions
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Suggestions panel ─────────────────────
                if (_showSuggestions) _buildSuggestionsPanel(),

                const SizedBox(height: 16),

                // Date Picker (Constrained to tour range)
                InkWell(
                  onTap: () async {
                    final first = widget.tourStartDate ?? DateTime(2020);
                    final last = widget.tourEndDate ?? DateTime(2030);
                    final initial = _selectedDate.isBefore(first)
                        ? first
                        : (_selectedDate.isAfter(last) ? last : _selectedDate);

                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: first,
                      lastDate: last,
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: AppColors.primary,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const Spacer(),
                        const Text(
                          'Select Date',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickTime(isStart: true),
                        child: IgnorePointer(
                          child: CustomTextField(
                            controller: _startController,
                            label: AppStrings.startTimeLabel,
                            hint: '09:00 AM',
                            prefixIcon: Icons.access_time_rounded,
                            validator: (val) =>
                                val == null || val.isEmpty ? 'Required' : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickTime(isStart: false),
                        child: IgnorePointer(
                          child: CustomTextField(
                            controller: _endController,
                            label: AppStrings.endTimeLabel,
                            hint: '10:30 AM',
                            prefixIcon: Icons.access_time_rounded,
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Required';
                              if (_startTime != null && _endTime != null) {
                                final sMins = _startTime!.hour * 60 + _startTime!.minute;
                                final eMins = _endTime!.hour * 60 + _endTime!.minute;
                                if (eMins <= sMins) {
                                  return 'Must be after Start Time';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  controller: _notesController,
                  label: AppStrings.notesLabel,
                  prefixIcon: Icons.notes_rounded,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 32),

                // Save button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: _isSaving
                        ? null
                        : AppColors.primaryGradient,
                    boxShadow: _isSaving
                        ? []
                        : [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: AppColors.surfaceVariant,
                      shadowColor: Colors.transparent,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.primary,
                            ),
                          )
                        : Text(
                            AppStrings.saveStopButton,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Location Suggestions Panel ────────────────────────────

  Widget _buildSuggestionsPanel() {
    final filtered = PhilippineLocationsData.search(_searchQuery);

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (value) =>
                    setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search city or attraction...',
                  hintStyle: const TextStyle(
                      fontSize: 13, color: AppColors.textHint),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 20, color: AppColors.textHint),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              size: 18, color: AppColors.textHint),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),

            // Results
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No matching locations found.',
                        style: TextStyle(
                          color: AppColors.textHint,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final city =
                            filtered.keys.elementAt(index);
                        final attractions = filtered[city]!;

                        return Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            // City section header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  14, 10, 14, 4),
                              child: Row(
                                children: [
                                  const Icon(
                                      Icons
                                          .location_city_rounded,
                                      size: 14,
                                      color:
                                          AppColors.primary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      city,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight:
                                            FontWeight.w700,
                                        color: AppColors
                                            .primary,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Attraction chips
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 10),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children:
                                    attractions.map((name) {
                                  return GestureDetector(
                                    onTap: () {
                                      _destController.text =
                                          name;
                                      setState(() {
                                        _showSuggestions =
                                            false;
                                        _searchQuery = '';
                                        _searchController
                                            .clear();
                                      });
                                    },
                                    child: Container(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration:
                                          BoxDecoration(
                                        color: AppColors
                                            .background,
                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                                    8),
                                        border: Border.all(
                                          color: AppColors
                                              .border,
                                        ),
                                      ),
                                      child: Text(
                                        name,
                                        style:
                                            const TextStyle(
                                          fontSize: 12,
                                          color: AppColors
                                              .textPrimary,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
