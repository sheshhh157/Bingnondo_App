import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import 'otp_screen.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // ─── Email form ──────────────────────────────────────────────────────────
  final _emailFormKey = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();

  bool _isLoading     = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  // ─── Submit: Email ───────────────────────────────────────────────────────

  Future<void> _handleEmailSubmit() async {
    if (!_emailFormKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final email = _emailCtrl.text.trim().toLowerCase();

      await context.read<AuthProvider>().forgotPassword(email: email);

      if (!mounted) return;

      // Navigate to OTP screen for password reset (email flow)
      final otpResult = await Navigator.push<String>(
        context,
        _slideRoute(
          OtpScreen(
            contact: email,
            isPasswordReset: true,
          ),
        ),
      );

      if (!mounted || otpResult == null) return;

      // OTP verified — go to reset password screen
      Navigator.pushReplacement(
        context,
        _slideRoute(
          ResetPasswordScreen(contact: email, otp: otpResult),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage =
          e.isNotFound ? 'No account found with that email address.' : e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  PageRouteBuilder<String> _slideRoute(Widget page) {
    return PageRouteBuilder<String>(
      pageBuilder: (_, anim, __) => page,
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: AppColors.textOnDark,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Forgot Password',
          style: GoogleFonts.playfairDisplaySc(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textOnDark,
          ),
        ),
      ),
      body: SafeArea(child: _buildEmailForm()),
    );
  }

  // ─── Email Tab ───────────────────────────────────────────────────────────

  Widget _buildEmailForm() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _emailFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.xl),

            // Icon
            Center(
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 2),
                ),
                child: const Icon(
                  Icons.mail_lock_outlined,
                  color: AppColors.gold,
                  size: 32,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            Text(
              'Reset via Email',
              style: AppTextStyles.display2(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              "Enter the email address linked to your account. We'll send you a 6-digit code.",
              style: AppTextStyles.bodyMedium(context),
            ),

            const SizedBox(height: AppSpacing.xl),

            if (_errorMessage != null) ...[
              StatusBanner(message: _errorMessage!, isError: true),
              const SizedBox(height: AppSpacing.md),
            ],

            AppTextField(
              label: 'Email Address',
              hint: 'you@example.com',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              prefixIcon: const Icon(
                Icons.mail_outline_rounded,
                size: 20,
                color: AppColors.gold,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required.';
                final reg = RegExp(
                  r'^[\w\.\-]+@[\w\-]+\.[a-z]{2,}$',
                  caseSensitive: false,
                );
                if (!reg.hasMatch(v.trim())) {
                  return 'Please enter a valid email address.';
                }
                return null;
              },
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
            ),

            const SizedBox(height: AppSpacing.xl),

            PrimaryButton(
              label: 'SEND RESET CODE',
              onPressed: _handleEmailSubmit,
              isLoading: _isLoading,
            ),

            const SizedBox(height: AppSpacing.lg),

            Center(
              child: Text(
                'Check your spam folder if you don\'t receive it.',
                style: AppTextStyles.caption(context),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
