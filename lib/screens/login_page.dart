import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/catalog_firebase.dart';
import '../firebase/user_profile.dart';
import '../shared/theme/app_colors.dart';
import '../shared/theme/app_text_styles.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isGoogleLoading = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  String _phoneNumber = '';
  String _verificationId = '';
  final TextEditingController _otpController = TextEditingController();

  FirebaseAuth get _catalogAuth => catalogAuth;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _promptForNameIfNeeded() async {
    final user = _catalogAuth.currentUser;
    if (user == null) return;
    final docRef = catalogFirestore.collection('users').doc(user.uid);
    final doc = await docRef.get();
    final data = doc.data();
    final name = (data != null && data['name'] is String) ? (data['name'] as String) : '';
    if (name.trim().isNotEmpty) return;
    // show a dedicated stateful dialog that manages its own controller/state
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _NamePromptDialog(docRef: docRef),
    );
    return;
  }
  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      final googleUser = await GoogleSignIn.instance.authenticate();
      final idToken = googleUser.authentication.idToken;
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await _catalogAuth.signInWithCredential(credential);
      await ensureUserProfileExists();
      if (context.mounted) Navigator.pop(context, true);
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Google sign-in failed: ${e.description}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _sendOtp() async {
    final cleaned = _phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid 10-digit phone number')));
      return;
    }

    final phone = '+91$cleaned';
    setState(() => _isSendingOtp = true);

    try {
      await _catalogAuth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-sign in (Android)
          try {
            await _catalogAuth.signInWithCredential(credential);
            await ensureUserProfileExists();
            if (mounted) {
              await _promptForNameIfNeeded();
              if (mounted) Navigator.pop(context, true);
            }
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auto sign-in failed: $e')));
          }
        },
        verificationFailed: (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification failed: ${e.message}')));
        },
        codeSent: (verificationId, resendToken) {
          setState(() {
            _verificationId = verificationId;
          });
        },
        codeAutoRetrievalTimeout: (verificationId) {
          setState(() {
            _verificationId = verificationId;
          });
        },
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send OTP: $e')));
    } finally {
      if (mounted) setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_verificationId.isEmpty) return;
    final code = _otpController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the 6-digit code')));
      return;
    }

    setState(() => _isVerifyingOtp = true);
    try {
      final credential = PhoneAuthProvider.credential(verificationId: _verificationId, smsCode: code);
      await _catalogAuth.signInWithCredential(credential);
      await ensureUserProfileExists();
      if (mounted) {
        await _promptForNameIfNeeded();
        if (mounted) Navigator.pop(context, true);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('OTP verification failed: ${e.message}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('OTP verification failed: $e')));
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final otpSent = _verificationId.isNotEmpty;

    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.lg,
                AppSpacing.screenGutter,
                AppSpacing.xxl,
              ),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'Skip',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  height: 56,
                  width: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.onPrimarySoft,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Sign in to continue', style: AppTextStyles.h1),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  otpSent
                      ? 'Enter the 6-digit code we sent to your phone.'
                      : 'Track orders, save devices and get paid faster.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                if (!otpSent) ..._buildPhoneStep() else ..._buildOtpStep(),
                const SizedBox(height: AppSpacing.xxl),
                _buildDivider(),
                const SizedBox(height: AppSpacing.xl),
                OutlinedButton.icon(
                  onPressed: _isGoogleLoading ? null : _signInWithGoogle,
                  icon: _isGoogleLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.g_mobiledata_rounded, size: 26),
                  label: Text(
                    'Continue with Google',
                    style: AppTextStyles.button.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'By continuing you agree to our Terms of Service and '
                  'Privacy Policy.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPhoneStep() {
    return [
      Text('Phone number', style: AppTextStyles.label),
      const SizedBox(height: AppSpacing.sm),
      TextField(
        keyboardType: TextInputType.phone,
        maxLength: 10,
        style: AppTextStyles.body,
        onChanged: (v) => setState(() => _phoneNumber = v),
        decoration: InputDecoration(
          hintText: '10-digit mobile number',
          counterText: '',
          prefixIcon: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.sm,
            ),
            child: Text('+91', style: AppTextStyles.bodyMedium),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      AppPrimaryButton(
        label: 'Send code',
        loading: _isSendingOtp,
        onPressed: _isSendingOtp ? null : _sendOtp,
      ),
    ];
  }

  List<Widget> _buildOtpStep() {
    return [
      Text('Verification code', style: AppTextStyles.label),
      const SizedBox(height: AppSpacing.sm),
      TextField(
        controller: _otpController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        style: AppTextStyles.h3,
        decoration: const InputDecoration(
          hintText: '000000',
          counterText: '',
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      AppPrimaryButton(
        label: 'Verify & continue',
        loading: _isVerifyingOtp,
        onPressed: _isVerifyingOtp ? null : _verifyOtp,
      ),
      const SizedBox(height: AppSpacing.sm),
      TextButton(
        onPressed: _isSendingOtp ? null : _sendOtp,
        child: Text(
          'Resend code',
          style: AppTextStyles.label.copyWith(color: AppColors.primary),
        ),
      ),
    ];
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(
          child: Divider(height: 1, thickness: 1, color: AppColors.border),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text('or', style: AppTextStyles.caption),
        ),
        const Expanded(
          child: Divider(height: 1, thickness: 1, color: AppColors.border),
        ),
      ],
    );
  }
}

class _NamePromptDialog extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> docRef;

  const _NamePromptDialog({required this.docRef});

  @override
  State<_NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends State<_NamePromptDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _controller.text.trim().isEmpty;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      title: Text("What's your name?", style: AppTextStyles.h3),
      content: TextField(
        controller: _controller,
        style: AppTextStyles.body,
        decoration: const InputDecoration(hintText: 'Enter your name'),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: AppTextStyles.label.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        AppPrimaryButton(
          label: 'Continue',
          expand: false,
          onPressed: isEmpty
              ? null
              : () async {
                  try {
                    await widget.docRef.update({'name': _controller.text.trim()});
                    if (mounted) Navigator.pop(context, true);
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save name: $e')));
                  }
                },
        ),
      ],
    );
  }
}
