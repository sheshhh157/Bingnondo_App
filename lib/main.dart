import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/auth_provider.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait by default (standard mobile experience)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const BingnondoApp(),
    ),
  );
}

class BingnondoApp extends StatelessWidget {
  const BingnondoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bingnondo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,

      // Auth-aware routing
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          switch (auth.status) {
            case AuthStatus.initial:
            // Splash / loading while checking stored token
              return const _SplashScreen();

            case AuthStatus.authenticated:
            // TODO: Replace with HomeScreen / MenuScreen once built
              return const _PlaceholderHomeScreen();

            case AuthStatus.awaitingVerification:
            // User registered but needs OTP — handled by SignUpScreen navigation
              return const SignUpScreen();

            case AuthStatus.unauthenticated:
              return const LoginScreen();
          }
        },
      ),
    );
  }
}

// ─── Splash Screen ─────────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SplashCat(),
            const SizedBox(height: AppSpacing.lg),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: AppColors.gold,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashCat extends StatefulWidget {
  const _SplashCat();

  @override
  State<_SplashCat> createState() => _SplashCatState();
}

class _SplashCatState extends State<_SplashCat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Column(
        children: [
          const _BrandLogoText(),
          const SizedBox(height: AppSpacing.xl),
          // Updated to use image asset
          Image.asset(
            'assets/images/lucky_cat.png',
            width: 80,
            height: 80,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return CustomPaint(
                size: const Size(80, 80),
                painter: _SplashCatPainter(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BrandLogoText extends StatelessWidget {
  const _BrandLogoText();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Bingnondo',
          style: TextStyle(
            fontFamily: 'Playfair Display SC',
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: AppColors.textOnDark,
            letterSpacing: 2,
          ),
        ),
        Text(
          'CAFE',
          style: TextStyle(
            fontFamily: 'Karla',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.gold,
            letterSpacing: 6,
          ),
        ),
      ],
    );
  }
}

class _SplashCatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = AppColors.gold.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final s = size.width / 100;
    canvas.scale(s, s);

    // Body
    final body = Path()
      ..moveTo(20, 95)
      ..lineTo(15, 60)
      ..quadraticBezierTo(10, 30, 30, 20)
      ..quadraticBezierTo(50, 10, 70, 20)
      ..quadraticBezierTo(90, 30, 85, 60)
      ..lineTo(80, 95)
      ..close();
    canvas.drawPath(body, fill);
    canvas.drawPath(body, stroke);

    // Head
    final head = Path()..addOval(const Rect.fromLTWH(22, 5, 56, 50));
    canvas.drawPath(head, fill);
    canvas.drawPath(head, stroke);

    // Ears
    final lEar = Path()..moveTo(25, 22)..lineTo(18, 5)..lineTo(35, 12)..close();
    final rEar = Path()..moveTo(75, 22)..lineTo(82, 5)..lineTo(65, 12)..close();
    canvas.drawPath(lEar, fill);
    canvas.drawPath(lEar, stroke);
    canvas.drawPath(rEar, fill);
    canvas.drawPath(rEar, stroke);

    // Eyes
    final eye = Paint()..color = AppColors.gold..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round;
    canvas.drawPath(Path()..moveTo(35, 30)..quadraticBezierTo(38, 35, 41, 30), eye);
    canvas.drawPath(Path()..moveTo(59, 30)..quadraticBezierTo(62, 35, 65, 30), eye);

    // Raised paw
    final paw = Path()
      ..moveTo(75, 40)
      ..quadraticBezierTo(90, 20, 88, 10)
      ..quadraticBezierTo(85, 3, 78, 7)
      ..quadraticBezierTo(72, 3, 65, 10)
      ..quadraticBezierTo(60, 20, 72, 38)
      ..close();
    canvas.drawPath(paw, fill);
    canvas.drawPath(paw, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Placeholder Home Screen ───────────────────────────────────────────────────
// Temporary — will be replaced by MenuScreen (Section 1.3)
class _PlaceholderHomeScreen extends StatelessWidget {
  const _PlaceholderHomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.restaurant_menu_rounded,
              color: AppColors.gold,
              size: 64,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Welcome to Bingnondo!',
              style: AppTextStyles.display2(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Menu screen coming next.',
              style: AppTextStyles.bodyMedium(context),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextButton(
              onPressed: () async {
                await context.read<AuthProvider>().logout();
              },
              child: Text('Sign out', style: AppTextStyles.link(context)),
            ),
          ],
        ),
      ),
    );
  }
}