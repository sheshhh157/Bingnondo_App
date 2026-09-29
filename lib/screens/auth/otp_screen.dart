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

class OtpScreen extends StatefulWidget {
  final String email;
  final bool isPasswordReset;

  const OtpScreen({
    super.key,
    required this.email,
    this.isPasswordReset = false,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with TickerProviderStateMixin {
  final _otpController = TextEditingController();
  String _currentOtp = '';

  bool _isVerifying = false;
  bool _isResending = false;
  bool _blockAutoVerify = false;
  String? _errorMessage;
  String? _successMessage;

  static const int _resendSeconds = 60;
  int _countdown = _resendSeconds;
  Timer? _timer;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnim;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: 0), weight: 1),
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

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        t.cancel();
        if (mounted) setState(() => _countdown = 0);
      } else {
        if (mounted) setState(() => _countdown--);
      }
    });
  }

  Future<void> _handleVerify() async {
    if (_currentOtp.length < 6 || _isVerifying || _blockAutoVerify) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      if (widget.isPasswordReset) {
        await context.read<AuthProvider>().verifyPasswordResetOtp(
          email: widget.email,
          otp: _currentOtp,
        );
        if (!mounted) return;

        // ✅ Tama — may success message, babalik sa sign in
        setState(() {
          _successMessage = 'OTP verified! Redirecting...';
        });
        await Future.delayed(const Duration(milliseconds: 1200));
        if (!mounted) return;
        Navigator.pop(context, _currentOtp);
      } else {
        await context.read<AuthProvider>().verifyOtp(otp: _currentOtp);
        if (!mounted) return;

        // ✅ Tama — may success message, babalik sa sign in page
        setState(() {
          _successMessage = 'Email verified! Please sign in to continue.';
        });
        await Future.delayed(const Duration(milliseconds: 1500));
        if (!mounted) return;

        // Balik sa sign in — pop lahat hanggang sa first route (sign in screen)
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _shakeController.forward(from: 0);
      setState(() {
        _errorMessage = e.message.contains('expired')
            ? 'OTP has expired. Please request a new one.'
            : e.message.contains('invalid') ||
            e.message.contains('incorrect') ||
            e.message.contains('Incorrect')
            ? 'Incorrect OTP. Please try again.'
            : e.message;
        _currentOtp = '';
        _blockAutoVerify = true;
      });
      _otpController.clear();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
        _currentOtp = '';
        _blockAutoVerify = true;
      });
      _otpController.clear();
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _handleResend() async {
    if (_countdown > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
      _successMessage = null;
      _blockAutoVerify = false;
    });

    try {
      await context.read<AuthProvider>().resendOtp();
      if (!mounted) return;
      setState(() {
        _successMessage = 'New OTP sent to ${_maskEmail(widget.email)}.';
        _currentOtp = '';
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

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 3) return '*${'*' * (name.length - 1)}@$domain';
    return '${name.substring(0, 2)}${'*' * (name.length - 2)}@$domain';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 600;
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
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
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

          Text(
            widget.isPasswordReset ? 'Check your inbox' : 'One last step',
            style: AppTextStyles.display2(context),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.sm),

          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.karla(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              children: [
                const TextSpan(text: 'We sent a 6-digit code to\n'),
                TextSpan(
                  text: _maskEmail(widget.email),
                  style: GoogleFonts.karla(
                    fontSize: 14,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: isCompact ? AppSpacing.lg : AppSpacing.xl),

          // Status banners
          if (_errorMessage != null) ...[
            StatusBanner(message: _errorMessage!, isError: true),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_successMessage != null) ...[
            StatusBanner(message: _successMessage!, isError: false),
            const SizedBox(height: AppSpacing.md),
          ],

          // Loading indicator kapag nag-veverify
          if (_isVerifying) ...[
            const SizedBox(height: AppSpacing.sm),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // OTP Input
          AnimatedBuilder(
            animation: _shakeAnim,
            builder: (_, child) => Transform.translate(
              offset: Offset(_shakeAnim.value, 0),
              child: child,
            ),
            child: _buildOtpField(context),
          ),

          SizedBox(height: isCompact ? AppSpacing.lg : AppSpacing.xl),

          // Resend section
          _buildResendSection(context),

          const SizedBox(height: AppSpacing.xl),

          Text(
            'Check your spam folder if you don\'t see it.',
            style: AppTextStyles.caption(context),
            textAlign: TextAlign.center,
          ),
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
      enabled: !_isVerifying, // Hindi na pwedeng mag-type habang nag-veverify
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      pinTheme: PinTheme(
        shape: PinCodeFieldShape.box,
        borderRadius: BorderRadius.circular(AppRadius.md),
        fieldHeight: 56,
        fieldWidth: 46,
        activeFillColor: AppColors.inputFill,
        inactiveFillColor: AppColors.inputFill,
        selectedFillColor: AppColors.surfaceWarm,
        activeColor: AppColors.gold,
        inactiveColor: AppColors.inputBorder,
        selectedColor: AppColors.primary,
        borderWidth: 2,
        errorBorderColor: AppColors.error,
      ),
      textStyle: GoogleFonts.playfairDisplaySc(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
        letterSpacing: 0,
      ),
      onChanged: (val) {
        setState(() {
          _currentOtp = val;
          // I-clear ang messages kapag nag-type ulit
          if (_errorMessage != null) _errorMessage = null;
          if (_successMessage != null) _successMessage = null;
          // I-lift ang block kapag nag-type ulit ang user
          if (_blockAutoVerify) _blockAutoVerify = false;
        });
      },
      onCompleted: (_) {
        // Auto-verify kapag kumpleto na ang 6 digits
        // at hindi naka-block (i.e. hindi galing sa error clear)
        if (!_blockAutoVerify) {
          _handleVerify();
        }
      },
    );
  }

  Widget _buildResendSection(BuildContext context) {
    return Column(
      children: [
        Text(
          'Didn\'t receive the code?',
          style: AppTextStyles.bodyMedium(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        _countdown > 0
            ? Text(
          'Resend in $_countdown s',
          style: GoogleFonts.karla(
            fontSize: 13,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        )
            : GestureDetector(
          onTap: _isResending ? null : _handleResend,
          child: _isResending
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              color: AppColors.gold,
              strokeWidth: 2,
            ),
          )
              : Text(
            'Resend Code',
            style: AppTextStyles.link(context),
          ),
        ),
      ],
    );
  }
}

class _BigLanternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final maroonFill = Paint()
      ..color = AppColors.primaryDark
      ..style = PaintingStyle.fill;

    final goldStroke = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final goldFill = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    canvas.drawLine(
      Offset(w / 2, 0),
      Offset(w / 2, h * 0.08),
      Paint()
        ..color = AppColors.gold
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );

    final capRect = Rect.fromLTWH(w * 0.2, h * 0.06, w * 0.6, h * 0.1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, const Radius.circular(4)),
      goldFill,
    );

    final bodyPath = Path()
      ..moveTo(w * 0.1, h * 0.2)
      ..quadraticBezierTo(0, h * 0.5, w * 0.1, h * 0.78)
      ..lineTo(w * 0.9, h * 0.78)
      ..quadraticBezierTo(w, h * 0.5, w * 0.9, h * 0.2)
      ..close();
    canvas.drawPath(bodyPath, maroonFill);
    canvas.drawPath(bodyPath, goldStroke);

    for (int i = 1; i <= 3; i++) {
      final y = h * 0.2 + (h * 0.58) * (i / 4);
      canvas.drawLine(
        Offset(w * 0.1, y),
        Offset(w * 0.9, y),
        goldStroke..color = AppColors.gold.withOpacity(0.3)..strokeWidth = 1,
      );
    }

    canvas.drawLine(
      Offset(w / 2, h * 0.2),
      Offset(w / 2, h * 0.78),
      goldStroke..color = AppColors.gold.withOpacity(0.3)..strokeWidth = 1,
    );

    final botCapRect = Rect.fromLTWH(w * 0.2, h * 0.76, w * 0.6, h * 0.08);
    canvas.drawRRect(
      RRect.fromRectAndRadius(botCapRect, const Radius.circular(4)),
      goldFill,
    );

    final tasselPaint = Paint()
      ..color = AppColors.gold
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 5; i++) {
      final x = w * 0.3 + i * w * 0.1;
      canvas.drawLine(
        Offset(x, h * 0.84),
        Offset(x + (i % 2 == 0 ? -4 : 4), h),
        tasselPaint,
      );
    }

    canvas.drawCircle(
      Offset(w / 2, h * 0.49),
      w * 0.06,
      Paint()..color = AppColors.goldLight.withOpacity(0.5),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}