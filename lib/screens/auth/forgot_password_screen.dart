import 'package:flutter/material.dart';
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
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _errorMessage;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      await context.read<AuthProvider>().forgotPassword(email: email);

      if (!mounted) return;

      // Go to OTP screen, then reset password
      final otp = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(email: email, isPasswordReset: true),
        ),
      );

      if (!mounted || otp == null) return;

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(email: email, otp: otp),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.height < 680;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              isCompact ? AppSpacing.md : AppSpacing.xxl,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Illustration
                  Center(
                    child: CustomPaint(
                      size: Size(isCompact ? 64 : 80, (isCompact ? 64 : 80) * 1.3),
                      painter: _KeyPainter(),
                    ),
                  ),

                  SizedBox(height: isCompact ? AppSpacing.lg : AppSpacing.xl),

                  Text('Forgot password?', style: AppTextStyles.display2(context)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'No worries. Enter your email and we\'ll send you a reset code.',
                    style: AppTextStyles.bodyMedium(context),
                  ),

                  SizedBox(height: isCompact ? AppSpacing.lg : AppSpacing.xl),

                  if (_errorMessage != null) ...[
                    StatusBanner(message: _errorMessage!, isError: true),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  AppTextField(
                    label: 'Email Address',
                    hint: 'you@example.com',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofocus: true,
                    prefixIcon: const Icon(
                      Icons.mail_outline_rounded,
                      size: 20,
                      color: AppColors.gold,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email is required.';
                      final emailReg = RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-z]{2,}$', caseSensitive: false);
                      if (!emailReg.hasMatch(v.trim())) return 'Please enter a valid email.';
                      return null;
                    },
                    onChanged: (_) {
                      if (_errorMessage != null) setState(() => _errorMessage = null);
                    },
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  PrimaryButton(
                    label: 'SEND RESET CODE',
                    onPressed: _handleSubmit,
                    isLoading: _isLoading,
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Back to Sign In',
                        style: AppTextStyles.link(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.fill;
    final maroon = Paint()
      ..color = AppColors.primaryDark
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Envelope body
    final envPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h * 0.25, w, h * 0.65),
        const Radius.circular(8),
      ));
    canvas.drawPath(envPath, maroon);
    canvas.drawPath(envPath, stroke..style = PaintingStyle.stroke);

    // Envelope flap (open V)
    final flapPath = Path()
      ..moveTo(0, h * 0.25)
      ..lineTo(w / 2, h * 0.52)
      ..lineTo(w, h * 0.25);
    canvas.drawPath(flapPath, stroke..style = PaintingStyle.stroke..strokeWidth = 2);

    // Bottom lines (content representation)
    for (int i = 0; i < 3; i++) {
      final y = h * 0.62 + i * h * 0.1;
      final xEnd = i == 2 ? w * 0.55 : w * 0.8;
      canvas.drawLine(
        Offset(w * 0.15, y),
        Offset(xEnd, y),
        stroke..color = AppColors.gold.withOpacity(0.4)..strokeWidth = 1.5,
      );
    }

    // Lock icon on top
    canvas.drawCircle(Offset(w / 2, h * 0.15), w * 0.18, gold);
    canvas.drawCircle(Offset(w / 2, h * 0.15), w * 0.18,
        stroke..color = AppColors.primaryDark..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Lock icon detail
    final lockBody = Paint()..color = AppColors.primaryDark..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w / 2 - w * 0.07, h * 0.11, w * 0.14, h * 0.1),
        const Radius.circular(3),
      ),
      lockBody,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}