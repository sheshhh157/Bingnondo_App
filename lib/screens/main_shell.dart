import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../services/cart_provider.dart';
import '../services/chatbot_provider.dart';
import '../theme/app_theme.dart';
import 'menu/home_menu_screen.dart';
import 'cart/cart_screen.dart';
import 'orders/my_orders_screen.dart';
import 'settings/account_settings_screen.dart';
import 'chatbot/chatbot_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with TickerProviderStateMixin {
  int _currentIndex = 0;

  late AnimationController _badgeBounceCtrl;
  late Animation<double> _badgeBounce;
  int _prevCartCount = 0;

  // IndexedStack keeps all screens alive — no rebuild on tab switch
  final List<Widget> _screens = const [
    HomeMenuScreen(),
    CartScreen(),
    MyOrdersScreen(),
    AccountSettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _badgeBounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _badgeBounce = TweenSequence([
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.35), weight: 40),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.35, end: 0.85), weight: 30),
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.85, end: 1.0), weight: 30),
    ]).animate(
        CurvedAnimation(parent: _badgeBounceCtrl, curve: Curves.easeOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cart = context.watch<CartProvider>();
    if (cart.totalItemCount > _prevCartCount) {
      _badgeBounceCtrl.forward(from: 0);
    }
    _prevCartCount = cart.totalItemCount;
  }

  @override
  void dispose() {
    _badgeBounceCtrl.dispose();
    super.dispose();
  }

  void _goToChatbot() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => const ChatbotScreen(),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
              begin: const Offset(0, 1), end: Offset.zero)
              .animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      // extendBody so the screen content draws behind the nav
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildNav(context),
    );
  }

  Widget _buildNav(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        border: Border(
          top: BorderSide(color: AppColors.goldMuted, width: 1.5),
        ),
      ),
      child: Row(
        children: [
          // Home
          Expanded(
            child: _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              active: _currentIndex == 0,
              onTap: () => setState(() => _currentIndex = 0),
            ),
          ),
          // Orders
          Expanded(
            child: _NavItem(
              icon: Icons.receipt_long_rounded,
              label: 'Orders',
              active: _currentIndex == 2,
              onTap: () => setState(() => _currentIndex = 2),
            ),
          ),
          // Cart
          Expanded(
            child: Consumer<CartProvider>(
              builder: (_, cart, __) => GestureDetector(
                onTap: () => setState(() => _currentIndex = 1),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            Icons.shopping_cart_rounded,
                            color: _currentIndex == 1
                                ? AppColors.primaryDark
                                : AppColors.textSecondary.withOpacity(0.55),
                            size: 34,
                          ),
                          if (cart.totalItemCount > 0)
                            Positioned(
                              top: -4,
                              right: -6,
                              child: AnimatedBuilder(
                                animation: _badgeBounce,
                                builder: (_, __) => Transform.scale(
                                  scale: _badgeBounce.value,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: AppColors.gold,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: AppColors.background,
                                          width: 1.5),
                                    ),
                                    child: Center(
                                      child: Text(
                                        cart.totalItemCount > 9
                                            ? '9+'
                                            : '${cart.totalItemCount}',
                                        style: const TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cart',
                        style: TextStyle(
                          fontFamily: 'Karla',
                          fontSize: 9,
                          fontWeight: _currentIndex == 1
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _currentIndex == 1
                              ? AppColors.primaryDark
                              : AppColors.textSecondary.withOpacity(0.55),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Ndo Bot — pushes to chatbot, no tab index
          Expanded(
            child: _NdoBotNavItem(onTap: _goToChatbot),
          ),
          // Account
          Expanded(
            child: _NavItem(
              icon: Icons.person_rounded,
              label: 'Account',
              active: _currentIndex == 3,
              onTap: () => setState(() => _currentIndex = 3),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Nav Item ────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? AppColors.primaryDark
        : AppColors.textSecondary.withOpacity(0.55);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 34),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Karla',
                fontSize: 9,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            if (active)
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.primaryDark,
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ─── Ndo Bot Nav Item (custom SVG icon) ──────────────────────────────────────
class _NdoBotNavItem extends StatelessWidget {
  final VoidCallback onTap;
  const _NdoBotNavItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/images/ndo_bot.svg',
              width: 36,
              height: 36,
            ),
            const SizedBox(height: 2),
            Text(
              'Ndo Bot',
              style: TextStyle(
                fontFamily: 'Karla',
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary.withOpacity(0.55),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}