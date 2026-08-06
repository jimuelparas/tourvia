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

  /// Session ID used to write to the correct Firestore path.
  final String sessionId;

  const AddEditItineraryScreen({
    super.key,
    this.itemToEdit,
    required this.sessionId,
  });

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
  bool _isSaving = false;
  bool _showSuggestions = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final item = widget.itemToEdit;
    _destController = TextEditingController(text: item?.destinationName ?? '');
    _startController = TextEditingController(text: item?.startTime ?? '');
    _endController = TextEditingController(text: item?.endTime ?? '');
    _notesController = TextEditingController(text: item?.notes ?? '');
    if (item != null) _selectedDate = item.date;
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final item = ItineraryItem(
      id: widget.itemToEdit?.id ?? '',
      destinationName: _destController.text.trim(),
      date: _selectedDate,
      startTime: _startController.text.trim(),
      endTime: _endController.text.trim(),
      notes: _notesController.text.trim(),
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
          margin: const EdgeInsets.all(16),
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
        leading: const BackButton(),
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

                // Date Picker
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
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
                          color: AppColors.textHint,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _startController,
                        label: AppStrings.startTimeLabel,
                        hint: '09:00 AM',
                        prefixIcon: Icons.access_time_rounded,
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CustomTextField(
                        controller: _endController,
                        label: AppStrings.endTimeLabel,
                        hint: '10:30 AM',
                        prefixIcon: Icons.access_time_rounded,
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Required' : null,
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
