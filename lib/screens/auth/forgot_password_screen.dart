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

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ─── Email form ──────────────────────────────────────────────────────────
  final _emailFormKey = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();

  // ─── Mobile form ─────────────────────────────────────────────────────────
  final _mobileFormKey = GlobalKey<FormState>();
  final _mobileCtrl    = TextEditingController();

  bool _isLoading     = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_errorMessage != null) setState(() => _errorMessage = null);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    super.dispose();
  }

  // ─── Validate PH mobile ──────────────────────────────────────────────────

  String? _validateMobile(String? v) {
    if (v == null || v.trim().isEmpty) return 'Mobile number is required.';
    final digits = v.trim().replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^09\d{9}$').hasMatch(digits)) {
      return 'Enter a valid PH number (09XXXXXXXXX).';
    }
    return null;
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
            isMobile: false,
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

  // ─── Submit: Mobile ──────────────────────────────────────────────────────

  Future<void> _handleMobileSubmit() async {
    if (!_mobileFormKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final mobile = _mobileCtrl.text.trim();

      await context.read<AuthProvider>().forgotPasswordMobile(
        mobileNumber: mobile,
      );

      if (!mounted) return;

      // Navigate to OTP screen for password reset (mobile flow)
      final otpResult = await Navigator.push<String>(
        context,
        _slideRoute(
          OtpScreen(
            contact: mobile,
            isMobile: true,
            isPasswordReset: true,
          ),
        ),
      );

      if (!mounted || otpResult == null) return;

      // OTP verified — go to reset password screen
      Navigator.pushReplacement(
        context,
        _slideRoute(
          ResetPasswordScreen(contact: mobile, otp: otpResult),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage =
          e.isNotFound ? 'No account found with that mobile number.' : e.message);
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.gold.withOpacity(0.3)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppColors.primaryDark,
                unselectedLabelColor: AppColors.textOnDark.withOpacity(0.7),
                labelStyle: GoogleFonts.karla(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: GoogleFonts.karla(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mail_outline_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Via Email'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phone_android_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Via Mobile'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildEmailForm(),
            _buildMobileForm(),
          ],
        ),
      ),
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

            if (_errorMessage != null && _tabController.index == 0) ...[
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

  // ─── Mobile Tab ──────────────────────────────────────────────────────────

  Widget _buildMobileForm() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _mobileFormKey,
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
                  Icons.phone_locked_outlined,
                  color: AppColors.gold,
                  size: 32,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            Text(
              'Reset via Mobile',
              style: AppTextStyles.display2(context),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              "Enter the mobile number linked to your account. We'll send a 6-digit SMS code.",
              style: AppTextStyles.bodyMedium(context),
            ),

            const SizedBox(height: AppSpacing.xl),

            if (_errorMessage != null && _tabController.index == 1) ...[
              StatusBanner(message: _errorMessage!, isError: true),
              const SizedBox(height: AppSpacing.md),
            ],

            AppTextField(
              label: 'Mobile Number',
              hint: '09XXXXXXXXX',
              controller: _mobileCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              prefixIcon: const Icon(
                Icons.phone_android_rounded,
                size: 20,
                color: AppColors.gold,
              ),
              extraFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 11,
              validator: _validateMobile,
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
            ),

            const SizedBox(height: AppSpacing.xl),

            PrimaryButton(
              label: 'SEND RESET CODE',
              onPressed: _handleMobileSubmit,
              isLoading: _isLoading,
            ),

            const SizedBox(height: AppSpacing.lg),

            Center(
              child: Text(
                'Make sure your number has signal and can receive SMS.',
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
