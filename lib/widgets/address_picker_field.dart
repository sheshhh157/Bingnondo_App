/**
 * address_picker_field.dart  —  Reusable "pin your address" form field
 * ───────────────────────────────────────────────────────────────────
 * A tappable card that opens AddressPickerScreen and integrates with Flutter's
 * Form validation (it IS a `FormField<PickedAddress>`).
 */

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/geo_models.dart';
import '../screens/address/address_picker_screen.dart';
import '../theme/app_theme.dart';

class AddressPickerField extends FormField<PickedAddress> {
  final String label;
  final String hint;

  AddressPickerField({
    super.key,
    PickedAddress? initialValue,
    this.label = 'Delivery Address',
    this.hint = 'Pin your delivery location on the map',
    bool required = false,
    ValueChanged<PickedAddress>? onChanged,
    String? Function(PickedAddress?)? validator,
  }) : super(
          initialValue: initialValue,
          validator: validator ??
              (required
                  ? (v) => (v == null || v.isEmpty) ? '$label is required' : null
                  : null),
          builder: (state) => _AddressPickerFieldBody(
            state:     state,
            label:     label,
            hint:      hint,
            onChanged: onChanged,
          ),
        );
}

class _AddressPickerFieldBody extends StatelessWidget {
  final FormFieldState<PickedAddress> state;
  final String label;
  final String hint;
  final ValueChanged<PickedAddress>? onChanged;

  const _AddressPickerFieldBody({
    required this.state,
    required this.label,
    required this.hint,
    this.onChanged,
  });

  Future<void> _open(BuildContext context) async {
    final picked = await Navigator.push<PickedAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressPickerScreen(initial: state.value),
      ),
    );
    if (picked != null) {
      state.didChange(picked);
      onChanged?.call(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value    = state.value;
    final hasValue = value != null && !value.isEmpty;
    final hasError = state.hasError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label(context)),
        const SizedBox(height: AppSpacing.sm),
        GestureDetector(
          onTap: () => _open(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: hasError
                    ? AppColors.error
                    : (hasValue ? AppColors.gold : AppColors.inputBorder),
                width: hasError ? 1.5 : (hasValue ? 1.5 : 1.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on_rounded,
                      color: AppColors.gold, size: 16),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasValue ? value.address : hint,
                        style: GoogleFonts.karla(
                          fontSize: 14,
                          fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                          color: hasValue
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      if (hasValue && value.hasCoordinates) ...[
                        const SizedBox(height: 3),
                        Text(
                          '${value.latitude!.toStringAsFixed(5)}, ${value.longitude!.toStringAsFixed(5)}',
                          style: AppTextStyles.caption(context),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.edit_location_alt_outlined,
                        color: AppColors.primary, size: 20),
                    const SizedBox(height: 2),
                    Text(
                      hasValue ? 'Change' : 'Pin',
                      style: GoogleFonts.karla(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              state.errorText ?? '',
              style: GoogleFonts.karla(
                  fontSize: 12, color: AppColors.error, height: 1.3),
            ),
          ),
        ],
      ],
    );
  }
}
