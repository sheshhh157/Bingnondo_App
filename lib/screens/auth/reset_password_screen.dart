import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String otp;

  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.otp,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _isDone = false;
  String? _errorMessage;

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await context.read<AuthProvider>().resetPassword(
        otp: widget.otp,
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      setState(() => _isDone = true);
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
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.height < 680;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: !_isDone,
        leading: _isDone
            ? null
            : IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'New Password',
          style: GoogleFonts.playfairDisplaySc(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            isCompact ? AppSpacing.md : AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          child: _isDone ? _buildSuccess(context) : _buildForm(context, isCompact),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, bool isCompact) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Set new password', style: AppTextStyles.display2(context)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Choose a strong password you haven\'t used before.',
            style: AppTextStyles.bodyMedium(context),
          ),

          SizedBox(height: isCompact ? AppSpacing.lg : AppSpacing.xl),

          if (_errorMessage != null) ...[
            StatusBanner(message: _errorMessage!, isError: true),
            const SizedBox(height: AppSpacing.md),
          ],

          AppTextField(
            label: 'New Password',
            controller: _passwordController,
            isPassword: true,
            textInputAction: TextInputAction.next,
            autofocus: true,
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.gold),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required.';
              if (v.length < 8) return 'Password must be at least 8 characters.';
              return null;
            },
          ),

          const SizedBox(height: AppSpacing.md),

          AppTextField(
            label: 'Confirm New Password',
            controller: _confirmController,
            isPassword: true,
            textInputAction: TextInputAction.done,
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.gold),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your password.';
              if (v != _passwordController.text) return 'Passwords do not match.';
              return null;
            },
          ),

          const SizedBox(height: AppSpacing.xl),

          PrimaryButton(
            label: 'RESET PASSWORD',
            onPressed: _handleReset,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.xxl),

        // Success illustration
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.success.withOpacity(0.3), width: 2),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.success,
              size: 48,
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        Text(
          'Password updated!',
          style: AppTextStyles.display2(context),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AppSpacing.sm),

        Text(
          'Your password has been reset successfully.\nYou can now sign in.',
          style: AppTextStyles.bodyMedium(context),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AppSpacing.xxl),

        PrimaryButton(
          label: 'SIGN IN',
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
            );
          },
        ),
      ],
    );
  }
}