import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/access_code_service.dart';
import '../../../core/theme/app_colors.dart';

/// Screen where the Tour Guide generates individual access codes,
/// one code per tourist. Tourist names are set by tourists themselves
/// when they log in. Guide can only CLEAR a name to reset a code slot.
///
/// Data is now fully backed by Firestore via [AccessCodeService].
/// [sessionId] must be passed in from the dashboard (currently using
/// a placeholder until the full session management feature is wired up).
class TourGuideAccessLogScreen extends StatefulWidget {
  /// The Firestore tour session document ID.
  /// TODO: Replace with the active session ID from session management (Step 4+).
  final String sessionId;

  const TourGuideAccessLogScreen({
    super.key,
    required this.sessionId,
  });

  @override
  State<TourGuideAccessLogScreen> createState() =>
      _TourGuideAccessLogScreenState();
}

class _TourGuideAccessLogScreenState extends State<TourGuideAccessLogScreen> {
  bool _isGenerating = false;

  // ── Code Generation ─────────────────────────────────────

  void _showGenerateDialog() {
    int count = 1;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('Generate Access Codes'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'How many access codes would you like to generate?',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Stepper control
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Minus button
                        IconButton(
                          onPressed: count > 1
                              ? () => setDialogState(() => count--)
                              : null,
                          icon: const Icon(Icons.remove_rounded),
                          color: AppColors.primary,
                          disabledColor: AppColors.textHint,
                        ),
                        // Count display
                        Column(
                          children: [
                            Text(
                              '$count',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              count == 1 ? 'code' : 'codes',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        // Plus button
                        IconButton(
                          onPressed: count < 50
                              ? () => setDialogState(() => count++)
                              : null,
                          icon: const Icon(Icons.add_rounded),
                          color: AppColors.primary,
                          disabledColor: AppColors.textHint,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Quick select chips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [5, 10, 20].map((n) {
                      final isSelected = count == n;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () => setDialogState(() => count = n),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              '$n',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _generateCodes(count);
                  },
                  icon: const Icon(Icons.confirmation_number_rounded, size: 18),
                  label: Text('Generate $count'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generateCodes(int count) async {
    setState(() => _isGenerating = true);
    try {
      await AccessCodeService.generateCodes(
        sessionId: widget.sessionId,
        count: count,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '$count ${count == 1 ? 'code' : 'codes'} generated successfully'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to generate codes. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _deleteCode(String codeDocId, String codeValue) async {
    try {
      await AccessCodeService.deleteCode(
        sessionId: widget.sessionId,
        codeDocId: codeDocId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed code $codeValue'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete code.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.codeCopiedMsg),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Guide can ONLY clear (reset) a name — they cannot set it.
  void _confirmClearName(
      String codeDocId, String codeValue, String touristName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Tourist Name?'),
        content: Text(
          'Remove "$touristName" from code $codeValue?\n\n'
          'The code will be available for a new tourist to claim.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await AccessCodeService.clearTouristName(
                  sessionId: widget.sessionId,
                  codeDocId: codeDocId,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cleared name from $codeValue'),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to clear name.'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Clear Name'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      String codeDocId, String codeValue, bool isJoined,
      String? touristName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Code?'),
        content: Text(
          'Remove code "$codeValue"'
          '${isJoined ? ' currently held by $touristName' : ''}?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteCode(codeDocId, codeValue);
    }
  }

  // ── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tourist Access Codes'),
        backgroundColor: AppColors.surface,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppColors.primary),
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: AccessCodeService.watchCodes(widget.sessionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading codes: ${snapshot.error}',
                style: const TextStyle(color: AppColors.error),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final assigned =
              docs.where((d) => (d['touristName'] as String?) != null).length;
          final unassigned = docs.length - assigned;

          return Column(
            children: [
              // ── Stats bar ────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                color: AppColors.surface,
                child: Row(
                  children: [
                    _statChip(
                      Icons.confirmation_number_rounded,
                      '${docs.length}',
                      'Total Codes',
                      AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    _statChip(
                      Icons.person_rounded,
                      '$assigned',
                      'Joined',
                      AppColors.success,
                    ),
                    const SizedBox(width: 12),
                    _statChip(
                      Icons.hourglass_empty_rounded,
                      '$unassigned',
                      'Waiting',
                      const Color(0xFFF59E0B),
                    ),
                  ],
                ),
              ),
              // ── Info banner ──────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                color: AppColors.primarySurface,
                child: Row(
                  children: const [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tourist names are set when they log in with the code. '
                        'You can only clear a name to reset a slot.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),

              // ── Generating spinner overlay ───────────────
              if (_isGenerating)
                const LinearProgressIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.primarySurface,
                ),

              // ── Code list ────────────────────────────────
              Expanded(
                child: docs.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, index) =>
                            _buildCodeCard(docs[index]),
                      ),
              ),
            ],
          );
        },
      ),

      // ── FAB: Generate new code ───────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isGenerating ? null : _showGenerateDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: _isGenerating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.add_rounded),
        label: const Text('Generate Code',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final codeDocId = doc.id;
    final codeValue = data['code'] as String? ?? codeDocId;
    final touristName = data['touristName'] as String?;
    final isJoined = touristName != null && touristName.isNotEmpty;
    final createdAt = data['createdAt'] as Timestamp?;
    final timeLabel = createdAt != null
        ? _formatTimestamp(createdAt)
        : 'Generating...';

    return Dismissible(
      key: Key(codeDocId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: AppColors.error, size: 28),
            SizedBox(height: 4),
            Text('Delete',
                style: TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await _confirmDelete(codeDocId, codeValue, isJoined, touristName);
        return false; // We handle deletion ourselves above
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isJoined
                ? AppColors.success.withValues(alpha: 0.3)
                : AppColors.border,
          ),
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
            // ── Code row ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isJoined
                          ? AppColors.success
                          : const Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      codeValue,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyCode(codeValue),
                    icon: const Icon(Icons.copy_rounded,
                        size: 20, color: AppColors.textHint),
                    tooltip: 'Copy Code',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            // ── Tourist name row ──────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isJoined
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.primarySurface,
                    child: isJoined
                        ? Text(
                            touristName!.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                              fontSize: 15,
                            ),
                          )
                        : const Icon(Icons.person_rounded,
                            size: 18, color: AppColors.textHint),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isJoined ? touristName! : 'Waiting for tourist...',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: isJoined
                                ? AppColors.textPrimary
                                : AppColors.textHint,
                          ),
                        ),
                        Text(
                          'Generated at $timeLabel',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Only show CLEAR button if tourist has already joined
                  if (isJoined)
                    GestureDetector(
                      onTap: () =>
                          _confirmClearName(codeDocId, codeValue, touristName!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_remove_rounded,
                                size: 14, color: AppColors.error),
                            SizedBox(width: 4),
                            Text(
                              'Clear',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.confirmation_number_outlined,
              size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Text(
            'No access codes yet.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap "Generate Code" to create\na code for each tourist.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textHint),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showGenerateDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Generate Codes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp ts) {
    final dt = ts.toDate().toLocal();
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}
