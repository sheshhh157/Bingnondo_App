import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/menu_models.dart';
import '../../models/review_model.dart';
import '../../services/menu_provider.dart';
import '../../services/cart_provider.dart';
import '../../services/auth_provider.dart';
import '../../services/business_hours_provider.dart';
import '../../services/notifications_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/business_hours_banner.dart';
import '../chatbot/chatbot_screen.dart';
import '../cart/cart_screen.dart';
import '../orders/my_orders_screen.dart';
import '../notifications/notifications_screen.dart';
import '../settings/account_settings_screen.dart';
import '../chat/support_chat_screen.dart';
import '../../services/order_tracking_provider.dart';
import '../../services/orders_provider.dart';
import '../../services/socket_service.dart';
import '../../services/review_provider.dart';

class HomeMenuScreen extends StatefulWidget {
  const HomeMenuScreen({super.key});

  @override
  State<HomeMenuScreen> createState() => _HomeMenuScreenState();
}

class _HomeMenuScreenState extends State<HomeMenuScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';

  double _collapseRatio = 0.0;

  late AnimationController _badgeBounceCtrl;
  late Animation<double> _badgeBounce;
  int _prevCartCount = 0;
  static const double _expandedHeaderH = 140.0;
  static const double _collapsedHeaderH = 75.0; // Increased to prevent overflow
  static const double _scrollTriggerH =
      _expandedHeaderH - _collapsedHeaderH;



  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);

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
      // Refresh the open/closed state whenever the home screen mounts
      context.read<BusinessHoursProvider>().load();
      // Pre-load notifications for badge count
      context.read<NotificationsProvider>().load();
      // Load orders up-front so "Message Staff" knows if there's an active order
      context.read<OrdersProvider>().loadOrders();
      // Join personal support room for real-time staff replies / lock-unlock
      final uid = context.read<AuthProvider>().user?.id;
      if (uid != null) SocketService.instance.joinSupportRoom(uid);
    });
  }

  void _onScroll() {
    final offset =
    _scrollController.offset.clamp(0.0, _scrollTriggerH);
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
      // +1 for the "ALL" tab at index 0
      _tabController = TabController(length: cats.length + 1, vsync: this);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _badgeBounceCtrl.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _handleAddToCart(MenuItem item) {
    // Adding to cart stays allowed even outside business hours — only placing
    // the order is blocked (cart / checkout / backend all enforce that).

    // If the item has variants, open the detail sheet so the customer can pick.
    // Otherwise, add directly to cart (existing fast-add behaviour).
    if (item.hasVariants) {
      _showItemDetail(context, item);
    } else {
      _addToCartQuantity(item, null, 1);
    }
  }

  void _addToCartQuantity(MenuItem item, MenuItemVariant? variant, int quantity) {
    if (quantity <= 0) return;

    final cart = context.read<CartProvider>();
    for (var i = 0; i < quantity; i++) {
      cart.addItem(item, variant: variant);
    }
    final newCount = cart.totalItemCount;
    if (newCount > _prevCartCount) {
      _badgeBounceCtrl.forward(from: 0);
      _prevCartCount = newCount;
    }
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${item.name}${quantity > 1 ? ' ×$quantity' : ''} added to cart',
            style: GoogleFonts.karla(fontSize: 13)),
        duration: const Duration(seconds: 2),
        // May 'View Cart' action kaya kailangang i-set sa false:
        // default kasi nito ay `persist = action != null`, kaya kung hindi
        // ito ii-set, hindi nag-a-auto-dismiss ang snackbar.
        persist: false,
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

  void _goToCart() => _push(const CartScreen());

  void _push(Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => screen,
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
              begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(
              parent: anim, curve: Curves.easeOutCubic)),
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
          return Stack(
            children: [
              // ── SVG Background Pattern ─────────────────────────────────
              Positioned.fill(
                child: Opacity(
                  opacity: 0.3, // Pwedeng baguhin ang opacity dito (halimbawa 0.1, 0.3, o 0.8)
                  child: SvgPicture.asset(
                    'assets/images/menu_bg_pattern.svg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // ── Main content column ─────────────────────────────────────
              Column(
                children: [
                  _PersistentHeader(
                    collapseRatio: _collapseRatio,
                    expandedHeight: _expandedHeaderH,
                    collapsedHeight: _collapsedHeaderH,
                    badgeBounce: _badgeBounce,
                    onNotifTap: () => _push(const NotificationsScreen()),
                  ),
                  if (menuProvider.isLoaded &&
                      menuProvider.categories.isNotEmpty)
                    _CategoryTabBar(
                      controller: _tabController,
                      categories: menuProvider.categories,
                      itemCounts: {
                        for (final c in menuProvider.categories)
                          c.id: menuProvider.itemsForCategory(c.id).length,
                      },
                    ),
                  if (menuProvider.isLoaded) _buildSearchField(),
                  Expanded(child: _buildBody(context, menuProvider)),
                ],
              ),
            ],
          );
        },
      ),
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
        if (_searchQuery.trim().isNotEmpty) {
          return _buildSearchResults(
            context,
            menuProvider.searchItems(_searchQuery),
          );
        }
        if (menuProvider.categories.isEmpty) return const _EmptyMenuState();
        // Tab index 0 = ALL (sections layout), 1..n = individual categories
        return TabBarView(
          controller: _tabController,
          children: [
            // ALL tab — one continuous scroll with per-category horizontal rows
            _buildAllSectionsView(context, menuProvider),
            // Individual category tabs — same list/grid as before
            ...menuProvider.categories.map((cat) {
              final items = menuProvider.itemsForCategory(cat.id);
              return _buildCategoryContent(context, items);
            }),
          ],
        );
    }
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onChanged: (value) {
          _searchDebounce?.cancel();
          if (value.trim().isEmpty) {
            setState(() => _searchQuery = '');
            return;
          }
          _searchDebounce = Timer(const Duration(milliseconds: 350), () {
            if (mounted) setState(() => _searchQuery = value);
          });
        },
        decoration: InputDecoration(
          hintText: 'Search menu items...',
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gold),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, List<MenuItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 48,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No menu items found',
                style: AppTextStyles.headline(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Try another item name, description, or category.',
                style: AppTextStyles.bodyMedium(context),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            0,
          ),
          child: Text(
            '${items.length} ${items.length == 1 ? 'item' : 'items'} found',
            style: AppTextStyles.bodySmall(context),
          ),
        ),
        Expanded(child: _buildCategoryContent(context, items)),
      ],
    );
  }

  // ─── ALL tab: featured hero + vertical sections ────────────────────────────
  Widget _buildAllSectionsView(BuildContext context, MenuProvider menuProvider) {
    final cats = menuProvider.categories;
    final isClosed =
        context.watch<BusinessHoursProvider>().isKnownClosed;

    // Featured picks — first available item from each category for variety.
    final featured = <MenuItem>[];
    for (final cat in cats) {
      final available =
      menuProvider.itemsForCategory(cat.id).where((i) => i.isAvailable);
      if (available.isNotEmpty) featured.add(available.first);
      if (featured.length >= 6) break;
    }

    return RefreshIndicator(
      onRefresh: () => context.read<MenuProvider>().refresh(),
      color: AppColors.gold,
      backgroundColor: AppColors.background,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          if (isClosed)
            const Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
              child: BusinessHoursBanner(),
            ),
          if (featured.isNotEmpty)
            _FeaturedSection(
              items: featured,
              onItemTap: (item) => _showItemDetail(context, item),
            ),
          for (int i = 0; i < cats.length; i++)
            _CategorySection(
              category: cats[i],
              items: menuProvider.itemsForCategory(cats[i].id),
              onItemTap: (item) => _showItemDetail(context, item),
              onAddToCart: _handleAddToCart,
              onViewAll: () => _tabController.animateTo(i + 1),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryContent(BuildContext context, List<MenuItem> items) {
    if (items.isEmpty) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const _LanternEmpty(),
            const SizedBox(height: AppSpacing.md),
            Text('Nothing here yet.', style: AppTextStyles.bodyMedium(context)),
          ]));
    }
    return MediaQuery.of(context).size.width >= 600
        ? _buildGrid(context, items)
        : _buildList(context, items);
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
    final crossCount =
    MediaQuery.of(context).size.width >= 900 ? 3 : 2;
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
          crossAxisSpacing: AppSpacing.sm + 2,
          mainAxisSpacing: AppSpacing.sm + 2,
          childAspectRatio: 0.72,
        ),
        itemCount: items.length,
        itemBuilder: (ctx, i) => MenuItemGridCard(
          item: items[i],
          onTap: () => _showItemDetail(ctx, items[i]),
          onAdd: () => _handleAddToCart(items[i]),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        // Featured row header
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
          child: Row(children: const [
            _ShimmerBox(width: 4, height: 18, radius: AppRadius.pill),
            SizedBox(width: 8),
            _ShimmerBox(width: 90, height: 14),
          ]),
        ),
        // Featured cards
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: 3,
            separatorBuilder: (_, __) =>
            const SizedBox(width: AppSpacing.sm + 2),
            itemBuilder: (_, __) =>
            const _ShimmerBox(width: 250, height: 210, radius: AppRadius.xl),
          ),
        ),
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.md),
          child: Row(children: const [
            _ShimmerBox(width: 4, height: 18, radius: AppRadius.pill),
            SizedBox(width: 8),
            _ShimmerBox(width: 120, height: 14),
          ]),
        ),
        // Horizontal row of item cards
        SizedBox(
          height: _kCategoryCardH,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: 3,
            separatorBuilder: (_, __) =>
            const SizedBox(width: AppSpacing.sm + 2),
            itemBuilder: (_, __) => const SizedBox(
              width: _kCategoryCardW,
              child: _ShimmerBox(radius: AppRadius.lg),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, MenuProvider mp) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded,
              color: AppColors.textMuted, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text('Could not load menu',
              style: AppTextStyles.headline(context),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(mp.errorMessage ?? 'Please try again.',
              style: AppTextStyles.bodyMedium(context),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
              label: 'TRY AGAIN',
              onPressed: mp.refresh,
              isSmall: true),
        ]),
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
        onAddToCart: (qty, variant) => _addToCartQuantity(item, variant, qty),
      ),
    );
  }


}

