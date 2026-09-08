import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/menu_models.dart';
import '../../services/menu_provider.dart';
import '../../services/cart_provider.dart';
import '../../services/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../chatbot/chatbot_screen.dart';
import '../cart/cart_screen.dart';

class HomeMenuScreen extends StatefulWidget {
  const HomeMenuScreen({super.key});

  @override
  State<HomeMenuScreen> createState() => _HomeMenuScreenState();
}

class _HomeMenuScreenState extends State<HomeMenuScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  late AnimationController _fabPulseController;
  late Animation<double> _fabPulse;

  // Cart badge bounce
  late AnimationController _badgeBounceCtrl;
  late Animation<double> _badgeBounce;
  int _prevCartCount = 0;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 1, vsync: this);

    _fabPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _fabPulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _fabPulseController, curve: Curves.easeInOut),
    );

    _badgeBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _badgeBounce = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _badgeBounceCtrl, curve: Curves.easeOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MenuProvider>().loadMenu().then((_) => _rebuildTabs());
    });
  }

  void _rebuildTabs() {
    final cats = context.read<MenuProvider>().categories;
    if (!mounted || cats.isEmpty) return;
    setState(() {
      _tabController.dispose();
      _tabController = TabController(length: cats.length, vsync: this);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fabPulseController.dispose();
    _badgeBounceCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleAddToCart(MenuItem item) {
    context.read<CartProvider>().addItem(item);

    // Bounce badge animation
    final newCount = context.read<CartProvider>().totalItemCount;
    if (newCount > _prevCartCount) {
      _badgeBounceCtrl.forward(from: 0);
      _prevCartCount = newCount;
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} added to cart',
            style: GoogleFonts.karla(fontSize: 13)),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        action: SnackBarAction(
          label: 'View Cart',
          textColor: AppColors.gold,
          onPressed: () => _goToCart(),
        ),
      ),
    );
  }

  void _goToCart() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => const CartScreen(),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<MenuProvider>(
        builder: (context, menuProvider, _) {
          return NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (context, innerBoxScrolled) => [
              _buildSliverAppBar(context, menuProvider, innerBoxScrolled),
            ],
            body: _buildBody(context, menuProvider),
          );
        },
      ),
      floatingActionButton: _buildChatbotFab(context),
    );
  }

  // ─── Sliver AppBar ─────────────────────────────────────────────────────────
  Widget _buildSliverAppBar(
      BuildContext context,
      MenuProvider menuProvider,
      bool innerBoxScrolled,
      ) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      floating: false,
      backgroundColor: AppColors.primaryDark,
      elevation: 0,
      scrolledUnderElevation: 2,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: _buildHeroBanner(context),
      ),
      bottom: menuProvider.isLoaded && menuProvider.categories.isNotEmpty
          ? PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: _buildCategoryTabBar(menuProvider),
      )
          : null,
      actions: [
        // Cart icon with badge
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Consumer<CartProvider>(
            builder: (context, cart, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: CustomPaint(
                      size: const Size(24, 24),
                      painter: _CartIconPainter(),
                    ),
                    onPressed: _goToCart,
                    tooltip: 'Cart',
                  ),
                  if (cart.totalItemCount > 0)
                    Positioned(
                      top: 8,
                      right: 6,
                      child: ScaleTransition(
                        scale: _badgeBounce,
                        child: Container(
                          width: 17,
                          height: 17,
                          decoration: const BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${cart.totalItemCount > 99 ? '99+' : cart.totalItemCount}',
                              style: GoogleFonts.karla(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        // Profile
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => _showProfileMenu(context),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.textOnDark.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.gold.withOpacity(0.5), width: 1.5),
              ),
              child: const Icon(Icons.person_outline_rounded,
                  color: AppColors.textOnDark, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroBanner(BuildContext context) {
    return Container(
      color: AppColors.primaryDark,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
              top: 8, left: 8, child: ChineseCornerDecoration(size: 44)),
          const Positioned(
              top: 8,
              right: 8,
              child: ChineseCornerDecoration(size: 44, flipH: true)),
          const Positioned(
              bottom: 48,
              left: 8,
              child: ChineseCornerDecoration(size: 36, flipV: true)),
          const Positioned(
              bottom: 48,
              right: 8,
              child: ChineseCornerDecoration(size: 36, flipH: true, flipV: true)),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: const Size(double.infinity, 32),
              painter: _LanternRowPainter(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 36, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                BrandCatIcon(size: 64),
                const SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bingnondo',
                      style: GoogleFonts.playfairDisplaySc(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textOnDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Authentic Binondo Cafe',
                      style: GoogleFonts.karla(
                        fontSize: 12,
                        color: AppColors.textOnDark.withOpacity(0.65),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.2),
                        borderRadius:
                        BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                            color: AppColors.gold.withOpacity(0.5), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                                color: AppColors.gold, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Open Now',
                            style: GoogleFonts.karla(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabBar(MenuProvider menuProvider) {
    return Container(
      color: AppColors.primaryDark,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: AppColors.gold,
        unselectedLabelColor: AppColors.textOnDark.withOpacity(0.55),
        indicatorColor: AppColors.gold,
        indicatorWeight: 2.5,
        dividerColor: Colors.transparent,
        labelStyle: GoogleFonts.karla(
            fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.3),
        unselectedLabelStyle:
        GoogleFonts.karla(fontSize: 13, fontWeight: FontWeight.w400),
        tabs: menuProvider.categories.map((cat) => Tab(text: cat.name)).toList(),
      ),
    );
  }

  // ─── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody(BuildContext context, MenuProvider menuProvider) {
    switch (menuProvider.state) {
      case MenuLoadState.loading:
      case MenuLoadState.initial:
        return _buildSkeletonList();
      case MenuLoadState.error:
        return _buildErrorState(context, menuProvider);
      case MenuLoadState.loaded:
        if (menuProvider.categories.isEmpty) {
          return const Center(child: _LanternEmpty());
        }
        return TabBarView(
          controller: _tabController,
          children: menuProvider.categories.map((cat) {
            final items = menuProvider.itemsForCategory(cat.id);
            return _buildCategoryContent(context, items);
          }).toList(),
        );
    }
  }

  Widget _buildCategoryContent(BuildContext context, List<MenuItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _LanternEmpty(),
            const SizedBox(height: AppSpacing.md),
            Text('Nothing here yet.', style: AppTextStyles.bodyMedium(context)),
          ],
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    if (width >= 600) return _buildMenuGrid(context, items);
    return _buildMenuList(context, items);
  }

  Widget _buildMenuList(BuildContext context, List<MenuItem> items) {
    return RefreshIndicator(
      onRefresh: () => context.read<MenuProvider>().refresh(),
      color: AppColors.gold,
      backgroundColor: AppColors.background,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, i) => MenuItemCard(
          item: items[i],
          onTap: () => _showItemDetail(context, items[i]),
        ),
      ),
    );
  }

  Widget _buildMenuGrid(BuildContext context, List<MenuItem> items) {
    final crossCount = MediaQuery.of(context).size.width >= 900 ? 3 : 2;
    return RefreshIndicator(
      onRefresh: () => context.read<MenuProvider>().refresh(),
      color: AppColors.gold,
      backgroundColor: AppColors.background,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossCount,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          childAspectRatio: 0.78,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) => MenuItemGridCard(
          item: items[i],
          onTap: () => _showItemDetail(context, items[i]),
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, __) => const _MenuItemSkeleton(),
    );
  }

  Widget _buildErrorState(BuildContext context, MenuProvider menuProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: AppColors.textMuted, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text('Could not load menu',
                style: AppTextStyles.headline(context),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(menuProvider.errorMessage ?? 'Please try again.',
                style: AppTextStyles.bodyMedium(context),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'TRY AGAIN',
              onPressed: menuProvider.refresh,
              isSmall: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatbotFab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ScaleTransition(
        scale: _fabPulse,
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, anim, __) => const ChatbotScreen(),
              transitionsBuilder: (_, anim, __, child) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                    parent: anim, curve: Curves.easeOutCubic)),
                child: child,
              ),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          ),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 2),
              boxShadow: AppShadows.goldGlow,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/images/ndo_bot.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return CustomPaint(
                        size: const Size(32, 32),
                        painter: _MiniFabCatPainter(),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: AppColors.gold, shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showItemDetail(BuildContext context, MenuItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MenuItemDetailSheet(
        item: item,
        onAddToCart: () => _handleAddToCart(item),
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProfileSheet(
        onLogout: () async {
          Navigator.pop(context);
          await context.read<AuthProvider>().logout();
        },
      ),
    );
  }
}

// ─── Menu Item Cards ───────────────────────────────────────────────────────────
// (identical to previous version but onTap now correctly passed through)

class MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onTap;
  const MenuItemCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.isAvailable ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: item.isAvailable ? 1.0 : 0.55,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(AppRadius.lg),
                ),
                child: _FoodImageWidget(
                    url: item.photoUrl, width: 100, height: 100),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: GoogleFonts.playfairDisplaySc(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _AvailabilityBadge(isAvailable: item.isAvailable),
                        ],
                      ),
                      if (item.description != null) ...[
                        const SizedBox(height: 4),
                        Text(item.description!,
                            style: AppTextStyles.bodySmall(context),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₱${item.price.toStringAsFixed(2)}',
                            style: GoogleFonts.playfairDisplaySc(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          if (item.isAvailable)
                            GestureDetector(
                              onTap: onTap,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Text(
                                  '+ Add',
                                  style: GoogleFonts.karla(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textOnDark,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MenuItemGridCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onTap;
  const MenuItemGridCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.isAvailable ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: item.isAvailable ? 1.0 : 0.55,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg),
                  topRight: Radius.circular(AppRadius.lg),
                ),
                child: Stack(
                  children: [
                    _FoodImageWidget(
                        url: item.photoUrl,
                        width: double.infinity,
                        height: 130),
                    Positioned(
                        top: 8,
                        right: 8,
                        child:
                        _AvailabilityBadge(isAvailable: item.isAvailable)),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm + 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: GoogleFonts.playfairDisplaySc(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₱${item.price.toStringAsFixed(0)}',
                            style: GoogleFonts.playfairDisplaySc(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          if (item.isAvailable)
                            GestureDetector(
                              onTap: onTap,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                                ),
                                child: const Icon(Icons.add_rounded,
                                    color: AppColors.textOnDark, size: 16),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Menu Item Detail Sheet ────────────────────────────────────────────────────
class MenuItemDetailSheet extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onAddToCart;
  const MenuItemDetailSheet(
      {super.key, required this.item, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * 0.65,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill)),
            ),
          ),
          ClipRRect(
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            child: _FoodImageWidget(
                url: item.photoUrl, width: double.infinity, height: 200),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child:
                          Text(item.name, style: AppTextStyles.display2(context))),
                      const SizedBox(width: 12),
                      _AvailabilityBadge(isAvailable: item.isAvailable),
                    ],
                  ),
                  if (item.description != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(item.description!,
                        style: AppTextStyles.bodyMedium(context)),
                  ],
                  const Spacer(),
                  Text(
                    '₱${item.price.toStringAsFixed(2)}',
                    style: GoogleFonts.playfairDisplaySc(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: item.isAvailable ? 'ADD TO CART' : 'UNAVAILABLE',
                    onPressed: item.isAvailable
                        ? () {
                      Navigator.pop(context);
                      onAddToCart();
                    }
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Availability Badge ────────────────────────────────────────────────────────
class _AvailabilityBadge extends StatelessWidget {
  final bool isAvailable;
  const _AvailabilityBadge({required this.isAvailable});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isAvailable
            ? AppColors.success.withOpacity(0.12)
            : AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: isAvailable
              ? AppColors.success.withOpacity(0.4)
              : AppColors.error.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
                color: isAvailable ? AppColors.success : AppColors.error,
                shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            isAvailable ? 'Available' : 'Sold out',
            style: GoogleFonts.karla(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isAvailable ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Food Image Widget ─────────────────────────────────────────────────────────
class _FoodImageWidget extends StatelessWidget {
  final String? url;
  final double width;
  final double height;
  const _FoodImageWidget(
      {required this.url, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return Image.network(url!, width: width, height: height,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder());
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        color: AppColors.surfaceWarm,
        child: Center(
          child: CustomPaint(
              size: const Size(40, 40), painter: _FoodBowlPainter()),
        ),
      ),
    );
  }
}

// ─── Profile Sheet ─────────────────────────────────────────────────────────────
class _ProfileSheet extends StatelessWidget {
  final VoidCallback onLogout;
  const _ProfileSheet({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill)),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Account', style: AppTextStyles.display2(context)),
          const SizedBox(height: AppSpacing.lg),
          const ChineseDivider(),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            leading: const Icon(Icons.person_outline_rounded,
                color: AppColors.gold),
            title: Text('Complete Profile',
                style: AppTextStyles.bodyLarge(context)),
            subtitle: Text('Add your name & address',
                style: AppTextStyles.bodySmall(context)),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to complete profile
            },
          ),
          ListTile(
            leading:
            const Icon(Icons.settings_outlined, color: AppColors.gold),
            title: Text('Account Settings',
                style: AppTextStyles.bodyLarge(context)),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to account settings (§1.9)
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          GoldOutlineButton(label: 'SIGN OUT', onPressed: onLogout),
        ],
      ),
    );
  }
}

// ─── Skeleton loader ───────────────────────────────────────────────────────────
class _MenuItemSkeleton extends StatefulWidget {
  const _MenuItemSkeleton();
  @override
  State<_MenuItemSkeleton> createState() => _MenuItemSkeletonState();
}

class _MenuItemSkeletonState extends State<_MenuItemSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final color = Color.lerp(
            const Color(0xFFEFEBE4), const Color(0xFFDDD8CF), _anim.value)!;
        return Container(
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.lg),
                    bottomLeft: Radius.circular(AppRadius.lg),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(
                          height: 14,
                          width: 120,
                          decoration: BoxDecoration(
                              color: color,
                              borderRadius:
                              BorderRadius.circular(AppRadius.sm))),
                      Container(
                          height: 10,
                          width: 180,
                          decoration: BoxDecoration(
                              color: color,
                              borderRadius:
                              BorderRadius.circular(AppRadius.sm))),
                      Container(
                          height: 10,
                          width: 90,
                          decoration: BoxDecoration(
                              color: color,
                              borderRadius:
                              BorderRadius.circular(AppRadius.sm))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Painters ──────────────────────────────────────────────────────────────────
class _CartIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.textOnDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(2, 2)
      ..lineTo(5, 2)
      ..lineTo(8, 16)
      ..lineTo(20, 16)
      ..lineTo(22, 6)
      ..lineTo(6, 6);
    canvas.drawPath(path, p);
    final dot = Paint()..color = AppColors.textOnDark..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(9, 20), 2, dot);
    canvas.drawCircle(const Offset(18, 20), 2, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FoodBowlPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.gold.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(
        Rect.fromLTWH(
            2, size.height * 0.35, size.width - 4, size.height * 0.5),
        p);
    canvas.drawLine(Offset(size.width * 0.2, size.height * 0.35),
        Offset(size.width * 0.8, size.height * 0.35), p);
    canvas.drawArc(
        Rect.fromLTWH(size.width * 0.25, 0, size.width * 0.5,
            size.height * 0.4),
        3.14 * 1.1, 3.14 * 0.8, false, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LanternRowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.gold.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    final spacing = size.width / 6;
    for (int i = 0; i < 6; i++) {
      final cx = spacing * i + spacing / 2;
      final path = Path()
        ..moveTo(cx, 0)
        ..lineTo(cx, size.height * 0.25)
        ..moveTo(cx - 8, size.height * 0.2)
        ..quadraticBezierTo(cx, size.height * 0.7, cx + 8, size.height * 0.2)
        ..close();
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LanternEmpty extends StatelessWidget {
  const _LanternEmpty();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
        size: const Size(60, 84), painter: _SingleLanternPainter(opacity: 0.3));
  }
}

class _SingleLanternPainter extends CustomPainter {
  final double opacity;
  const _SingleLanternPainter({this.opacity = 1.0});
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = AppColors.gold.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final w = size.width;
    final h = size.height;
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h * 0.1), stroke);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.15, h * 0.08, w * 0.7, h * 0.1),
            const Radius.circular(3)),
        fill..color = AppColors.gold.withOpacity(opacity));
    final body = Path()
      ..moveTo(w * 0.05, h * 0.2)
      ..quadraticBezierTo(0, h * 0.5, w * 0.05, h * 0.78)
      ..lineTo(w * 0.95, h * 0.78)
      ..quadraticBezierTo(w, h * 0.5, w * 0.95, h * 0.2)
      ..close();
    canvas.drawPath(
        body, fill..color = AppColors.primaryDark.withOpacity(opacity));
    canvas.drawPath(body, stroke);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.15, h * 0.76, w * 0.7, h * 0.08),
            const Radius.circular(3)),
        fill..color = AppColors.gold.withOpacity(opacity));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniFabCatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = AppColors.gold..style = PaintingStyle.fill;
    final s = size.width / 32;
    canvas.scale(s, s);
    canvas.drawOval(const Rect.fromLTWH(6, 8, 20, 18),
        fill..color = AppColors.gold.withOpacity(0.7));
    canvas.drawPath(
        Path()..moveTo(8, 14)..lineTo(5, 6)..lineTo(13, 11)..close(), fill);
    canvas.drawPath(
        Path()..moveTo(24, 14)..lineTo(27, 6)..lineTo(19, 11)..close(), fill);
    final eye = Paint()
      ..color = AppColors.primaryDark
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(13, 14), const Offset(13, 17), eye);
    canvas.drawLine(const Offset(19, 14), const Offset(19, 17), eye);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}