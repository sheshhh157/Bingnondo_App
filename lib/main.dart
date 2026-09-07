import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/auth_provider.dart';
import 'services/menu_provider.dart';
import 'services/chatbot_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/app_widgets.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/menu/home_menu_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MenuProvider()),
        ChangeNotifierProvider(create: (_) => ChatbotProvider()),
      ],
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
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          switch (auth.status) {
            case AuthStatus.initial:
              return const _SplashScreen();

            case AuthStatus.authenticated:
              return const HomeMenuScreen();

            case AuthStatus.awaitingVerification:
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
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _fade = Tween<double>(begin: 0.7, end: 1.0).animate(
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
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Stack(
        children: [
          // Corner decorations
          Positioned(
              top: 24, left: 24, child: ChineseCornerDecoration(size: 60)),
          Positioned(
              top: 24,
              right: 24,
              child: ChineseCornerDecoration(size: 60, flipH: true)),
          Positioned(
              bottom: 24,
              left: 24,
              child: ChineseCornerDecoration(size: 60, flipV: true)),
          Positioned(
              bottom: 24,
              right: 24,
              child: ChineseCornerDecoration(size: 60, flipH: true, flipV: true)),

          Center(
            child: ScaleTransition(
              scale: _scale,
              child: FadeTransition(
                opacity: _fade,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BrandCatIcon(size: 96),
                    const SizedBox(height: AppSpacing.lg),
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
                    const SizedBox(height: 4),
                    Text(
                      'C A F E',
                      style: TextStyle(
                        fontFamily: 'Karla',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gold,
                        letterSpacing: 8,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: AppColors.gold,
                        strokeWidth: 2.5,
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
}