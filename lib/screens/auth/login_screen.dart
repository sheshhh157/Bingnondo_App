import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

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
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await context.read<AuthProvider>().login(
        emailOrMobile: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Navigation is handled by router listening to AuthProvider status
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _mapError(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapError(ApiException e) {
    if (e.statusCode == 401) {
      return 'Incorrect email or password.';
    } else if (e.statusCode == 403) {
      if (e.message.contains('suspended')) {
        return 'Account suspended. Please contact support.';
      }
      return 'Please verify your account first.';
    }
    return e.message;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 600;
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
            child: _buildLayout(context, isWide, isCompact, size),
          ),
        ),
      ),
    );
  }

  Widget _buildLayout(
      BuildContext context,
      bool isWide,
      bool isCompact,
      Size size,
      ) {
    if (isWide) {
      // Tablet / large phone landscape — two column
      return Row(
        children: [
          Expanded(child: _buildBrandPanel(context, isCompact)),
          Expanded(
            child: _buildFormPanel(context, isCompact),
          ),
        ],
      );
    }

    // Portrait / compact — single column with scrollable form
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            children: [
              _buildHeader(context, isCompact),
              Expanded(child: _buildFormPanel(context, isCompact)),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Brand Panel (wide layouts) ────────────────────────────────────────────
  Widget _buildBrandPanel(BuildContext context, bool isCompact) {
    return Container(
      color: AppColors.primaryDark,
      child: Stack(
        children: [
          // Corner decorations
          const Positioned(top: 16, left: 16, child: ChineseCornerDecoration(size: 50)),
          const Positioned(top: 16, right: 16, child: ChineseCornerDecoration(size: 50, flipH: true)),
          const Positioned(bottom: 16, left: 16, child: ChineseCornerDecoration(size: 50, flipV: true)),
          const Positioned(bottom: 16, right: 16, child: ChineseCornerDecoration(size: 50, flipH: true, flipV: true)),

          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BrandCatIcon(size: 100),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Bingnondo',
                  style: GoogleFonts.playfairDisplaySc(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnDark,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Authentic Binondo Flavors\nDelivered to Your Door',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.karla(
                    fontSize: 14,
                    color: AppColors.textOnDark.withOpacity(0.7),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header (portrait) ─────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, bool isCompact) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        isCompact ? AppSpacing.md : AppSpacing.xxl,
        AppSpacing.lg,
        isCompact ? AppSpacing.lg : AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primaryDark,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Top-left corner decoration
          const Positioned(
            top: -8,
            left: -8,
            child: ChineseCornerDecoration(size: 40),
          ),
          const Positioned(
            top: -8,
            right: -8,
            child: ChineseCornerDecoration(size: 40, flipH: true),
          ),

          Column(
            children: [
              if (!isCompact) ...[
                BrandCatIcon(size: 72),
                const SizedBox(height: AppSpacing.md),
              ],
              Text(
                'Bingnondo',
                style: GoogleFonts.playfairDisplaySc(
                  fontSize: isCompact ? 26 : 30,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textOnDark,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'The taste of Binondo, anytime.',
                style: GoogleFonts.karla(
                  fontSize: 13,
                  color: AppColors.textOnDark.withOpacity(0.65),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Form Panel ────────────────────────────────────────────────────────────
  Widget _buildFormPanel(BuildContext context, bool isCompact) {
    final isWide = MediaQuery.of(context).size.width >= 600;

    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          isCompact ? AppSpacing.lg : AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section heading
              if (isWide) ...[
                const SizedBox(height: AppSpacing.xl),
                BrandCatIcon(size: 56),
                const SizedBox(height: AppSpacing.md),
              ],
              Text(
                'Welcome back',
                style: AppTextStyles.display2(context),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Sign in to continue your order',
                style: AppTextStyles.bodyMedium(context),
              ),

              SizedBox(height: isCompact ? AppSpacing.lg : AppSpacing.xl),

              // Error banner
              if (_errorMessage != null) ...[
                StatusBanner(message: _errorMessage!, isError: true),
                const SizedBox(height: AppSpacing.md),
              ],

              // Email/Mobile
              AppTextField(
                label: 'Email or Mobile Number',
                hint: 'you@example.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                focusNode: _emailFocus,
                textInputAction: TextInputAction.next,
                prefixIcon: const Icon(
                  Icons.person_outline_rounded,
                  size: 20,
                  color: AppColors.gold,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please enter your email or mobile number.';
                  return null;
                },
                onChanged: (_) {
                  if (_errorMessage != null) setState(() => _errorMessage = null);
                },
              ),

              const SizedBox(height: AppSpacing.md),

              // Password
              AppTextField(
                label: 'Password',
                controller: _passwordController,
                isPassword: true,
                focusNode: _passwordFocus,
                textInputAction: TextInputAction.done,
                prefixIcon: const Icon(
                  Icons.lock_outline_rounded,
                  size: 20,
                  color: AppColors.gold,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter your password.';
                  return null;
                },
                onChanged: (_) {
                  if (_errorMessage != null) setState(() => _errorMessage = null);
                },
              ),

              const SizedBox(height: AppSpacing.sm),

              // Forgot password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xs,
                    ),
                    minimumSize: const Size(44, 44),
                  ),
                  child: Text(
                    'Forgot password?',
                    style: AppTextStyles.link(context).copyWith(fontSize: 13),
                  ),
                ),
              ),

              SizedBox(height: isCompact ? AppSpacing.md : AppSpacing.lg),

              // Sign In button
              PrimaryButton(
                label: 'SIGN IN',
                onPressed: _handleLogin,
                isLoading: _isLoading,
              ),

              SizedBox(height: isCompact ? AppSpacing.md : AppSpacing.lg),

              // Divider
              const ChineseDivider(),

              SizedBox(height: isCompact ? AppSpacing.md : AppSpacing.lg),

              // Go to Sign Up
              _buildSignUpPrompt(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpPrompt(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: AppTextStyles.bodyMedium(context),
        ),
        GestureDetector(
          onTap: () {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, anim, __) => const SignUpScreen(),
                transitionsBuilder: (_, anim, __, child) {
                  return FadeTransition(opacity: anim, child: child);
                },
                transitionDuration: const Duration(milliseconds: 300),
              ),
            );
          },
          child: Text(
            'Sign up',
            style: AppTextStyles.link(context),
          ),
        ),
      ],
    );
  }
}