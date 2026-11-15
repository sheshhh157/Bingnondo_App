import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/auth_provider.dart';
import 'services/menu_provider.dart';
import 'services/chatbot_provider.dart';
import 'services/cart_provider.dart';
import 'services/order_tracking_provider.dart';
import 'services/support_chat_provider.dart';
import 'services/orders_provider.dart';
import 'services/notifications_provider.dart';
import 'services/account_settings_provider.dart';
import 'services/business_hours_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/app_widgets.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/main_shell.dart';
import 'screens/notifications/notifications_screen.dart';
import 'services/push_notification_service.dart';

const MethodChannel _startupSplashChannel = MethodChannel(
  'bingnondo/startup_splash',
);
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService.instance.initialize();

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
        // Business hours — drives the Open/Closed pill + order gating
        ChangeNotifierProvider(create: (_) => BusinessHoursProvider()..start()),
        ChangeNotifierProvider(create: (_) => ChatbotProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OrderTrackingProvider()),
        ChangeNotifierProvider(create: (_) => SupportChatProvider()),
        ChangeNotifierProvider(create: (_) => OrdersProvider()),
        // §1.8
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
        // §1.9
        ChangeNotifierProvider(create: (_) => AccountSettingsProvider()),
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
      navigatorKey: _rootNavigatorKey,
      home: const _StartupRouter(),
    );
  }
}

class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  AuthProvider? _authProvider;
  bool _nativeSplashDismissRequested = false;
  bool _pendingNotificationNavigation = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PushNotificationService.instance.setNotificationTapHandler(
      _openNotificationsFromPush,
    );
    final authProvider = context.read<AuthProvider>();
    if (_authProvider != authProvider) {
      _authProvider?.removeListener(_onAuthChanged);
      _authProvider = authProvider..addListener(_onAuthChanged);
    }
    _dismissNativeSplashWhenReady(authProvider);
  }

  void _onAuthChanged() {
    final authProvider = _authProvider;
    if (authProvider != null) {
      _dismissNativeSplashWhenReady(authProvider);
      if (_pendingNotificationNavigation &&
          authProvider.status == AuthStatus.authenticated) {
        _pendingNotificationNavigation = false;
        _openNotificationsFromPush();
      }
    }
  }

  void _openNotificationsFromPush() {
    if (_authProvider?.status != AuthStatus.authenticated) {
      _pendingNotificationNavigation = true;
      return;
    }

    final navigator = _rootNavigatorKey.currentState;
    if (navigator == null) {
      _pendingNotificationNavigation = true;
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
  }

  void _dismissNativeSplashWhenReady(AuthProvider authProvider) {
    if (!Platform.isAndroid ||
        authProvider.status == AuthStatus.initial ||
        _nativeSplashDismissRequested) {
      return;
    }

    _nativeSplashDismissRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startupSplashChannel.invokeMethod<void>('hide');
      }
    });
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthChanged);
    PushNotificationService.instance.setNotificationTapHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    switch (auth.status) {
      case AuthStatus.initial:
        return const _SplashScreen();
      case AuthStatus.authenticated:
        return const MainShell();
      case AuthStatus.awaitingVerification:
        return const SignUpScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}

// ─── Splash Screen ─────────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final catSize = (constraints.maxHeight * 0.15)
                .clamp(48.0, 88.0)
                .toDouble();
            final barWidth = (constraints.maxWidth * 0.7)
                .clamp(0.0, 240.0)
                .toDouble();

            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BrandCatIcon(size: catSize),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: barWidth,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        minHeight: 5,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
