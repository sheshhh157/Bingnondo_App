import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

// ─── Binondo Lucky Cat Image ─────────────────────────────────────────────────────
// The brand mascot — uses image asset with painter fallback
class BrandCatIcon extends StatelessWidget {
  final double size;

  const BrandCatIcon({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/lucky_cat.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _CatPainter(),
          ),
        );
      },
    );
  }
}

class _CatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final maroon = Paint()
      ..color = AppColors.primaryDark
      ..style = PaintingStyle.fill;
    final gold = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.04
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Scale to fit
    final s = size.width / 100;
    canvas.scale(s, s);

    // Body
    final bodyPath = Path()
      ..moveTo(20, 95)
      ..lineTo(15, 60)
      ..quadraticBezierTo(10, 30, 30, 20)
      ..quadraticBezierTo(50, 10, 70, 20)
      ..quadraticBezierTo(90, 30, 85, 60)
      ..lineTo(80, 95)
      ..close();
    canvas.drawPath(bodyPath, maroon);
    canvas.drawPath(bodyPath, gold);

    // Head
    final headPath = Path()
      ..addOval(const Rect.fromLTWH(22, 5, 56, 50));
    canvas.drawPath(headPath, maroon);
    canvas.drawPath(headPath, gold);

    // Left ear
    final leftEar = Path()
      ..moveTo(25, 22)
      ..lineTo(18, 5)
      ..lineTo(35, 12)
      ..close();
    canvas.drawPath(leftEar, maroon);
    canvas.drawPath(leftEar, gold);

    // Right ear
    final rightEar = Path()
      ..moveTo(75, 22)
      ..lineTo(82, 5)
      ..lineTo(65, 12)
      ..close();
    canvas.drawPath(rightEar, maroon);
    canvas.drawPath(rightEar, gold);

    // Eyes (closed — happy cat)
    final eyePaint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Left eye smile
    final leftEyePath = Path()
      ..moveTo(35, 30)
      ..quadraticBezierTo(38, 35, 41, 30);
    canvas.drawPath(leftEyePath, eyePaint);

    // Right eye smile
    final rightEyePath = Path()
      ..moveTo(59, 30)
      ..quadraticBezierTo(62, 35, 65, 30);
    canvas.drawPath(rightEyePath, eyePaint);

    // Nose
    final nosePaint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.fill;
    canvas.drawOval(const Rect.fromLTWH(47, 37, 6, 4), nosePaint);

    // Mouth
    final mouthPath = Path()
      ..moveTo(50, 41)
      ..quadraticBezierTo(46, 46, 42, 44);
    final mouthPath2 = Path()
      ..moveTo(50, 41)
      ..quadraticBezierTo(54, 46, 58, 44);
    canvas.drawPath(mouthPath, eyePaint);
    canvas.drawPath(mouthPath2, eyePaint);

    // Raised right paw
    final pawPath = Path()
      ..moveTo(75, 40)
      ..quadraticBezierTo(90, 20, 88, 10)
      ..quadraticBezierTo(85, 5, 80, 8)
      ..quadraticBezierTo(78, 5, 75, 8)
      ..quadraticBezierTo(70, 5, 68, 8)
      ..quadraticBezierTo(65, 5, 63, 10)
      ..quadraticBezierTo(60, 20, 72, 38)
      ..close();
    canvas.drawPath(pawPath, maroon);
    canvas.drawPath(pawPath, gold);

    // Collar
    final collarPaint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final collarPath = Path()
      ..moveTo(28, 54)
      ..quadraticBezierTo(50, 62, 72, 54);
    canvas.drawPath(collarPath, collarPaint);

    // Bell on collar
    final bellFill = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(50, 58), 5, bellFill);
    canvas.drawCircle(const Offset(50, 58), 5, gold..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Chinese Pattern Divider ────────────────────────────────────────────────────
class ChineseDivider extends StatelessWidget {
  const ChineseDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: AppColors.border, thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: CustomPaint(
            size: const Size(20, 20),
            painter: _LanternPainter(),
          ),
        ),
        const Expanded(
          child: Divider(color: AppColors.border, thickness: 1),
        ),
      ],
    );
  }
}

