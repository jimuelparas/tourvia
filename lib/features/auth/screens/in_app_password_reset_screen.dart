import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'role_selection_screen.dart'; // To navigate back to login after success

class InAppPasswordResetScreen extends StatefulWidget {
  final String oobCode;

  const InAppPasswordResetScreen({
    super.key,
    required this.oobCode,
  });

  @override
  State<InAppPasswordResetScreen> createState() => _InAppPasswordResetScreenState();
}

class _InAppPasswordResetScreenState extends State<InAppPasswordResetScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _isSuccess = false;
  bool _isCodeValid = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _verifyCode();
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    try {
      // Verify that the code is valid before letting them type a password
      await FirebaseAuth.instance.verifyPasswordResetCode(widget.oobCode);
      if (mounted) {
        setState(() {
          _isCodeValid = true;
          _isLoading = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isCodeValid = false;
          _isLoading = false;
          if (e.code == 'expired-action-code') {
            _errorMessage = 'This password reset link has expired. Please request a new one from the app.';
          } else if (e.code == 'invalid-action-code') {
            _errorMessage = 'This password reset link is invalid or has already been used.';
          } else {
            _errorMessage = 'Unable to verify reset link: ${e.message}';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCodeValid = false;
          _isLoading = false;
          _errorMessage = 'An unexpected error occurred. Please try again.';
        });
      }
    }
  }

  Future<void> _submitNewPassword() async {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    setState(() {
      _errorMessage = null;
    });

    if (newPassword.length < 8) {
      setState(() {
        _errorMessage = 'Password must be at least 8 characters long.';
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await FirebaseAuth.instance.confirmPasswordReset(
        code: widget.oobCode,
        newPassword: newPassword,
      );
      if (mounted) {
        setState(() {
          _isSuccess = true;
          _isSubmitting = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.message ?? 'Failed to reset password.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'An unexpected error occurred.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Light gray background
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // Because they deep linked here, popping might just close the app, 
            // so we push replacement to login screen.
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
              (route) => false,
            );
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E3A8A), // Solid dark blue
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: const Center(
                      child: Text(
                        'TOURVIA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),

                  // Body
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: _buildBodyContent(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48.0),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
        ),
      );
    }

    if (_isSuccess) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Password Reset Successful!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your password has been successfully updated. You can now log in with your new password.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Color(0xFF4B5563), height: 1.5),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.login),
              label: const Text('Return to Login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      );
    }

    if (!_isCodeValid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Invalid Link',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'This link is invalid.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Color(0xFF4B5563), height: 1.5),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Return to App'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Set New Password',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
        ),
        const SizedBox(height: 16),
        const Text(
          'Please enter a new password for your account.',
          style: TextStyle(fontSize: 15, color: Color(0xFF4B5563), height: 1.5),
        ),
        const SizedBox(height: 24),
        
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red[800], fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        TextField(
          controller: _newPasswordController,
          obscureText: _obscureNew,
          decoration: InputDecoration(
            labelText: 'New Password',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            labelText: 'Confirm New Password',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ),
        
        const SizedBox(height: 32),

        // Main Call-to-Action
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: const Border(
              left: BorderSide(color: Color(0xFF1E3A8A), width: 4),
            ),
          ),
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitNewPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Reset Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