// ─── Persistent Animated Header ────────────────────────────────────────────────
class _PersistentHeader extends StatelessWidget {
  final double collapseRatio;
  final double expandedHeight;
  final double collapsedHeight;
  final Animation<double> badgeBounce;
  final VoidCallback onNotifTap;

  const _PersistentHeader({
    required this.collapseRatio,
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.badgeBounce,
    required this.onNotifTap,
  });

  double _lerp(double from, double to) =>
      from + (to - from) * collapseRatio;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final currentHeight = _lerp(expandedHeight, collapsedHeight);
    final catSize = _lerp(64.0, 36.0);
    final titleSize = _lerp(24.0, 16.0);
    final subSize = _lerp(12.0, 10.0);
    final pillScale = _lerp(1.0, 0.85);
    final isCollapsed = collapseRatio > 0.55;

    return Container(
      color: AppColors.primaryDark,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        safeTop + (isCollapsed ? 4 : 12),
        AppSpacing.md,
        8,
      ),
      height: currentHeight + safeTop,
      child: Stack(
        children: [
          // ── Action buttons ───────────────────────────────────────────────
          Positioned(
            top: 0,
            right: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Notification bell
                Consumer<NotificationsProvider>(
                  builder: (_, notifProvider, __) => Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: CustomPaint(
                          size: const Size(22, 22),
                          painter: _BellIconPainter(),
                        ),
                        onPressed: onNotifTap,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                        tooltip: 'Notifications',
                      ),
                      if (notifProvider.unreadCount > 0)
                        Positioned(
                          top: 4,
                          right: 3,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle),
                            child: Center(
                              child: Text(
                                notifProvider.unreadCount > 9
                                    ? '9+'
                                    : '${notifProvider.unreadCount}',
                                style: GoogleFonts.karla(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),


              ],
            ),
          ),

          // ── Brand content ─────────────────────────────────────────────
          Positioned.fill(
            right: 40, // room for 1 icon button (notif only)
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

// ─── Expanded Brand ────────────────────────────────────────────────────────────
class _ExpandedBrand extends StatelessWidget {
  final double catSize, titleSize, subSize, pillScale, collapseRatio;
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
                  color: AppColors.textOnDark
                      .withOpacity((1 - collapseRatio * 1.2).clamp(0, 1)),
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

// ─── Collapsed Brand ───────────────────────────────────────────────────────────
class _CollapsedBrand extends StatelessWidget {
  final double catSize, titleSize, subSize, pillScale;
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bingnondo',
                style: GoogleFonts.playfairDisplaySc(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textOnDark,
                  letterSpacing: 0.3,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'Authentic Binondo Cafe',
                style: GoogleFonts.karla(
                  fontSize: subSize,
                  color: AppColors.textOnDark.withOpacity(0.6),
                  letterSpacing: 0.2,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Transform.scale(
                scale: pillScale,
                alignment: Alignment.centerLeft,
                child: const _OpenNowPill(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Open Now Pill ─────────────────────────────────────────────────────────────
class _OpenNowPill extends StatelessWidget {
  const _OpenNowPill();

  @override
  Widget build(BuildContext context) {
    final hours = context.watch<BusinessHoursProvider>();
    final isOpen = hours.isOpen;
    // Lighter red reads better on the dark maroon header than AppColors.error.
    const closedColor = Color(0xFFFF8A80);
    final color = isOpen ? AppColors.gold : closedColor;
    final label = isOpen ? 'Open Now' : 'Closed';
    final detail = hours.hasStatus
        ? '${hours.message}\n${hours.status!.scheduleLabel}'
        : 'Checking business hours…';

    return Tooltip(
      message: detail,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: color.withOpacity(0.5), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.karla(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Category Tab Bar ──────────────────────────────────────────────────────────
// Layout: pill-style chips in a single horizontal scroll row.
// Index 0 = "ALL", 1..n = individual categories (matches TabController).
class _CategoryTabBar extends StatelessWidget {
  final TabController controller;
  final List<MenuCategory> categories;
  final Map<int, int> itemCounts; // categoryId → item count (badge)

  const _CategoryTabBar({
    required this.controller,
    required this.categories,
    required this.itemCounts,
  });

  @override
  Widget build(BuildContext context) {
    // All labels: ALL first, then each category name
    final labels = ['All', ...categories.map((c) => c.name)];

    return Container(
      color: AppColors.primaryDark,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        // Hide the default bottom indicator — we style the chip itself
        indicator: const BoxDecoration(),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        tabs: List.generate(labels.length, (i) {
          final isAll = i == 0;
          // IMPORTANT: must be Tab() so TabBar's internal InkWell handles the tap.
          // _CategoryChip is purely cosmetic — the chip is the Tab's child.
          return Tab(
            child: _CategoryChip(
              label: labels[i],
              controller: controller,
              index: i,
              // "All" shows no badge — only real categories do.
              count: isAll ? null : itemCounts[categories[i - 1].id],
            ),
          );
        }),
      ),
    );
  }
}

// Animating pill chip — fills with gold when selected.
// A small badge on the right shows how many items the category has.
class _CategoryChip extends StatefulWidget {
  final String label;
  final TabController controller;
  final int index;
  final int? count; // null → no badge (used by the "All" chip)

  const _CategoryChip({
    required this.label,
    required this.controller,
    required this.index,
    this.count,
  });

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.controller.index == widget.index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      // No padding here — Tab widget already provides the tap area and height.
      // Horizontal padding is handled by labelPadding on the TabBar.
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.gold
            : AppColors.textOnDark.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: isSelected
              ? AppColors.gold
              : AppColors.textOnDark.withOpacity(0.18),
          width: 1,
        ),
        boxShadow: isSelected
            ? [
          BoxShadow(
            color: AppColors.gold.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ]
            : const [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.karla(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? AppColors.primaryDark
                  : AppColors.textOnDark.withOpacity(0.7),
              letterSpacing: 0.2,
            ),
          ),
          if (widget.count != null) ...[
            const SizedBox(width: 6),
            _CategoryCountBadge(
              count: widget.count!,
              isSelected: isSelected,
            ),
          ],
        ],
      ),
    );
  }
}

// Small pill badge showing the number of items in the category.
class _CategoryCountBadge extends StatelessWidget {
  final int count;
  final bool isSelected;

  const _CategoryCountBadge({required this.count, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryDark.withOpacity(0.9)
            : AppColors.gold.withOpacity(0.9),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: GoogleFonts.karla(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          height: 1.1,
          color: isSelected ? AppColors.gold : AppColors.primaryDark,
        ),
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
    return _Pressable(
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
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: _FoodImage(
                      url: item.photoUrl, width: 90, height: 90),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.md, AppSpacing.md, AppSpacing.md),
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
  final VoidCallback? onAdd;
  const MenuItemGridCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: item.isAvailable ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: item.isAvailable ? 1.0 : 0.55,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _FoodImage(
                    url: item.photoUrl,
                    width: double.infinity,
                    height: double.infinity),

                // Legibility gradient
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00000000),
                        Color(0x1A000000),
                        Color(0xBF000000),
                      ],
                      stops: [0.36, 0.58, 1.0],
                    ),
                  ),
                ),

                // Sold-out chip
                if (!item.isAvailable)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        'SOLD OUT',
                        style: GoogleFonts.karla(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),

                // Name + price + add
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.name,
                        style: GoogleFonts.playfairDisplaySc(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.25,
                          shadows: const [
                            Shadow(color: Color(0x88000000), blurRadius: 4),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '₱${item.price.toStringAsFixed(0)}',
                              style: GoogleFonts.playfairDisplaySc(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.goldLight,
                                shadows: const [
                                  Shadow(
                                      color: Color(0x88000000), blurRadius: 4),
                                ],
                              ),
                            ),
                          ),
                          if (item.isAvailable && onAdd != null)
                            GestureDetector(
                              onTap: onAdd,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.gold,
                                  shape: BoxShape.circle,
                                  boxShadow: AppShadows.goldGlow,
                                ),
                                child: const Icon(Icons.add_rounded,
                                    color: AppColors.primaryDark, size: 18),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Detail Sheet ──────────────────────────────────────────────────────────────
class MenuItemDetailSheet extends StatefulWidget {
  final MenuItem item;

  /// Called when the customer taps ADD TO CART.
  /// [quantity] — how many; [variant] — chosen variant or null if none required.
  final void Function(int quantity, MenuItemVariant? variant) onAddToCart;

  const MenuItemDetailSheet({
    super.key,
    required this.item,
    required this.onAddToCart,
  });

  @override
  State<MenuItemDetailSheet> createState() => _MenuItemDetailSheetState();
}

class _MenuItemDetailSheetState extends State<MenuItemDetailSheet> {
  int _qty = 1;
  // Selected variants per group: groupId → chosen variant.
  // For optional groups the value may be null (no selection).
  final Map<int, MenuItemVariant?> _selectedVariants = {};

  MenuItem get item => widget.item;

  /// The single chosen variant — for now we support one variant group at a time.
  /// Returns the first selection found (or null).
  MenuItemVariant? get _chosenVariant =>
      _selectedVariants.values.firstWhere((v) => v != null, orElse: () => null);

  /// True when all required groups have a selection.
  bool get _canAdd {
    for (final group in item.inferredVariantGroups) {
      if (group.isRequired && _selectedVariants[group.id] == null) return false;
    }
    return true;
  }

  /// Effective price = base price + chosen variant price delta.
  /// The variant price in DB is the TOTAL price of that option,
  /// so we replace the base price entirely when a variant is picked.
  double get _effectivePrice {
    final chosen = _chosenVariant;
    if (chosen != null) return chosen.price;
    return item.price;
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.9;
    final available = item.isAvailable;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _heroHeader(context, available),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                      AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(item.name,
                                style: AppTextStyles.display2(context)),
                          ),
                          const SizedBox(width: 12),
                          _AvailBadge(available: available),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '₱${item.price.toStringAsFixed(2)}',
                        style: GoogleFonts.playfairDisplaySc(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      if (item.description != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(item.description!,
                            style: AppTextStyles.bodyMedium(context)),
                      ],
                      // ── Variant picker (shown only when variants exist) ───
                      if (item.hasVariants) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _VariantPicker(
                          groups: item.inferredVariantGroups,
                          selectedVariants: _selectedVariants,
                          onChanged: (groupId, variant) {
                            setState(() => _selectedVariants[groupId] = variant);
                          },
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      const ChineseDivider(),
                      const SizedBox(height: AppSpacing.sm),
                      _ReviewsSection(itemId: item.id),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _bottomBar(context, available),
        ],
      ),
    );
  }

  Widget _heroHeader(BuildContext context, bool available) {
    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _FoodImage(
              url: item.photoUrl,
              width: double.infinity,
              height: double.infinity),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x00000000),
                  Color(0x00000000),
                ],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),
          // Drag handle
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
          ),
          // Close button
          Positioned(
            top: 8,
            right: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.4)),
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
          if (!available)
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  'SOLD OUT',
                  style: GoogleFonts.karla(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bottomBar(BuildContext context, bool available) {
    final total = _effectivePrice * _qty;
    // Disable the button when a required variant hasn't been chosen yet.
    final bool canPress = available && _canAdd;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            _QtyStepper(
              value: _qty,
              onChanged: available ? (v) => setState(() => _qty = v) : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: PrimaryButton(
                label: available
                    ? 'ADD • ₱${total.toStringAsFixed(0)}'
                    : 'UNAVAILABLE',
                onPressed: canPress
                    ? () {
                  Navigator.pop(context);
                  widget.onAddToCart(_qty, _chosenVariant);
                }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─── Variant Picker ───────────────────────────────────────────────────────────

/// Displays all variant groups for a menu item inside the detail sheet.
/// Each group renders as a labelled chip row. Required groups show a red dot.
class _VariantPicker extends StatelessWidget {
  final List<VariantGroup> groups;
  final Map<int, MenuItemVariant?> selectedVariants;
  final void Function(int groupId, MenuItemVariant? variant) onChanged;

  const _VariantPicker({
    required this.groups,
    required this.selectedVariants,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.map((group) => _buildGroup(context, group)).toList(),
    );
  }

  Widget _buildGroup(BuildContext context, VariantGroup group) {
    final chosen = selectedVariants[group.id];
    final availableVariants = group.variants.where((v) => v.isAvailable).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group label row
          Row(
            children: [
              Text(
                group.name.toUpperCase(),
                style: GoogleFonts.playfairDisplaySc(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 6),
              if (group.isRequired)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'REQUIRED',
                    style: GoogleFonts.karla(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.error,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'OPTIONAL',
                    style: GoogleFonts.karla(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Variant chips
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              // "None" chip for optional groups
              if (!group.isRequired)
                _VariantChip(
                  label: 'None',
                  subLabel: null,
                  isSelected: chosen == null,
                  isNone: true,
                  onTap: () => onChanged(group.id, null),
                ),
              ...availableVariants.map((variant) {
                final isSelected = chosen?.id == variant.id;
                // Show "+₱X" price difference compared to base item price
                // (the variant.price in DB is already the FULL price of that option)
                return _VariantChip(
                  label: variant.name,
                  subLabel: '₱${variant.price.toStringAsFixed(0)}',
                  isSelected: isSelected,
                  isNone: false,
                  onTap: () => onChanged(group.id, variant),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

class _VariantChip extends StatelessWidget {
  final String label;
  final String? subLabel;
  final bool isSelected;
  final bool isNone;
  final VoidCallback onTap;

  const _VariantChip({
    required this.label,
    required this.subLabel,
    required this.isSelected,
    required this.isNone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected ? AppShadows.goldGlow : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected && !isNone) ...[
              Icon(Icons.check_rounded,
                  size: 13,
                  color: Colors.white),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.karla(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : isNone
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
              ),
            ),
            if (subLabel != null) ...[
              const SizedBox(width: 5),
              Text(
                subLabel!,
                style: GoogleFonts.karla(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? Colors.white.withOpacity(0.85)
                      : AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Quantity stepper ─────────────────────────────────────────────────────────
class _QtyStepper extends StatelessWidget {
  final int value;
  final void Function(int)? onChanged; // null = disabled
  final int min;
  final int max;

  const _QtyStepper({
    required this.value,
    this.onChanged,
    this.min = 1,
    this.max = 20,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove_rounded,
              enabled && value > min ? () => onChanged!(value - 1) : null),
          SizedBox(
            width: 32,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplaySc(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: enabled ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ),
          _btn(Icons.add_rounded,
              enabled && value < max ? () => onChanged!(value + 1) : null),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap) {
    final active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 44,
        alignment: Alignment.center,
        child: Icon(icon,
            size: 18,
            color: active ? AppColors.primary : AppColors.textMuted),
      ),
    );
  }
}

// ─── Ratings & Reviews ────────────────────────────────────────────────────────
class _ReviewsSection extends StatefulWidget {
  final int itemId;
  const _ReviewsSection({required this.itemId});

  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  late final ReviewProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = ReviewProvider(widget.itemId)..load();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  void _openWriteReview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WriteReviewSheet(provider: _provider),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _provider,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'RATINGS & REVIEWS',
                    style: GoogleFonts.playfairDisplaySc(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                // Show "Write a review" / "Edit review" only if eligible
                if (_provider.canWriteReview)
                  GestureDetector(
                    onTap: _openWriteReview,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      child: Text(
                        _provider.hasAlreadyReviewed
                            ? 'Edit review'
                            : 'Write a review',
                        style: GoogleFonts.karla(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (_provider.isLoading)
              _loading()
            else if (!_provider.hasReviews)
              _empty()
            else
              _content(),
          ],
        );
      },
    );
  }

  Widget _loading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            _ShimmerBox(width: 64, height: 48, radius: AppRadius.md),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBox(width: 120, height: 12),
                  SizedBox(height: 6),
                  _ShimmerBox(width: 80, height: 10),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (int i = 0; i < 2; i++) ...[
          const _ShimmerBox(height: 64, radius: AppRadius.lg),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _empty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm.withOpacity(0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.rate_review_outlined,
              size: 28, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.sm),
          Text('No reviews yet',
              style: AppTextStyles.bodyLarge(context)
                  .copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('Be the first to share your experience.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall(context)),
          // If eligible, show CTA button inside empty state too
          if (_provider.canWriteReview) ...[
            const SizedBox(height: AppSpacing.md),
            GestureDetector(
              onTap: _openWriteReview,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  'Write a Review',
                  style: GoogleFonts.karla(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _content() {
    final avg = _provider.average;
    final maxCount = [5, 4, 3, 2, 1]
        .map(_provider.countFor)
        .reduce((a, b) => a > b ? a : b);
    final reviews = _provider.reviews;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Summary ──────────────────────────────────────────────────────
        Row(
          children: [
            Column(
              children: [
                Text(
                  avg.toStringAsFixed(1),
                  style: GoogleFonts.playfairDisplaySc(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                _StarRow(rating: avg, size: 14),
                const SizedBox(height: 4),
                Text('${_provider.count} reviews',
                    style: AppTextStyles.caption(context)),
              ],
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                children: [
                  for (int star = 5; star >= 1; star--)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text('$star',
                              style: GoogleFonts.karla(
                                  fontSize: 11,
                                  color: AppColors.textMuted)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _bar(maxCount == 0
                                ? 0
                                : _provider.countFor(star) / maxCount),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 18,
                            child: Text(
                              '${_provider.countFor(star)}',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.karla(
                                  fontSize: 11,
                                  color: AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Review list ──────────────────────────────────────────────────
        for (final r in reviews) _ReviewCard(review: r),
      ],
    );
  }

  Widget _bar(double fraction) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        height: 6,
        color: AppColors.border.withOpacity(0.5),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: fraction.clamp(0.0, 1.0),
          child: Container(color: AppColors.gold),
        ),
      ),
    );
  }
}

// ─── Single review card ───────────────────────────────────────────────────────
class _ReviewCard extends StatelessWidget {
  final Review review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final initial = review.authorName.trim().isNotEmpty
        ? review.authorName.trim()[0].toUpperCase()
        : '?';
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border:
                  Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Text(
                  initial,
                  style: GoogleFonts.playfairDisplaySc(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.authorName,
                        style: AppTextStyles.bodyLarge(context)
                            .copyWith(fontWeight: FontWeight.w600)),
                    Text(_relativeDate(review.createdAt),
                        style: AppTextStyles.caption(context)),
                  ],
                ),
              ),
              _StarRow(rating: review.rating, size: 14),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(review.comment, style: AppTextStyles.bodyMedium(context)),
          ],
        ],
      ),
    );
  }

  String _relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 30) {
      final months = (diff.inDays / 30).floor();
      return months <= 1 ? '1 month ago' : '$months months ago';
    }
    if (diff.inDays >= 1) {
      return diff.inDays == 1 ? '1 day ago' : '${diff.inDays} days ago';
    }
    if (diff.inHours >= 1) {
      return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
    }
    if (diff.inMinutes >= 1) {
      return diff.inMinutes == 1
          ? '1 minute ago'
          : '${diff.inMinutes} minutes ago';
    }
    return 'Just now';
  }
}

// ─── Write / Edit Review Sheet ─────────────────────────────────────────────────
class _WriteReviewSheet extends StatefulWidget {
  final ReviewProvider provider;
  const _WriteReviewSheet({required this.provider});

  @override
  State<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<_WriteReviewSheet> {
  int _selectedRating = 0;          // 0 = not yet picked
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  static const _starLabels = ['Terrible', 'Poor', 'Okay', 'Good', 'Excellent'];

  @override
  void initState() {
    super.initState();
    _prefillExisting();
  }

  /// If the customer already reviewed this item, pre-fill the form.
  Future<void> _prefillExisting() async {
    if (!widget.provider.hasAlreadyReviewed) return;
    final existing = await ReviewService.instance
        .fetchMyReview(widget.provider.itemId);
    if (existing != null && mounted) {
      setState(() {
        _selectedRating = existing.rating.round();
        _commentCtrl.text = existing.comment;
      });
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a star rating.',
              style: GoogleFonts.karla(fontSize: 13)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    final success = await widget.provider.submitReview(
      rating:  _selectedRating,
      comment: _commentCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.provider.hasAlreadyReviewed
                ? 'Review updated! Salamat sa iyong feedback.'
                : 'Review submitted! Salamat sa iyong feedback.',
            style: GoogleFonts.karla(fontSize: 13),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.provider.submitError ?? 'Something went wrong.',
            style: GoogleFonts.karla(fontSize: 13),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg,
          AppSpacing.lg + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle ───────────────────────────────────────────────────
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),

          // ── Title ────────────────────────────────────────────────────
          Text(
            widget.provider.hasAlreadyReviewed
                ? 'Edit Your Review'
                : 'Write a Review',
            style: GoogleFonts.playfairDisplaySc(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your feedback helps other customers.',
            style: GoogleFonts.karla(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Star picker ──────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedRating = star),
                      child: Padding(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          star <= _selectedRating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: star <= _selectedRating
                              ? AppColors.gold
                              : AppColors.textMuted.withOpacity(0.4),
                          size: 40,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _selectedRating > 0
                      ? Text(
                    _starLabels[_selectedRating - 1],
                    key: ValueKey(_selectedRating),
                    style: GoogleFonts.karla(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gold,
                    ),
                  )
                      : Text(
                    'Tap a star to rate',
                    key: const ValueKey(0),
                    style: GoogleFonts.karla(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Comment ──────────────────────────────────────────────────
          Text(
            'Comment (optional)',
            style: GoogleFonts.karla(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _commentCtrl,
            maxLines: 4,
            maxLength: 1000,
            style: GoogleFonts.karla(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Share your experience with this dish...',
              hintStyle: GoogleFonts.karla(
                  fontSize: 13, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.card,
              counterStyle: GoogleFonts.karla(
                  fontSize: 11, color: AppColors.textMuted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(
                    color: AppColors.gold.withOpacity(0.6), width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(AppSpacing.md),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Submit button ────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _submitting
                  ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: AppColors.gold, strokeWidth: 2.5),
                ),
              )
                  : ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(AppRadius.pill),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  widget.provider.hasAlreadyReviewed
                      ? 'UPDATE REVIEW'
                      : 'SUBMIT REVIEW',
                  style: GoogleFonts.karla(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ─── Star row ─────────────────────────────────────────────────────────────────
class _StarRow extends StatelessWidget {
  final double rating;
  final double size;
  const _StarRow({required this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final pos = i + 1;
        final IconData icon;
        if (rating >= pos) {
          icon = Icons.star_rounded;
        } else if (rating >= pos - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_border_rounded;
        }
        return Icon(icon, size: size, color: AppColors.gold);
      }),
    );
  }
}

// ─── Profile Sheet ─────────────────────────────────────────────────────────────
class _ProfileSheet extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onMyOrders;
  final VoidCallback onSettings;
  final VoidCallback onMessageStaff;

  const _ProfileSheet({
    required this.onLogout,
    required this.onMyOrders,
    required this.onSettings,
    required this.onMessageStaff,
  });

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrdersProvider>();
    final hasActiveOrder = orders.activeOrders.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
      // Material gives the ListTiles below a Material ancestor to paint their
      // ink splash on (the colored Container alone hides those effects).
      child: Material(
        color: Colors.transparent,
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
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined,
                  color: AppColors.gold),
              title:
              Text('My Orders', style: AppTextStyles.bodyLarge(context)),
              subtitle: Text('Track your active order',
                  style: AppTextStyles.bodySmall(context)),
              onTap: onMyOrders,
            ),
            ListTile(
              enabled: hasActiveOrder,
              leading: Icon(
                Icons.chat_bubble_outline_rounded,
                color: hasActiveOrder ? AppColors.gold : AppColors.textMuted,
              ),
              title: Text(
                'Message Staff',
                style: AppTextStyles.bodyLarge(context).copyWith(
                  color: hasActiveOrder ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
              subtitle: Text(
                hasActiveOrder ? 'Chat about your current order' : 'Available when you have an order',
                style: AppTextStyles.bodySmall(context),
              ),
              onTap: hasActiveOrder ? onMessageStaff : null,
            ),
            ListTile(
              leading:
              const Icon(Icons.settings_outlined, color: AppColors.gold),
              title: Text('Account Settings',
                  style: AppTextStyles.bodyLarge(context)),
              subtitle: Text('Profile, password & payment',
                  style: AppTextStyles.bodySmall(context)),
              onTap: onSettings,
            ),
            const SizedBox(height: AppSpacing.sm),
            GoldOutlineButton(label: 'SIGN OUT', onPressed: onLogout),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ───────────────────────────────────────────────────────────────────
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
                : AppColors.error.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
                color: available ? AppColors.success : AppColors.error,
                shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(available ? 'Available' : 'Sold out',
            style: GoogleFonts.karla(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: available ? AppColors.success : AppColors.error)),
      ]),
    );
  }
}

class _FoodImage extends StatelessWidget {
  final String? url;
  final double width, height;
  const _FoodImage(
      {required this.url, required this.width, required this.height});
  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return Image.network(
        url!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _ph(),
      );
    }
    return _ph();
  }

  Widget _ph() => SizedBox(
    width: width,
    height: height,
    child: SvgPicture.asset(
      'assets/images/menu_placeholder.svg',
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholderBuilder: (_) => Container(
        color: AppColors.surfaceWarm,
        child: Center(
          child: CustomPaint(
            size: const Size(40, 40),
            painter: _BowlPainter(),
          ),
        ),
      ),
    ),
  );
}

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
      size: const Size(60, 84),
      painter: _SingleLanternPainter(opacity: 0.3));
}

class _ShimmerBox extends StatefulWidget {
  final double? width;
  final double? height;
  final double radius;
  const _ShimmerBox({this.width, this.height, this.radius = AppRadius.sm});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
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
        final col = Color.lerp(const Color(0xFFEFEBE4),
            const Color(0xFFDDD8CF), _a.value)!;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: col,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

// ─── Painters ──────────────────────────────────────────────────────────────────
class _BellIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.textOnDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final bell = Path()
      ..moveTo(size.width * 0.5, size.height * 0.05)
      ..quadraticBezierTo(size.width * 0.1, size.height * 0.25,
          size.width * 0.1, size.height * 0.65)
      ..lineTo(size.width * 0.9, size.height * 0.65)
      ..quadraticBezierTo(size.width * 0.9, size.height * 0.25,
          size.width * 0.5, size.height * 0.05);
    canvas.drawPath(bell, p);
    canvas.drawLine(Offset(size.width * 0.05, size.height * 0.65),
        Offset(size.width * 0.95, size.height * 0.65), p);
    canvas.drawOval(
        Rect.fromLTWH(size.width * 0.37, size.height * 0.72,
            size.width * 0.26, size.height * 0.16),
        p);
    canvas.drawLine(Offset(size.width * 0.5, 0),
        Offset(size.width * 0.5, size.height * 0.05), p);
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

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
          ..moveTo(2, 2)
          ..lineTo(5, 2)
          ..lineTo(8, 16)
          ..lineTo(20, 16)
          ..lineTo(22, 6)
          ..lineTo(6, 6),
        p);
    final d = Paint()
      ..color = AppColors.textOnDark
      ..style = PaintingStyle.fill;
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
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final w = size.width;
    final h = size.height;
    canvas.drawLine(
        Offset(w / 2, 0), Offset(w / 2, h * 0.1), stroke);
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
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _MiniFabCatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final f = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.fill;
    final s = size.width / 32;
    canvas.scale(s, s);
    canvas.drawOval(const Rect.fromLTWH(6, 8, 20, 18),
        f..color = AppColors.gold.withOpacity(0.7));
    canvas.drawPath(
        Path()
          ..moveTo(8, 14)
          ..lineTo(5, 6)
          ..lineTo(13, 11)
          ..close(),
        f);
    canvas.drawPath(
        Path()
          ..moveTo(24, 14)
          ..lineTo(27, 6)
          ..lineTo(19, 11)
          ..close(),
        f);
    final e = Paint()
      ..color = AppColors.primaryDark
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(13, 14), const Offset(13, 17), e);
    canvas.drawLine(const Offset(19, 14), const Offset(19, 17), e);
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
// Fixed card size for the horizontal item rows in the ALL tab.
// Same proportions as the old 2-column grid (0.72 aspect ratio).
const double _kCategoryCardW = 160;
const double _kCategoryCardH = 222;

// ─── Category Section (used in ALL tab) ───────────────────────────────────────
// One section = category header + horizontal scroll row of item cards.
class _CategorySection extends StatelessWidget {
  final MenuCategory category;
  final List<MenuItem> items;
  final void Function(MenuItem) onItemTap;
  final void Function(MenuItem) onAddToCart;
  final VoidCallback? onViewAll;

  const _CategorySection({
    required this.category,
    required this.items,
    required this.onItemTap,
    required this.onAddToCart,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.md),
          child: Row(
            children: [
              // Gold accent bar
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.name.toUpperCase(),
                  style: GoogleFonts.playfairDisplaySc(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (items.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${items.length}',
                    style: GoogleFonts.karla(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                if (onViewAll != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onViewAll,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 2, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View all',
                            style: GoogleFonts.karla(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.gold,
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              size: 16, color: AppColors.gold),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),

        // ── Horizontal scroll row of item cards ─────────────────────────────
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            child: Text(
              'Nothing here yet.',
              style: AppTextStyles.bodySmall(context),
            ),
          )
        else
          SizedBox(
            height: _kCategoryCardH,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
              itemCount: items.length,
              separatorBuilder: (_, __) =>
              const SizedBox(width: AppSpacing.sm + 2),
              itemBuilder: (ctx, i) => SizedBox(
                width: _kCategoryCardW,
                child: MenuItemGridCard(
                  item: items[i],
                  onTap: () => onItemTap(items[i]),
                  onAdd: () => onAddToCart(items[i]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Featured hero section ────────────────────────────────────────────────────
// Auto-scrolling PageView carousel with dot indicators.
class _FeaturedSection extends StatefulWidget {
  final List<MenuItem> items;
  final void Function(MenuItem) onItemTap;

  const _FeaturedSection({required this.items, required this.onItemTap});

  @override
  State<_FeaturedSection> createState() => _FeaturedSectionState();
}

class _FeaturedSectionState extends State<_FeaturedSection> {
  late final PageController _pageCtrl;
  late final Timer _timer;
  int _currentPage = 0;

  static const _autoScrollInterval = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 1.0);
    _timer = Timer.periodic(_autoScrollInterval, (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % widget.items.length;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.card,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Stack(
            children: [
              // ── Sliding cards fill the panel ────────────────────────────
              SizedBox(
                height: 230,
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: widget.items.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (ctx, i) => _FeaturedCard(
                    item: widget.items[i],
                    onTap: () => widget.onItemTap(widget.items[i]),
                  ),
                ),
              ),
              // ── FEATURED label (top-left) ────────────────────────────────
              Positioned(
                top: 12,
                left: 12,
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'FEATURED',
                      style: GoogleFonts.playfairDisplaySc(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.8,
                        shadows: const [
                          Shadow(color: Color(0x99000000), blurRadius: 6),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.local_fire_department_rounded,
                        size: 16, color: AppColors.gold),
                  ],
                ),
              ),
              // ── Dot indicators (bottom-center) ───────────────────────────
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.items.length, (i) {
                    final active = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.gold
                            : Colors.white.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Featured card (image-forward overlay) ────────────────────────────────────
class _FeaturedCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onTap;

  const _FeaturedCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.card,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _FoodImage(
                  url: item.photoUrl,
                  width: double.infinity,
                  height: double.infinity),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x33000000),
                      Color(0x00000000),
                      Color(0xD9000000),
                    ],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
              ),

              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.playfairDisplaySc(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                        shadows: const [
                          Shadow(color: Color(0x88000000), blurRadius: 5),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        style: GoogleFonts.karla(
                          fontSize: 11.5,
                          color: Colors.white.withOpacity(0.85),
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '₱${item.price.toStringAsFixed(0)}',
                          style: GoogleFonts.playfairDisplaySc(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.goldLight,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                            boxShadow: AppShadows.goldGlow,
                          ),
                          child: const Icon(Icons.arrow_forward_rounded,
                              color: AppColors.primaryDark, size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Press feedback wrapper ───────────────────────────────────────────────────
// Subtle scale-down animation on tap for a tactile feel.
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const _Pressable({
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
  });

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    if (mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}