class _LanternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.fill;

    // Simple diamond / rhombus shape (traditional Chinese pattern element)
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height / 2)
      ..close();
    canvas.drawPath(path, paint);

    // Inner diamond
    final innerPaint = Paint()
      ..color = AppColors.background
      ..style = PaintingStyle.fill;
    final innerPath = Path()
      ..moveTo(size.width / 2, size.height * 0.25)
      ..lineTo(size.width * 0.75, size.height / 2)
      ..lineTo(size.width / 2, size.height * 0.75)
      ..lineTo(size.width * 0.25, size.height / 2)
      ..close();
    canvas.drawPath(innerPath, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Corner Decorations — Traditional Chinese ────────────────────────────────
class ChineseCornerDecoration extends StatelessWidget {
  final double size;
  final bool flipH;
  final bool flipV;

  const ChineseCornerDecoration({
    super.key,
    this.size = 60,
    this.flipH = false,
    this.flipV = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget corner = CustomPaint(
      size: Size(size, size),
      painter: _CornerPainter(),
    );

    if (flipH || flipV) {
      corner = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..scale(flipH ? -1.0 : 1.0, flipV ? -1.0 : 1.0),
        child: corner,
      );
    }

    return corner;
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final s = size.width;

    // Outer L-bracket
    final outer = Path()
      ..moveTo(s * 0.1, s * 0.6)
      ..lineTo(s * 0.1, s * 0.1)
      ..lineTo(s * 0.6, s * 0.1);
    canvas.drawPath(outer, paint);

    // Inner decorative arc
    canvas.drawArc(
      Rect.fromLTWH(s * 0.15, s * 0.15, s * 0.35, s * 0.35),
      3.14 * 1, // start
      3.14 * 0.5, // sweep
      false,
      paint,
    );

    // Dot accent
    final dotPaint = Paint()
      ..color = AppColors.gold.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(s * 0.1, s * 0.1), 3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Primary Button ─────────────────────────────────────────────────────────────
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isSmall;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: onPressed != null ? AppShadows.goldGlow : [],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
          foregroundColor: AppColors.textOnDark,
          minimumSize: Size(double.infinity, isSmall ? 44 : 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: isLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: AppColors.textOnDark,
            strokeWidth: 2.5,
          ),
        )
            : Text(
          label,
          style: GoogleFonts.karla(
            fontSize: isSmall ? 13 : 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.textOnDark,
          ),
        ),
      ),
    );
  }
}

// ─── Gold outlined button ────────────────────────────────────────────────────
class GoldOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const GoldOutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.gold, width: 1.5),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
      child: isLoading
          ? const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      )
          : Text(
        label,
        style: GoogleFonts.karla(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ─── App TextField ────────────────────────────────────────────────────────────
class AppTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final TextInputAction textInputAction;
  final FocusNode? focusNode;
  final Widget? prefixIcon;
  final bool autofocus;
  final int? maxLength;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    required this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
    this.focusNode,
    this.prefixIcon,
    this.autofocus = false,
    this.maxLength,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.isPassword && _obscured,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      maxLength: widget.maxLength,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: GoogleFonts.karla(
        fontSize: 15,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.prefixIcon != null
            ? Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: widget.prefixIcon,
        )
            : null,
        prefixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        suffixIcon: widget.isPassword
            ? GestureDetector(
          onTap: () => setState(() => _obscured = !_obscured),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              _obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.textMuted,
              size: 20,
            ),
          ),
        )
            : null,
        counterText: '', // hide maxLength counter
      ),
      onChanged: widget.onChanged,
      validator: widget.validator,
    );
  }
}

// ─── Status Banner ─────────────────────────────────────────────────────────────
class StatusBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const StatusBanner({
    super.key,
    required this.message,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: isError
            ? AppColors.error.withOpacity(0.08)
            : AppColors.gold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isError ? AppColors.error.withOpacity(0.3) : AppColors.gold.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            color: isError ? AppColors.error : AppColors.gold,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.karla(
                fontSize: 13,
                color: isError ? AppColors.error : AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Lantern Loader ─────────────────────────────────────────────────────────────
// Minimalist page-level loading state
class LanternLoader extends StatelessWidget {
  const LanternLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.gold,
        strokeWidth: 3,
      ),
    );
  }
}

// ─── Food thumbnail ───────────────────────────────────────────────────────────
// Reusable rounded food image with graceful placeholder + "sold out" overlay.
class FoodThumb extends StatelessWidget {
  final String? url;
  final double size;
  final bool isUnavailable;
  final double radius;

  const FoodThumb({
    super.key,
    required this.url,
    this.size = 64,
    this.isUnavailable = false,
    this.radius = AppRadius.md,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surfaceWarm,
          border: Border.all(
            color: isUnavailable
                ? AppColors.error.withOpacity(0.4)
                : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _image(),
            if (isUnavailable)
              Container(
                color: Colors.black.withOpacity(0.45),
                alignment: Alignment.center,
                child: const Icon(Icons.block_rounded,
                    color: Colors.white, size: 22),
              ),
          ],
        ),
      ),
    );
  }

  Widget _image() {
    if (url != null && url!.isNotEmpty) {
      return Image.network(
        url!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _ph(),
      );
    }
    return _ph();
  }

  Widget _ph() => Container(
    color: AppColors.surfaceWarm,
    alignment: Alignment.center,
    child: Icon(Icons.ramen_dining_rounded,
        color: AppColors.gold, size: size * 0.4),
  );
}