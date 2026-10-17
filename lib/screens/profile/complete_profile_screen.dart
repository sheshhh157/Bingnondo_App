/**
 * complete_profile_screen.dart  —  §1.1b Complete Profile
 * ─────────────────────────────────────────────────────────
 * Gate screen shown when customer tries to checkout without a completed profile.
 * Calls PUT /api/customer/profile via CartService.updateProfile().
 *
 * Returns `true` via Navigator.pop when profile is saved successfully.
 * CartProvider.checkProfileGate() re-runs after this returns.
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../mock/mock_data.dart';
import '../../models/geo_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/address_picker_field.dart';
import '../../services/cart_service.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey     = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _mobileCtrl    = TextEditingController();

  PickedAddress? _pickedAddress;

  bool    _isLoading     = false;
  String? _errorMessage;
  String? _successMessage;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fade;

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
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading    = true;
      _errorMessage = null;
    });

    try {
      if (kUseMock) {
        await Future.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;
        setState(() => _successMessage = 'Profile saved!');
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        await CartService.instance.updateProfile(
          firstName:    _firstNameCtrl.text,
          lastName:     _lastNameCtrl.text,
          mobileNumber: _mobileCtrl.text,
          address:      _pickedAddress?.address ?? '',
          latitude:     _pickedAddress?.latitude,
          longitude:    _pickedAddress?.longitude,
        );
        if (!mounted) return;
        setState(() => _successMessage = 'Profile saved!');
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
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
    final theme     = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.primary,
          onPressed: () => Navigator.pop(context, false),
        ),
        title: Text(
          'Complete Your Profile',
          style: GoogleFonts.playfairDisplaySc(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fade,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header copy ──────────────────────────────────────────────
              Text(
                'Just a few more details so we can get your order to you!',
                style: GoogleFonts.karla(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // ── Form ─────────────────────────────────────────────────────
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildField(
                      controller: _firstNameCtrl,
                      label:      'First Name',
                      hint:       'e.g. Juan',
                      validator:  (v) => (v == null || v.trim().isEmpty) ? 'First name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _lastNameCtrl,
                      label:      'Last Name',
                      hint:       'e.g. dela Cruz',
                      validator:  (v) => (v == null || v.trim().isEmpty) ? 'Last name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      controller:  _mobileCtrl,
                      label:       'Mobile Number',
                      hint:        'e.g. 09171234567',
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 11,
                      validator:  (v) {
                        if (v == null || v.trim().isEmpty) return 'Mobile number is required';
                        if (v.trim().length < 10) return 'Enter a valid mobile number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AddressPickerField(
                      label:    'Delivery Address',
                      hint:     'Tap to pin your delivery location on the map',
                      required: true,
                      onChanged: (p) => _pickedAddress = p,
                    ),
                  ],
                ),
              ),

              // ── Error / Success messages ──────────────────────────────────
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                BngErrorBanner(message: _errorMessage!),
              ],
              if (_successMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:        Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border:       Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(children: [
                    Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
                    const SizedBox(width: 8),
                    Text(_successMessage!,
                        style: GoogleFonts.karla(color: Colors.green.shade700)),
                  ]),
                ),
              ],

              const SizedBox(height: 28),

              // ── Save button ───────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                      : Text(
                    'Save Profile',
                    style: GoogleFonts.karla(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType         = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    int maxLines                       = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller:       controller,
      keyboardType:     keyboardType,
      inputFormatters:  inputFormatters,
      maxLength:        maxLength,
      maxLines:         maxLines,
      validator:        validator,
      style:            GoogleFonts.karla(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText:     label,
        hintText:      hint,
        labelStyle:    GoogleFonts.karla(color: AppColors.primary.withOpacity(0.8)),
        hintStyle:     GoogleFonts.karla(color: Colors.grey.shade400, fontSize: 13),
        counterText:   '',
        filled:        true,
        fillColor:     Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   BorderSide(color: AppColors.primary.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   BorderSide(color: AppColors.primary.withOpacity(0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: Colors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

// ─── Small reusable error banner ──────────────────────────────────────────────
class BngErrorBanner extends StatelessWidget {
  final String message;
  const BngErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: Colors.red.shade300),
      ),
      child: Row(children: [
        Icon(Icons.error_outline, color: Colors.red.shade600, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: GoogleFonts.karla(color: Colors.red.shade700, fontSize: 13)),
        ),
      ]),
    );
  }
}