import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/business_hours_provider.dart';
import '../theme/app_theme.dart';

/// Warning shown while the cafe is outside its business hours.
/// Renders nothing when the cafe is open (or the status isn't loaded yet).
class BusinessHoursBanner extends StatelessWidget {
  final bool compact;

  const BusinessHoursBanner({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final hours = context.watch<BusinessHoursProvider>();
    if (!hours.isKnownClosed) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: compact ? AppSpacing.sm : AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_clock_rounded,
            color: AppColors.error,
            size: compact ? 16 : 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bingnondo is closed',
                  style: GoogleFonts.karla(
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hours.message,
                  style: GoogleFonts.karla(
                    fontSize: compact ? 11 : 12,
                    height: 1.35,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 2),
                  Text(
                    'You can still add items to your cart — placing orders resumes when we reopen.',
                    style: GoogleFonts.karla(
                      fontSize: 11,
                      height: 1.35,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
