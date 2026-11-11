import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:provider/provider.dart';

import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import 'login_screen.dart';

class OtpScreen extends StatefulWidget {
  /// Email address receiving the OTP.
  final String contact;

  /// True if this OTP is for a password reset flow
  final bool isPasswordReset;

  const OtpScreen({
    super.key,
    required this.contact,
    this.isPasswordReset = false,
  });

  // ── Legacy constructor support (email-only callers) ──────────────────────
  factory OtpScreen.email({
    required String email,
    bool isPasswordReset = false,
  }) {
    return OtpScreen(
      contact: email,
      isPasswordReset: isPasswordReset,
    );
  }

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with TickerProviderStateMixin {
  final _otpController = TextEditingController();

  String _currentOtp     = '';
  bool _isVerifying      = false;
  bool _isResending      = false;
  bool _blockAutoVerify  = false;
  bool _isVerified       = false;
  String? _errorMessage;
  String? _successMessage;

  static const int _resendSeconds = 60;
  int _countdown = _resendSeconds;
  Timer? _timer;

  late final AnimationController _shakeController;
  late final Animation<double>   _shakeAnim;
  late final AnimationController _fadeController;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _shakeController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8),  weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8),  weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -6),  weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 6),  weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: 0),   weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeController.dispose();
    _shakeController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ─── Countdown ──────────────────────────────────────────────────────────

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = _resendSeconds);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _countdown = 0);
      } else {
        if (mounted) setState(() => _countdown--);
      }
    });
  }

  // ─── Verify ─────────────────────────────────────────────────────────────

  Future<void> _handleVerify() async {
    if (_currentOtp.length < 6 || _isVerifying || _blockAutoVerify) return;

    FocusScope.of(context).unfocus();
    setState(() { _isVerifying = true; _errorMessage = null; _successMessage = null; });

    try {
      if (widget.isPasswordReset) {
        await context.read<AuthProvider>().verifyPasswordResetOtp(
          contact: widget.contact,
          otp: _currentOtp,
        );

        if (!mounted) return;
        setState(() => _successMessage = 'OTP verified! Redirecting...');
        await Future.delayed(const Duration(milliseconds: 1200));
        if (!mounted) return;

        Navigator.pop(context, _currentOtp);
      } else {
        await context.read<AuthProvider>().verifyOtp(otp: _currentOtp);

        if (!mounted) return;
        setState(() {
          _successMessage = 'Email verified successfully!';
          _isVerified = true;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _shakeController.forward(from: 0);
      setState(() {
        _errorMessage = e.message.contains('expired')
            ? 'OTP has expired. Please request a new one.'
            : (e.message.contains('invalid') || e.message.toLowerCase().contains('incorrect'))
                ? 'Incorrect OTP. Please try again.'
                : e.message;
        _currentOtp      = '';
        _blockAutoVerify = true;
      });
      _otpController.clear();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage    = 'Something went wrong. Please try again.';
        _currentOtp      = '';
        _blockAutoVerify = true;
      });
      _otpController.clear();
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  // ─── Resend ─────────────────────────────────────────────────────────────

  Future<void> _handleResend() async {
    if (_countdown > 0 || _isResending) return;

    setState(() { _isResending = true; _errorMessage = null; _successMessage = null; _blockAutoVerify = false; });

    try {
      if (widget.isPasswordReset) {
        await context.read<AuthProvider>().resendPasswordResetOtp(
          contact: widget.contact,
        );
      } else {
        await context.read<AuthProvider>().resendOtp();
      }

      if (!mounted) return;
      setState(() {
        _successMessage = 'New OTP sent to ${_maskContact(widget.contact)}.';
        _currentOtp     = '';
      });
      _otpController.clear();
      _startCountdown();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Could not resend OTP. Please try again.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  // ─── Mask contact for display ────────────────────────────────────────────

  String _maskContact(String contact) {
    // Email: angelo@gmail.com → an***@gmail.com
    final parts = contact.split('@');
    if (parts.length != 2) return contact;
    final name   = parts[0];
    final domain = parts[1];
    if (name.length <= 3) return '*${'*' * (name.length - 1)}@$domain';
    return '${name.substring(0, 2)}${'*' * (name.length - 2)}@$domain';
  }

  void _goToSignIn() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size      = MediaQuery.of(context).size;
    final isWide    = size.width >= 600;
    final isCompact = size.height < 680;

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: Text(
          widget.isPasswordReset ? 'Reset Password' : 'Verify Email',
          style: GoogleFonts.playfairDisplaySc(
            fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: isWide
              ? Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: _buildContent(context, isCompact),
                  ),
                )
              : _buildContent(context, isCompact),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isCompact) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        isCompact ? AppSpacing.md : AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: isCompact ? AppSpacing.lg : AppSpacing.xl),

          // ── Icon ──────────────────────────────────────────────────────
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            child: Icon(
              Icons.mail_outline_rounded,
              color: AppColors.gold,
              size: 36,
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          Text(
            widget.isPasswordReset ? 'Check your inbox' : 'One last step',
            style: AppTextStyles.display2(context),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.sm),

          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.karla(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              children: [
                TextSpan(
                  text: 'We sent a 6-digit code to\n',
                ),
                TextSpan(
                  text: _maskContact(widget.contact),
                  style: GoogleFonts.karla(
                    fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: isCompact ? AppSpacing.lg : AppSpacing.xl),

          if (_errorMessage != null) ...[
            StatusBanner(message: _errorMessage!, isError: true),
            const SizedBox(height: AppSpacing.md),
          ],

          if (_successMessage != null) ...[
            StatusBanner(message: _successMessage!, isError: false),
            const SizedBox(height: AppSpacing.md),
          ],

          if (_isVerifying) ...[
            const SizedBox(height: AppSpacing.sm),
            const SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          if (!_isVerified)
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) =>
                  Transform.translate(offset: Offset(_shakeAnim.value, 0), child: child),
              child: _buildOtpField(context),
            ),

          SizedBox(height: isCompact ? AppSpacing.lg : AppSpacing.xl),

          if (_isVerified) ...[
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(label: 'GO TO SIGN IN', onPressed: _goToSignIn),
          ] else ...[
            _buildResendSection(context),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Check your spam folder if you don\'t see it.',
              style: AppTextStyles.caption(context),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOtpField(BuildContext context) {
    return PinCodeTextField(
      appContext: context,
      length: 6,
      controller: _otpController,
      keyboardType: TextInputType.number,
      animationType: AnimationType.scale,
      animationDuration: const Duration(milliseconds: 150),
      enableActiveFill: true,
      autoFocus: true,
      enabled: !_isVerifying,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      pinTheme: PinTheme(
        shape: PinCodeFieldShape.box,
        borderRadius: BorderRadius.circular(AppRadius.md),
        fieldHeight: 56,
        fieldWidth: 46,
        activeFillColor:   AppColors.inputFill,
        inactiveFillColor: AppColors.inputFill,
        selectedFillColor: AppColors.surfaceWarm,
        activeColor:       AppColors.gold,
        inactiveColor:     AppColors.inputBorder,
        selectedColor:     AppColors.primary,
        borderWidth: 2,
        errorBorderColor:  AppColors.error,
      ),
      textStyle: GoogleFonts.playfairDisplaySc(
        fontSize: 22, fontWeight: FontWeight.w700,
        color: AppColors.primary, letterSpacing: 0,
      ),
      onChanged: (val) {
        setState(() {
          _currentOtp = val;
          if (_errorMessage != null)   _errorMessage   = null;
          if (_successMessage != null) _successMessage = null;
          if (_blockAutoVerify)        _blockAutoVerify = false;
        });
      },
      onCompleted: (_) {
        if (!_blockAutoVerify) _handleVerify();
      },
    );
  }

  Widget _buildResendSection(BuildContext context) {
    return Column(
      children: [
        Text('Didn\'t receive the code?', style: AppTextStyles.bodyMedium(context)),
        const SizedBox(height: AppSpacing.sm),

        _countdown > 0
            ? Text(
                'Resend in $_countdown s',
                style: GoogleFonts.karla(
                  fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500,
                ),
              )
            : GestureDetector(
                onTap: _isResending ? null : _handleResend,
                child: _isResending
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
                      )
                    : Text('Resend Code', style: AppTextStyles.link(context)),
              ),
      ],
    );
  }
}
