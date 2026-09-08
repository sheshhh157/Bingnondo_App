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

  // How much the hero has collapsed (0.0 = expanded, 1.0 = fully collapsed)
  double _collapseRatio = 0.0;

  // Heights
  static const double _expandedHeaderH = 140.0;
  static const double _collapsedHeaderH = 64.0;
  static const double _tabBarH = 48.0;
  static const double _scrollTriggerH = _expandedHeaderH - _collapsedHeaderH;

  // Fab pulse
  late AnimationController _fabPulseCtrl;
  late Animation<double> _fabPulse;

  // Cart badge bounce
  late AnimationController _badgeBounceCtrl;
  late Animation<double> _badgeBounce;
  int _prevCartCount = 0;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 1, vsync: this);

    _fabPulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _fabPulse = Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: _fabPulseCtrl, curve: Curves.easeInOut));

    _badgeBounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _badgeBounce = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 1),
    ]).animate(
        CurvedAnimation(parent: _badgeBounceCtrl, curve: Curves.easeOut));

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MenuProvider>().loadMenu().then((_) => _rebuildTabs());
    });
  }

  void _onScroll() {
    final offset = _scrollController.offset.clamp(0.0, _scrollTriggerH);
    final ratio = offset / _scrollTriggerH;
    if ((ratio - _collapseRatio).abs() > 0.01) {
      setState(() => _collapseRatio = ratio);
    }
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
    _fabPulseCtrl.dispose();
    _badgeBounceCtrl.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _handleAddToCart(MenuItem item) {
    context.read<CartProvider>().addItem(item);
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
          onPressed: _goToCart,
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
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
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
          return Column(
            children: [
              // ── Persistent header (always visible, morphs on scroll) ──────
              _PersistentHeader(
                collapseRatio: _collapseRatio,
                expandedHeight: _expandedHeaderH,
                collapsedHeight: _collapsedHeaderH,
                badgeBounce: _badgeBounce,
                onCartTap: _goToCart,
                onProfileTap: () => _showProfileMenu(context),
              ),

              // ── Category tab bar (pinned, always visible) ─────────────────
              if (menuProvider.isLoaded && menuProvider.categories.isNotEmpty)
                _CategoryTabBar(
                  controller: _tabController,
                  categories: menuProvider.categories,
                ),

              // ── Scrollable menu content ───────────────────────────────────
              Expanded(
                child: _buildBody(context, menuProvider),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  // ─── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody(BuildContext context, MenuProvider menuProvider) {
    switch (menuProvider.state) {
      case MenuLoadState.loading:
      case MenuLoadState.initial:
        return _buildSkeleton();
      case MenuLoadState.error:
        return _buildErrorState(context, menuProvider);
      case MenuLoadState.loaded:
        if (menuProvider.categories.isEmpty) return const _EmptyMenuState();
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const _LanternEmpty(),
          const SizedBox(height: AppSpacing.md),
          Text('Nothing here yet.', style: AppTextStyles.bodyMedium(context)),
        ]),
      );
    }
    final width = MediaQuery.of(context).size.width;
    if (width >= 600) return _buildGrid(context, items);
    return _buildList(context, items);
  }

  Widget _buildList(BuildContext context, List<MenuItem> items) {
    return RefreshIndicator(
      onRefresh: () => context.read<MenuProvider>().refresh(),
      color: AppColors.gold,
      backgroundColor: AppColors.background,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (ctx, i) => MenuItemCard(
          item: items[i],
          onTap: () => _showItemDetail(ctx, items[i]),
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<MenuItem> items) {
    final crossCount = MediaQuery.of(context).size.width >= 900 ? 3 : 2;
    return RefreshIndicator(
      onRefresh: () => context.read<MenuProvider>().refresh(),
      color: AppColors.gold,
      backgroundColor: AppColors.background,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossCount,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          childAspectRatio: 0.78,
        ),
        itemCount: items.length,
        itemBuilder: (ctx, i) => MenuItemGridCard(
          item: items[i],
          onTap: () => _showItemDetail(ctx, items[i]),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, __) => const _MenuItemSkeleton(),
    );
  }

  Widget _buildErrorState(BuildContext context, MenuProvider mp) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.textMuted, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text('Could not load menu',
              style: AppTextStyles.headline(context), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(mp.errorMessage ?? 'Please try again.',
              style: AppTextStyles.bodyMedium(context), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(label: 'TRY AGAIN', onPressed: mp.refresh, isSmall: true),
        ]),
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
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
                    begin: const Offset(0, 1), end: Offset.zero)
                    .animate(CurvedAnimation(
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
                CustomPaint(
                    size: const Size(32, 32),
                    painter: _MiniFabCatPainter()),
                Positioned(
                  top: 10, right: 10,
                  child: Container(
                    width: 8, height: 8,
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

// ─── Persistent Animated Header ────────────────────────────────────────────────
// Morphs from expanded (140px) to compact (64px) as user scrolls.
// Brand cat, "Bingnondo", "Authentic Binondo Cafe", and "Open Now"
// stay visible at ALL scroll positions — they just get smaller.
class _PersistentHeader extends StatelessWidget {
  final double collapseRatio; // 0.0 = expanded, 1.0 = collapsed
  final double expandedHeight;
  final double collapsedHeight;
  final Animation<double> badgeBounce;
  final VoidCallback onCartTap;
  final VoidCallback onProfileTap;

  const _PersistentHeader({
    required this.collapseRatio,
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.badgeBounce,
    required this.onCartTap,
    required this.onProfileTap,
  });

  // Lerp helpers
  double _lerp(double from, double to) =>
      from + (to - from) * collapseRatio;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final currentHeight = _lerp(expandedHeight, collapsedHeight);

    // Font / icon sizes
    final catSize    = _lerp(64.0, 36.0);
    final titleSize  = _lerp(24.0, 16.0);
    final subSize    = _lerp(12.0, 10.0);
    final pillScale  = _lerp(1.0, 0.85);

    // In collapsed mode we switch from column to row layout
    final isCollapsed = collapseRatio > 0.55;

    return Container(
      color: AppColors.primaryDark,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        safeTop + (isCollapsed ? 8 : 12),
        AppSpacing.md,
        8,
      ),
      height: currentHeight + safeTop,
      child: Stack(
        children: [
          // ── Decorative corner marks (fade out as collapsed) ──────────────
          if (collapseRatio < 0.7) ...[
            Positioned(
              top: 0, left: 0,
              child: Opacity(
                opacity: (1 - collapseRatio * 1.4).clamp(0, 1),
                child: const ChineseCornerDecoration(size: 36),
              ),
            ),
            Positioned(
              top: 0, right: 48,
              child: Opacity(
                opacity: (1 - collapseRatio * 1.4).clamp(0, 1),
                child: const ChineseCornerDecoration(size: 36, flipH: true),
              ),
            ),
          ],

          // ── Action buttons (cart + profile) — always top-right ───────────
          Positioned(
            top: 0, right: 0,
            child: Row(
              children: [
                Consumer<CartProvider>(
                  builder: (_, cart, __) => Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: CustomPaint(
                          size: const Size(22, 22),
                          painter: _CartIconPainter(),
                        ),
                        onPressed: onCartTap,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                      ),
                      if (cart.totalItemCount > 0)
                        Positioned(
                          top: 4, right: 3,
                          child: ScaleTransition(
                            scale: badgeBounce,
                            child: Container(
                              width: 16, height: 16,
                              decoration: const BoxDecoration(
                                  color: AppColors.gold,
                                  shape: BoxShape.circle),
                              child: Center(
                                child: Text(
                                  '${cart.totalItemCount > 99 ? '99+' : cart.totalItemCount}',
                                  style: GoogleFonts.karla(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryDark),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onProfileTap,
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.textOnDark.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.gold.withOpacity(0.5), width: 1.5),
                    ),
                    child: const Icon(Icons.person_outline_rounded,
                        color: AppColors.textOnDark, size: 16),
                  ),
                ),
              ],
            ),
          ),

          // ── Brand content — always visible, morphs size ──────────────────
          Positioned.fill(
            right: 80, // leave room for action buttons
            child: isCollapsed
                ? _CollapsedBrand(
              catSize: catSize,
              titleSize: titleSize,
              subSize: subSize,
              pillScale: pillScale,
            )
                : _ExpandedBrand(
              catSize: catSize,
              titleSize: titleSize,
              subSize: subSize,
              pillScale: pillScale,
              collapseRatio: collapseRatio,
            ),
          ),
        ],
      ),
    );
  }
}

// Expanded layout — cat left, text right (column), all info visible
class _ExpandedBrand extends StatelessWidget {
  final double catSize;
  final double titleSize;
  final double subSize;
  final double pillScale;
  final double collapseRatio;

  const _ExpandedBrand({
    required this.catSize,
    required this.titleSize,
    required this.subSize,
    required this.pillScale,
    required this.collapseRatio,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Animated cat
        BrandCatIcon(size: catSize),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bingnondo',
              style: GoogleFonts.playfairDisplaySc(
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
                color: AppColors.textOnDark,
                letterSpacing: 0.3,
              ),
            ),
            if (collapseRatio < 0.8) ...[
              const SizedBox(height: 2),
              Text(
                'Authentic Binondo Cafe',
                style: GoogleFonts.karla(
                  fontSize: subSize,
                  color: AppColors.textOnDark.withOpacity(
                      (1 - collapseRatio * 1.2).clamp(0, 1)),
                  letterSpacing: 0.3,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Transform.scale(
              scale: pillScale,
              alignment: Alignment.centerLeft,
              child: const _OpenNowPill(),
            ),
          ],
        ),
      ],
    );
  }
}

// Collapsed layout — row: cat + title + subtitle (inline) + pill
class _CollapsedBrand extends StatelessWidget {
  final double catSize;
  final double titleSize;
  final double subSize;
  final double pillScale;

  const _CollapsedBrand({
    required this.catSize,
    required this.titleSize,
    required this.subSize,
    required this.pillScale,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        BrandCatIcon(size: catSize),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bingnondo',
                style: GoogleFonts.playfairDisplaySc(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textOnDark,
                  letterSpacing: 0.3,
                ),
              ),
              Row(
                children: [
                  Text(
                    'Authentic Binondo Cafe',
                    style: GoogleFonts.karla(
                      fontSize: subSize,
                      color: AppColors.textOnDark.withOpacity(0.6),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Transform.scale(
                    scale: pillScale,
                    alignment: Alignment.centerLeft,
                    child: const _OpenNowPill(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// "Open Now" pill — extracted so it's identical in both layouts
class _OpenNowPill extends StatelessWidget {
  const _OpenNowPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.gold.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5, height: 5,
            decoration: const BoxDecoration(
                color: AppColors.gold, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            'Open Now',
            style: GoogleFonts.karla(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Category Tab Bar ──────────────────────────────────────────────────────────
class _CategoryTabBar extends StatelessWidget {
  final TabController controller;
  final List<MenuCategory> categories;

  const _CategoryTabBar(
      {required this.controller, required this.categories});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryDark,
      child: TabBar(
        controller: controller,
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
        tabs: categories.map((cat) => Tab(text: cat.name)).toList(),
      ),
    );
  }
}

// ─── Menu Item Cards ───────────────────────────────────────────────────────────

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
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(AppRadius.lg),
                ),
                child: _FoodImage(url: item.photoUrl, width: 100, height: 100),
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
                            child: Text(item.name,
                                style: GoogleFonts.playfairDisplaySc(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          _AvailBadge(available: item.isAvailable),
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
                          Text('₱${item.price.toStringAsFixed(2)}',
                              style: GoogleFonts.playfairDisplaySc(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
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
                                child: Text('+ Add',
                                    style: GoogleFonts.karla(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textOnDark)),
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
            border: Border.all(color: AppColors.border),
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
                    _FoodImage(
                        url: item.photoUrl, width: double.infinity, height: 130),
                    Positioned(
                        top: 8,
                        right: 8,
                        child: _AvailBadge(available: item.isAvailable)),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm + 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          style: GoogleFonts.playfairDisplaySc(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('₱${item.price.toStringAsFixed(0)}',
                              style: GoogleFonts.playfairDisplaySc(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
                          if (item.isAvailable)
                            GestureDetector(
                              onTap: onTap,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius:
                                    BorderRadius.circular(AppRadius.sm)),
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

// ─── Detail Sheet ──────────────────────────────────────────────────────────────
class MenuItemDetailSheet extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onAddToCart;
  const MenuItemDetailSheet(
      {super.key, required this.item, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill)),
            ),
          ),
          ClipRRect(
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            child: _FoodImage(
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
                          child: Text(item.name,
                              style: AppTextStyles.display2(context))),
                      const SizedBox(width: 12),
                      _AvailBadge(available: item.isAvailable),
                    ],
                  ),
                  if (item.description != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(item.description!,
                        style: AppTextStyles.bodyMedium(context)),
                  ],
                  const Spacer(),
                  Text('₱${item.price.toStringAsFixed(2)}',
                      style: GoogleFonts.playfairDisplaySc(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
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
class _AvailBadge extends StatelessWidget {
  final bool available;
  const _AvailBadge({required this.available});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: available
            ? AppColors.success.withOpacity(0.12)
            : AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: available
              ? AppColors.success.withOpacity(0.4)
              : AppColors.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5, height: 5,
            decoration: BoxDecoration(
                color: available ? AppColors.success : AppColors.error,
                shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(available ? 'Available' : 'Sold out',
              style: GoogleFonts.karla(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: available ? AppColors.success : AppColors.error)),
        ],
      ),
    );
  }
}

// ─── Food Image ────────────────────────────────────────────────────────────────
class _FoodImage extends StatelessWidget {
  final String? url;
  final double width;
  final double height;
  const _FoodImage({required this.url, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return Image.network(url!, width: width, height: height, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _ph());
    }
    return _ph();
  }

  Widget _ph() => SizedBox(
    width: width, height: height,
    child: Container(
      color: AppColors.surfaceWarm,
      child: Center(
        child: CustomPaint(size: const Size(40, 40), painter: _BowlPainter()),
      ),
    ),
  );
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
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
            leading: const Icon(Icons.person_outline_rounded, color: AppColors.gold),
            title: Text('Complete Profile', style: AppTextStyles.bodyLarge(context)),
            subtitle: Text('Add your name & address',
                style: AppTextStyles.bodySmall(context)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined, color: AppColors.gold),
            title: Text('Account Settings', style: AppTextStyles.bodyLarge(context)),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          GoldOutlineButton(label: 'SIGN OUT', onPressed: onLogout),
        ],
      ),
    );
  }
}

// ─── Empty / skeleton helpers ──────────────────────────────────────────────────
class _EmptyMenuState extends StatelessWidget {
  const _EmptyMenuState();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const _LanternEmpty(),
      const SizedBox(height: AppSpacing.md),
      Text('Menu is empty.', style: AppTextStyles.bodyMedium(context)),
    ]),
  );
}

class _LanternEmpty extends StatelessWidget {
  const _LanternEmpty();
  @override
  Widget build(BuildContext context) => CustomPaint(
      size: const Size(60, 84), painter: _SingleLanternPainter(opacity: 0.3));
}

class _MenuItemSkeleton extends StatefulWidget {
  const _MenuItemSkeleton();
  @override
  State<_MenuItemSkeleton> createState() => _MenuItemSkeletonState();
}

class _MenuItemSkeletonState extends State<_MenuItemSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _a = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) {
        final col = Color.lerp(
            const Color(0xFFEFEBE4), const Color(0xFFDDD8CF), _a.value)!;
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
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: col,
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
                      Container(height: 14, width: 120,
                          decoration: BoxDecoration(color: col,
                              borderRadius: BorderRadius.circular(AppRadius.sm))),
                      Container(height: 10, width: 180,
                          decoration: BoxDecoration(color: col,
                              borderRadius: BorderRadius.circular(AppRadius.sm))),
                      Container(height: 10, width: 90,
                          decoration: BoxDecoration(color: col,
                              borderRadius: BorderRadius.circular(AppRadius.sm))),
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
    canvas.drawPath(
        Path()
          ..moveTo(2, 2)..lineTo(5, 2)..lineTo(8, 16)
          ..lineTo(20, 16)..lineTo(22, 6)..lineTo(6, 6),
        p);
    final d = Paint()..color = AppColors.textOnDark..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(9, 20), 2, d);
    canvas.drawCircle(const Offset(18, 20), 2, d);
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _BowlPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.gold.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(Rect.fromLTWH(2, size.height * 0.35, size.width - 4, size.height * 0.5), p);
    canvas.drawLine(Offset(size.width * 0.2, size.height * 0.35),
        Offset(size.width * 0.8, size.height * 0.35), p);
    canvas.drawArc(Rect.fromLTWH(size.width * 0.25, 0, size.width * 0.5, size.height * 0.4),
        3.14 * 1.1, 3.14 * 0.8, false, p);
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _SingleLanternPainter extends CustomPainter {
  final double opacity;
  const _SingleLanternPainter({this.opacity = 1.0});
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = AppColors.gold.withOpacity(opacity)
      ..style = PaintingStyle.stroke..strokeWidth = 1.5;
    final w = size.width; final h = size.height;
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h * 0.1), stroke);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.15, h * 0.08, w * 0.7, h * 0.1), const Radius.circular(3)),
        fill..color = AppColors.gold.withOpacity(opacity));
    final body = Path()
      ..moveTo(w * 0.05, h * 0.2)
      ..quadraticBezierTo(0, h * 0.5, w * 0.05, h * 0.78)
      ..lineTo(w * 0.95, h * 0.78)
      ..quadraticBezierTo(w, h * 0.5, w * 0.95, h * 0.2)
      ..close();
    canvas.drawPath(body, fill..color = AppColors.primaryDark.withOpacity(opacity));
    canvas.drawPath(body, stroke);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.15, h * 0.76, w * 0.7, h * 0.08), const Radius.circular(3)),
        fill..color = AppColors.gold.withOpacity(opacity));
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _MiniFabCatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final f = Paint()..color = AppColors.gold..style = PaintingStyle.fill;
    final s = size.width / 32;
    canvas.scale(s, s);
    canvas.drawOval(const Rect.fromLTWH(6, 8, 20, 18), f..color = AppColors.gold.withOpacity(0.7));
    canvas.drawPath(Path()..moveTo(8,14)..lineTo(5,6)..lineTo(13,11)..close(), f);
    canvas.drawPath(Path()..moveTo(24,14)..lineTo(27,6)..lineTo(19,11)..close(), f);
    final e = Paint()..color = AppColors.primaryDark..strokeWidth = 1.5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(13,14), const Offset(13,17), e);
    canvas.drawLine(const Offset(19,14), const Offset(19,17), e);
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}