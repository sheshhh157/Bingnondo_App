import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../mock/mock_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../services/cart_service.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _mobileCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (kUseMock) {
        await Future.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;
        setState(() => _successMessage = 'Profile saved!');
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        Navigator.pop(context, true); // return true = profile now complete
      } else {
        // TODO: Replace with real PUT /api/customer/profile call
        // final headers = await _authHeaders();
        // await http.put(Uri.parse('$baseUrl/api/customer/profile'), ...);
        Navigator.pop(context, true);
      }
    } on CartApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Could not save profile. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.height < 700;

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    isCompact ? AppSpacing.md : AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Progress gate banner
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                                color: AppColors.gold.withOpacity(0.3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomPaint(
                                  size: const Size(16, 16),
                                  painter: _LanternSmall()),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Just a few more details so we can get your order to you!',
                                  style: GoogleFonts.karla(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(
                            height: isCompact ? AppSpacing.lg : AppSpacing.xl),

                        // Error / success
                        if (_errorMessage != null) ...[
                          StatusBanner(message: _errorMessage!, isError: true),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        if (_successMessage != null) ...[
                          StatusBanner(
                              message: _successMessage!, isError: false),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // Name row (responsive: row on wide, column on narrow)
                        _buildNameRow(context),

                        const SizedBox(height: AppSpacing.md),

                        // Mobile
                        AppTextField(
                          label: 'Mobile Number',
                          hint: '+63 917 123 4567',
                          controller: _mobileCtrl,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          prefixIcon: const Icon(
                            Icons.phone_outlined,
                            size: 20,
                            color: AppColors.gold,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Mobile number is required.';
                            }
                            final ph = v.trim().replaceAll(' ', '');
                            if (!RegExp(r'^(\+63|0)[0-9]{10}$').hasMatch(ph)) {
                              return 'Enter a valid PH mobile number.';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // Address
                        _buildAddressField(context),

                        const SizedBox(height: AppSpacing.xl),

                        PrimaryButton(
                          label: 'SAVE & CONTINUE',
                          onPressed: _handleSave,
                          isLoading: _isLoading,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppColors.primaryDark,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: AppColors.textOnDark,
            onPressed: () => Navigator.pop(context, false),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Complete Profile',
                  style: GoogleFonts.playfairDisplaySc(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnDark,
                  ),
                ),
                Text(
                  'Required before ordering',
                  style: GoogleFonts.karla(
                    fontSize: 11,
                    color: AppColors.textOnDark.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          const ChineseCornerDecoration(size: 28, flipH: true),
        ],
      ),
    );
  }

  Widget _buildNameRow(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 500;

    if (isWide) {
      return Row(
        children: [
          Expanded(
            child: AppTextField(
              label: 'First Name',
              controller: _firstNameCtrl,
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
              prefixIcon: const Icon(Icons.person_outline_rounded,
                  size: 20, color: AppColors.gold),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'First name is required.';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: AppTextField(
              label: 'Last Name',
              controller: _lastNameCtrl,
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
              prefixIcon: const Icon(Icons.person_outline_rounded,
                  size: 20, color: AppColors.gold),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Last name is required.';
                }
                return null;
              },
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        AppTextField(
          label: 'First Name',
          controller: _firstNameCtrl,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          prefixIcon: const Icon(Icons.person_outline_rounded,
              size: 20, color: AppColors.gold),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'First name is required.';
            return null;
          },
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Last Name',
          controller: _lastNameCtrl,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          prefixIcon: const Icon(Icons.person_outline_rounded,
              size: 20, color: AppColors.gold),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Last name is required.';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildAddressField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Delivery Address', style: AppTextStyles.label(context)),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: _addressCtrl,
          maxLines: 3,
          keyboardType: TextInputType.streetAddress,
          textInputAction: TextInputAction.done,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: GoogleFonts.karla(
              fontSize: 15, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Street, Barangay, City, Province…',
            hintStyle:
            GoogleFonts.karla(fontSize: 14, color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.inputFill,
            contentPadding: const EdgeInsets.all(AppSpacing.md),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide:
              const BorderSide(color: AppColors.inputBorder, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide:
              const BorderSide(color: AppColors.inputBorder, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.gold, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide:
              const BorderSide(color: AppColors.error, width: 1.5),
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 0, 0),
              child: CustomPaint(
                  size: const Size(20, 20), painter: _PinPainter()),
            ),
            prefixIconConstraints:
            const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Delivery address is required.';
            }
            if (v.trim().length < 10) {
              return 'Please enter your full delivery address.';
            }
            return null;
          },
          onChanged: (_) {
            if (_errorMessage != null) setState(() => _errorMessage = null);
          },
        ),
      ],
    );
  }
}

class _LanternSmall extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(
        Rect.fromLTWH(
            size.width * 0.1, size.height * 0.2, size.width * 0.8, size.height * 0.6),
        Paint()
          ..color = AppColors.gold.withOpacity(0.6)
          ..style = PaintingStyle.fill);
    canvas.drawLine(
        Offset(size.width / 2, 0), Offset(size.width / 2, size.height * 0.2),
        Paint()
          ..color = AppColors.gold
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.fill;
    final path = Path()
      ..addOval(Rect.fromLTWH(
          size.width * 0.1, 0, size.width * 0.8, size.height * 0.65))
      ..moveTo(size.width / 2, size.height * 0.65)
      ..lineTo(size.width * 0.35, size.height * 0.45)
      ..lineTo(size.width * 0.65, size.height * 0.45)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawOval(
        Rect.fromLTWH(size.width * 0.3, size.height * 0.15, size.width * 0.4,
            size.height * 0.35),
        Paint()
          ..color = AppColors.primaryDark
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}