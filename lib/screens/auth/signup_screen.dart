import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import 'login_screen.dart';
import 'otp_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {

  // ─── Email form ──────────────────────────────────────────────────────────
  final _emailFormKey       = GlobalKey<FormState>();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();
  final _emailFocus         = FocusNode();
  final _passwordFocus      = FocusNode();
  final _confirmFocus       = FocusNode();

  bool _isLoading     = false;
  String? _errorMessage;
  bool _termsAccepted = false;

  late final AnimationController _animController;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  // ─── Submit: Email ───────────────────────────────────────────────────────

  Future<void> _handleEmailSignUp() async {
    if (!_emailFormKey.currentState!.validate()) return;

    if (!_termsAccepted) {
      setState(() => _errorMessage = 'Please agree to our Terms and Privacy Policy to continue.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final email = _emailController.text.trim();
      await context.read<AuthProvider>().register(
        email: email,
        password: _passwordController.text,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, anim, __) =>
              OtpScreen(contact: email),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage =
          e.isConflict ? 'This email is already registered. Sign in instead.' : e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Password strength ───────────────────────────────────────────────────

  double _passwordStrength(String pw) {
    if (pw.isEmpty) return 0;
    double score = 0;
    if (pw.length >= 8) score += 0.25;
    if (pw.length >= 12) score += 0.15;
    if (RegExp(r'[A-Z]').hasMatch(pw)) score += 0.2;
    if (RegExp(r'[0-9]').hasMatch(pw)) score += 0.2;
    if (RegExp(r'[!@#\$&*~%^]').hasMatch(pw)) score += 0.2;
    return score.clamp(0, 1);
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size      = MediaQuery.of(context).size;
    final isWide    = size.width >= 600;
    final isCompact = size.height < 700;

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: isWide
                ? _buildWideLayout(context, isCompact)
                : _buildPortraitLayout(context, isCompact),
          ),
        ),
      ),
    );
  }

  // ─── Wide layout (tablet) ────────────────────────────────────────────────

  Widget _buildWideLayout(BuildContext context, bool isCompact) {
    return Row(
      children: [
        Expanded(child: _buildBrandPanel(context)),
        Expanded(
          child: _buildFormPanel(context, isCompact, isWide: true),
        ),
      ],
    );
  }

  Widget _buildBrandPanel(BuildContext context) {
    return Container(
      color: AppColors.primaryDark,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            BrandCatIcon(size: 80),
            const SizedBox(width: AppSpacing.lg),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Join Bingnondo',
                  style: GoogleFonts.playfairDisplaySc(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Create your account and\nstart ordering in minutes.',
                  style: GoogleFonts.karla(
                    fontSize: 14,
                    color: AppColors.textOnDark.withOpacity(0.65),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _buildProgressDots(0),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Portrait layout (phone) ─────────────────────────────────────────────

  Widget _buildPortraitLayout(BuildContext context, bool isCompact) {
    return Column(
      children: [
        _buildPortraitHeader(context, isCompact),
        Expanded(child: _buildFormPanel(context, isCompact)),
      ],
    );
  }

  Widget _buildPortraitHeader(BuildContext context, bool isCompact) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        isCompact ? AppSpacing.md : AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      color: AppColors.primaryDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              BrandCatIcon(size: isCompact ? 48 : 64),
              const SizedBox(width: AppSpacing.md),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Account',
                    style: GoogleFonts.playfairDisplaySc(
                      fontSize: isCompact ? 22 : 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textOnDark,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs + 2),
                  _buildProgressDots(0),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressDots(int step) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(2, (i) {
        final isActive = i == step;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.gold
                : AppColors.textOnDark.withOpacity(0.3),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        );
      }),
    );
  }

  // ─── Form panel ──────────────────────────────────────────────────────────

  Widget _buildFormPanel(BuildContext context, bool isCompact, {bool isWide = false}) {
    return Container(
      color: AppColors.background,
      child: _buildEmailForm(
        context,
        isCompact,
        isWide: isWide,
      ),
    );
  }

  // ─── Email Form ──────────────────────────────────────────────────────────

  Widget _buildEmailForm(BuildContext context, bool isCompact, {bool isWide = false}) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        isCompact ? AppSpacing.lg : (isWide ? AppSpacing.xxl : AppSpacing.xl),
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      child: Form(
        key: _emailFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isWide) ...[
              BrandCatIcon(size: 48),
              const SizedBox(height: AppSpacing.md),
            ],

            Text('New here?', style: AppTextStyles.display2(context)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Just your email and a password — you\'re in.',
              style: AppTextStyles.bodyMedium(context),
            ),

            SizedBox(height: isCompact ? AppSpacing.md : AppSpacing.xl),

            if (_errorMessage != null) ...[
              StatusBanner(message: _errorMessage!, isError: true),
              const SizedBox(height: AppSpacing.md),
            ],

            AppTextField(
              label: 'Email Address',
              hint: 'you@example.com',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              focusNode: _emailFocus,
              textInputAction: TextInputAction.next,
              prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20, color: AppColors.gold),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required.';
                final reg = RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-z]{2,}$', caseSensitive: false);
                if (!reg.hasMatch(v.trim())) return 'Please enter a valid email address.';
                return null;
              },
              onChanged: (_) {
                if (_errorMessage != null) setState(() => _errorMessage = null);
              },
            ),

            const SizedBox(height: AppSpacing.md),

            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _passwordController,
              builder: (_, val, __) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    label: 'Password',
                    controller: _passwordController,
                    isPassword: true,
                    focusNode: _passwordFocus,
                    textInputAction: TextInputAction.next,
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.gold),
                    validator: validatePassword,
                    autovalidateMode: AutovalidateMode.disabled,
                    onChanged: (_) {
                      if (_errorMessage != null) setState(() => _errorMessage = null);
                    },
                  ),
                  PasswordChecklist(password: val.text),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            AppTextField(
              label: 'Confirm Password',
              controller: _confirmController,
              isPassword: true,
              focusNode: _confirmFocus,
              textInputAction: TextInputAction.done,
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.gold),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please confirm your password.';
                if (v != _passwordController.text) return 'Passwords do not match.';
                return null;
              },
            ),

            SizedBox(height: isCompact ? AppSpacing.md : AppSpacing.lg),
            _buildTermsCheckbox(context),
            SizedBox(height: isCompact ? AppSpacing.md : AppSpacing.lg),

            PrimaryButton(
              label: 'CREATE ACCOUNT',
              onPressed: _handleEmailSignUp,
              isLoading: _isLoading,
            ),

            SizedBox(height: isCompact ? AppSpacing.md : AppSpacing.lg),
            _buildInfoNote(context, 'Just email and password to start. We\'ll ask for your name and address only when you\'re ready to place your first order.'),
            SizedBox(height: isCompact ? AppSpacing.md : AppSpacing.lg),
            const ChineseDivider(),
            const SizedBox(height: AppSpacing.md),
            _buildLoginPrompt(context),
          ],
        ),
      ),
    );
  }

  // ─── Shared widgets ──────────────────────────────────────────────────────

  Widget _buildTermsCheckbox(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _termsAccepted = !_termsAccepted),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24, height: 24,
            child: Checkbox(
              value: _termsAccepted,
              onChanged: (v) => setState(() => _termsAccepted = v ?? false),
              activeColor: AppColors.primary,
              checkColor: AppColors.textOnDark,
              side: const BorderSide(color: AppColors.gold, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text.rich(
                TextSpan(
                  style: GoogleFonts.karla(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  children: [
                    const TextSpan(text: 'I agree to Bingnondo\'s '),
                    TextSpan(
                      text: 'Terms of Service',
                      style: GoogleFonts.karla(
                        fontSize: 13, color: AppColors.gold, fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline, decorationColor: AppColors.gold,
                      ),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: GoogleFonts.karla(
                        fontSize: 13, color: AppColors.gold, fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline, decorationColor: AppColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoNote(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.goldMuted, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.karla(
                fontSize: 12, color: AppColors.textSecondary, height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Already have an account? ', style: AppTextStyles.bodyMedium(context)),
        GestureDetector(
          onTap: () => Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, anim, __) => const LoginScreen(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 300),
            ),
          ),
          child: Text('Sign in', style: AppTextStyles.link(context)),
        ),
      ],
    );
  }
}
