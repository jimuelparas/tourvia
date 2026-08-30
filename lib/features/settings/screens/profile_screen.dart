import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';

/// Profile screen allowing tour guides to view and edit their personal
/// information including photo, name, email, phone, address, and password.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameCtrl;
  late TextEditingController _middleNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _tourGuideId;
  String? _username;
  String? _profilePhotoUrl;
  Uint8List? _newPhotoBytes;

  // Password change
  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  // Delete account
  final _deletePasswordCtrl = TextEditingController();
  bool _obscureDeletePassword = true;
  bool _isDeleting = false;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController();
    _middleNameCtrl = TextEditingController();
    _lastNameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _addressCtrl = TextEditingController();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _deletePasswordCtrl.dispose();
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await AuthService.getProfile();
      if (!mounted) return;
      if (profile != null) {
        // Support both old (fullName) and new (firstName/lastName) formats
        if (profile['firstName'] != null) {
          _firstNameCtrl.text = profile['firstName'] as String? ?? '';
          _middleNameCtrl.text = profile['middleName'] as String? ?? '';
          _lastNameCtrl.text = profile['lastName'] as String? ?? '';
        } else {
          // Legacy fallback: put the full name into firstName
          _firstNameCtrl.text = profile['fullName'] as String? ?? '';
        }
        _emailCtrl.text = profile['email'] as String? ?? '';
        _phoneCtrl.text = profile['contactNumber'] as String? ?? '';
        _addressCtrl.text = profile['address'] as String? ?? '';
        _tourGuideId = profile['tourGuideId'] as String?;
        _username = profile['username'] as String?;
        _profilePhotoUrl = profile['profilePhotoUrl'] as String?;
      }
      setState(() => _isLoading = false);
      _fadeController.forward();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _fadeController.forward();
      _showSnackbar('Failed to load profile.', isError: true);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo'),
              onTap: () async {
                final img = await picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 80,
                );
                if (ctx.mounted) Navigator.pop(ctx, img);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                final img = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 512,
                  maxHeight: 512,
                  imageQuality: 80,
                );
                if (ctx.mounted) Navigator.pop(ctx, img);
              },
            ),
            if (_newPhotoBytes != null || _profilePhotoUrl != null)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: const Text('Remove Photo',
                    style: TextStyle(color: AppColors.error)),
                onTap: () {
                  setState(() {
                    _newPhotoBytes = null;
                    _profilePhotoUrl = null;
                  });
                  Navigator.pop(ctx, null);
                },
              ),
          ],
        ),
      ),
    );

    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _newPhotoBytes = bytes);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await AuthService.updateProfile(
        firstName: _firstNameCtrl.text,
        middleName: _middleNameCtrl.text,
        lastName: _lastNameCtrl.text,
        email: _emailCtrl.text,
        contactNumber: _phoneCtrl.text,
        address: _addressCtrl.text.isNotEmpty ? _addressCtrl.text : null,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnackbar('Profile updated successfully!');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnackbar(e.message ?? 'Failed to update profile.', isError: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnackbar('Failed to update profile.', isError: true);
    }
  }

  void _showChangePasswordDialog() {
    _currentPasswordCtrl.clear();
    _newPasswordCtrl.clear();
    _confirmPasswordCtrl.clear();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Text('Change Password'),
            ],
          ),
          content: Form(
            key: _passwordFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPasswordField(
                  controller: _currentPasswordCtrl,
                  label: 'Current Password',
                  obscure: _obscureCurrent,
                  onToggle: () =>
                      setDialogState(() => _obscureCurrent = !_obscureCurrent),
                  validator: (val) => val == null || val.isEmpty
                      ? 'Enter your current password'
                      : null,
                ),
                const SizedBox(height: 12),
                _buildPasswordField(
                  controller: _newPasswordCtrl,
                  label: 'New Password',
                  obscure: _obscureNew,
                  onToggle: () =>
                      setDialogState(() => _obscureNew = !_obscureNew),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Required';
                    if (val.length < 8) return 'Min. 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildPasswordField(
                  controller: _confirmPasswordCtrl,
                  label: 'Confirm New Password',
                  obscure: _obscureConfirm,
                  onToggle: () => setDialogState(
                      () => _obscureConfirm = !_obscureConfirm),
                  validator: (val) {
                    if (val != _newPasswordCtrl.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _changePassword(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePassword(BuildContext dialogContext) async {
    if (!_passwordFormKey.currentState!.validate()) return;

    Navigator.pop(dialogContext);

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await AuthService.updatePassword(
        currentPassword: _currentPasswordCtrl.text,
        newPassword: _newPasswordCtrl.text,
      );
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      _showSnackbar('Password changed successfully!');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      final msg = e.code == 'wrong-password' || e.code == 'invalid-credential'
          ? 'Current password is incorrect.'
          : e.message ?? 'Failed to change password.';
      _showSnackbar(msg, isError: true);
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      _showSnackbar('Failed to change password.', isError: true);
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('My Profile'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildAvatar(),
                    const SizedBox(height: 28),
                    _buildProfileForm(),
                    const SizedBox(height: 16),
                    _buildPasswordSection(),
                    const SizedBox(height: 16),
                    _buildDeleteAccountSection(),
                    const SizedBox(height: 28),
                    _buildSaveButton(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAvatar() {
    final hasPhoto = _newPhotoBytes != null || _profilePhotoUrl != null;

    return Center(
      child: GestureDetector(
        onTap: _pickPhoto,
        child: Stack(
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor: AppColors.surface,
                  backgroundImage: _newPhotoBytes != null
                      ? MemoryImage(_newPhotoBytes!)
                      : (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty
                          ? NetworkImage(_profilePhotoUrl!) as ImageProvider
                          : null),
                  child: !hasPhoto
                      ? Text(
                          _firstNameCtrl.text.isNotEmpty
                              ? _firstNameCtrl.text[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: AppColors.surface, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileForm() {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
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
            _buildSectionLabel('Personal Information'),
            const SizedBox(height: 14),

            // First Name
            _buildFormField(
              controller: _firstNameCtrl,
              label: 'First Name',
              icon: Icons.person_outline_rounded,
              validator: (val) =>
                  val == null || val.isEmpty ? 'First name is required' : null,
            ),
            const SizedBox(height: 14),

            // Middle Name
            _buildFormField(
              controller: _middleNameCtrl,
              label: 'Middle Name (Optional)',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 14),

            // Last Name
            _buildFormField(
              controller: _lastNameCtrl,
              label: 'Last Name',
              icon: Icons.person_outline_rounded,
              validator: (val) =>
                  val == null || val.isEmpty ? 'Last name is required' : null,
            ),
            const SizedBox(height: 14),

            // Email
            _buildFormField(
              controller: _emailCtrl,
              label: 'Email Address',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (val) {
                if (val == null || val.isEmpty) return 'Email is required';
                if (!val.contains('@') || !val.contains('.')) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Phone
            _buildFormField(
              controller: _phoneCtrl,
              label: 'Phone Number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (val) =>
                  val == null || val.isEmpty ? 'Phone is required' : null,
            ),
            const SizedBox(height: 14),

            // Address (optional)
            _buildFormField(
              controller: _addressCtrl,
              label: 'Address (Optional)',
              icon: Icons.location_on_outlined,
              maxLines: 2,
            ),

            // Username (read-only)
            if (_username != null && _username!.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildReadOnlyField(
                label: 'Username',
                value: _username!,
                icon: Icons.alternate_email_rounded,
              ),
            ],

            // Tour Guide ID (read-only)
            if (_tourGuideId != null && _tourGuideId!.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildReadOnlyField(
                label: 'DOT Tour Guide ID',
                value: _tourGuideId!,
                icon: Icons.badge_outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
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
          _buildSectionLabel('Security'),
          const SizedBox(height: 14),
          InkWell(
            onTap: _showChangePasswordDialog,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.lock_outline_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Change Password',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Update your account password',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textHint),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteAccountSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
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
          _buildSectionLabel('Danger Zone'),
          const SizedBox(height: 14),
          InkWell(
            onTap: _showDeleteAccountDialog,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_forever_rounded,
                        color: AppColors.error, size: 20),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delete Account',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.error,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Permanently delete your account and all data',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.error),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    _deletePasswordCtrl.clear();
    _obscureDeletePassword = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_rounded,
                    color: AppColors.error, size: 22),
              ),
              const SizedBox(width: 12),
              const Text('Delete Account',
                  style: TextStyle(color: AppColors.error)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This action is permanent and cannot be undone. All your data, sessions, and profile information will be permanently deleted.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Enter your password to confirm:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _deletePasswordCtrl,
                obscureText: _obscureDeletePassword,
                style: const TextStyle(fontSize: 14),
                cursorColor: AppColors.error,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                      size: 20, color: AppColors.textSecondary),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureDeletePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 20,
                      color: AppColors.textHint,
                    ),
                    onPressed: () => setDialogState(
                        () => _obscureDeletePassword = !_obscureDeletePassword),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.error, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _deleteAccount(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Delete My Account'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext dialogContext) async {
    if (_deletePasswordCtrl.text.isEmpty) {
      _showSnackbar('Please enter your password.', isError: true);
      return;
    }

    Navigator.pop(dialogContext);

    setState(() => _isDeleting = true);

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await AuthService.deleteAccount(password: _deletePasswordCtrl.text);
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      // Navigate to login screen and clear all routes
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      _showSnackbar('Account deleted successfully.');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      setState(() => _isDeleting = false);
      final msg = e.code == 'wrong-password' || e.code == 'invalid-credential'
          ? 'Incorrect password. Account was not deleted.'
          : e.message ?? 'Failed to delete account.';
      _showSnackbar(msg, isError: true);
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss loading
      setState(() => _isDeleting = false);
      _showSnackbar('Failed to delete account.', isError: true);
    }
  }

  Widget _buildSaveButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: _isSaving ? null : AppColors.primaryGradient,
        boxShadow: _isSaving
            ? []
            : [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveProfile,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              )
            : const Icon(Icons.save_rounded, size: 20),
        label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: AppColors.surfaceVariant,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 56),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────

  Widget _buildSectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
        filled: true,
        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textHint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_rounded, size: 14, color: AppColors.textHint),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded,
            size: 20, color: AppColors.textSecondary),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 20,
            color: AppColors.textHint,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }
}
