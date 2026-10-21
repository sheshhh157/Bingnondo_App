import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/order_summary_model.dart';
import '../../models/tracking_models.dart';
import '../../services/orders_provider.dart';
import '../../services/order_tracking_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../tracking/order_tracking_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdersProvider>().loadOrders();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _openTracking(BuildContext context, OrderSummary order) {
    context.read<OrderTrackingProvider>().loadOrder(order.id);
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => OrderTrackingScreen(
          orderId: order.id,
          orderNumber: order.orderNumber,
        ),
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
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: Consumer<OrdersProvider>(
                  builder: (context, provider, _) =>
                      _buildBody(context, provider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header (title + tabs, rounded dark panel) ──────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius:
        BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Orders',
                      style: GoogleFonts.playfairDisplaySc(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textOnDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Track and review your orders',
                      style: GoogleFonts.karla(
                        fontSize: 11,
                        color: AppColors.textOnDark.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // Refresh button
              Consumer<OrdersProvider>(
                builder: (_, provider, __) => IconButton(
                  icon: provider.state == OrdersLoadState.loading
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: AppColors.gold, strokeWidth: 2),
                  )
                      : const Icon(Icons.refresh_rounded,
                      color: AppColors.gold, size: 20),
                  onPressed: provider.state == OrdersLoadState.loading
                      ? null
                      : () => provider.refresh(),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildTabBar(),
        ],
      ),
    );
  }

  // ─── Tab Bar (pill segmented control) ───────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: TabBar(
        controller: _tabCtrl,
        labelColor: AppColors.primaryDark,
        unselectedLabelColor: AppColors.textOnDark.withOpacity(0.7),
        indicator: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: EdgeInsets.zero,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(AppRadius.pill),
        overlayColor: WidgetStateProperty.all(
            AppColors.gold.withOpacity(0.12)),
        labelStyle: GoogleFonts.karla(
            fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.karla(
            fontSize: 13, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(height: 36, text: 'Active'),
          Tab(height: 36, text: 'Past Orders'),
        ],
      ),
    );
  }

  // ─── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody(BuildContext context, OrdersProvider provider) {
    switch (provider.state) {
      case OrdersLoadState.initial:
      case OrdersLoadState.loading:
        return _buildSkeleton();
      case OrdersLoadState.error:
        return _buildError(context, provider);
      case OrdersLoadState.loaded:
        return TabBarView(
          controller: _tabCtrl,
          children: [
            _buildOrderList(context, provider.activeOrders, isActive: true),
            _buildOrderList(context, provider.pastOrders, isActive: false),
          ],
        );
    }
  }

  Widget _buildOrderList(
      BuildContext context, List<OrderSummary> orders,
      {required bool isActive}) {
    if (orders.isEmpty) {
      return _buildEmpty(context, isActive: isActive);
    }

    return RefreshIndicator(
      onRefresh: () => context.read<OrdersProvider>().refresh(),
      color: AppColors.gold,
      backgroundColor: AppColors.background,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (ctx, i) => _OrderCard(
          order: orders[i],
          onTap: () => _openTracking(ctx, orders[i]),
        ),
      ),
    );
  }

  // ─── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmpty(BuildContext context, {required bool isActive}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon badge
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withOpacity(0.1),
                border: Border.all(
                    color: AppColors.gold.withOpacity(0.3), width: 1.5),
              ),
              child: Icon(
                isActive
                    ? Icons.receipt_long_rounded
                    : Icons.history_rounded,
                color: AppColors.gold,
                size: 40,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              isActive ? 'No active orders' : 'No past orders yet',
              style: AppTextStyles.headline(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isActive
                  ? 'Ready to order? Browse our menu and place\nyour first Bingnondo order!'
                  : 'Your completed and cancelled orders\nwill appear here.',
              style: AppTextStyles.bodyMedium(context),
              textAlign: TextAlign.center,
            ),
            if (isActive) ...[
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'BROWSE MENU',
                onPressed: () => Navigator.pop(context),
                isSmall: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Skeleton ──────────────────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, __) => const _OrderCardSkeleton(),
    );
  }

  Widget _buildError(BuildContext context, OrdersProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: AppColors.textMuted, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text('Could not load orders',
                style: AppTextStyles.headline(context),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(provider.errorMessage ?? 'Please try again.',
                style: AppTextStyles.bodyMedium(context),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'TRY AGAIN',
              onPressed: provider.refresh,
              isSmall: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Order Card ────────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final OrderSummary order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = order.isActive;
    final isGcash  = order.paymentMethod == 'gcash';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: AppColors.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: isActive
                ? AppColors.gold.withOpacity(0.4)
                : AppColors.border,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            children: [
              // ── Header: status icon + order number/date + badge ──────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
                child: Row(
                  children: [
                    _StatusIcon(status: order.status),
                    const SizedBox(width: AppSpacing.sm + 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.orderNumber,
                            style: GoogleFonts.playfairDisplaySc(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formatDate(order.createdAt),
                            style: AppTextStyles.caption(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StatusBadge(status: order.status),
                  ],
                ),
              ),

              // ── Divider ──────────────────────────────────────────────────
              const Divider(
                  color: AppColors.border, height: 1, indent: 16, endIndent: 16),

              // ── Meta row: chips + total ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                    AppSpacing.sm + 2, AppSpacing.md, AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs + 2,
                        children: [
                          _MetaChip(
                            icon: Icons.ramen_dining_rounded,
                            label: '${order.itemCount} '
                                '${order.itemCount == 1 ? 'item' : 'items'}',
                          ),
                          _MetaChip(
                            icon: isGcash
                                ? Icons.smartphone_rounded
                                : Icons.payments_rounded,
                            label: isGcash ? 'GCash' : 'Cash',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '₱${order.totalAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.playfairDisplaySc(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Footer ───────────────────────────────────────────────────
              if (isActive)
                Container(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                      AppSpacing.sm + 2, AppSpacing.md, AppSpacing.sm + 2),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.07),
                    border: Border(
                      top:
                      BorderSide(color: AppColors.gold.withOpacity(0.2)),
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(AppRadius.lg),
                      bottomRight: Radius.circular(AppRadius.lg),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_shipping_rounded,
                          color: AppColors.gold, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          order.status.description,
                          style: GoogleFonts.karla(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Track',
                        style: GoogleFonts.karla(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gold,
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.gold, size: 18),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm + 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'View details',
                        style: GoogleFonts.karla(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textMuted, size: 18),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $h:$m $period';
  }
}

// ─── Status Icon ───────────────────────────────────────────────────────────────
class _StatusIcon extends StatelessWidget {
  final OrderStatus status;
  const _StatusIcon({required this.status});

  IconData get _icon {
    switch (status) {
      case OrderStatus.pending:
        return Icons.hourglass_top_rounded;
      case OrderStatus.confirmed:
        return Icons.verified_rounded;
      case OrderStatus.preparing:
        return Icons.soup_kitchen_rounded;
      case OrderStatus.ready:
        return Icons.restaurant_rounded;
      case OrderStatus.outForDelivery:
        return Icons.delivery_dining_rounded;
      case OrderStatus.completed:
        return Icons.check_circle_rounded;
      case OrderStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }

  Color get _color {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.textMuted;
      case OrderStatus.completed:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
      default:
        return AppColors.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Center(child: Icon(_icon, color: color, size: 20)),
    );
  }
}

// ─── Meta Chip ─────────────────────────────────────────────────────────────────
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.karla(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status Badge ──────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final OrderStatus status;
  const _StatusBadge({required this.status});

  Color get _bgColor {
    switch (status) {
      case OrderStatus.completed:
        return AppColors.success.withOpacity(0.1);
      case OrderStatus.cancelled:
        return AppColors.error.withOpacity(0.08);
      case OrderStatus.pending:
        return AppColors.textMuted.withOpacity(0.1);
      default:
        return AppColors.gold.withOpacity(0.12);
    }
  }

  Color get _borderColor {
    switch (status) {
      case OrderStatus.completed:
        return AppColors.success.withOpacity(0.35);
      case OrderStatus.cancelled:
        return AppColors.error.withOpacity(0.3);
      case OrderStatus.pending:
        return AppColors.textMuted.withOpacity(0.3);
      default:
        return AppColors.gold.withOpacity(0.4);
    }
  }

  Color get _textColor {
    switch (status) {
      case OrderStatus.completed:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
      case OrderStatus.pending:
        return AppColors.textMuted;
      default:
        return AppColors.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: _borderColor, width: 1),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.karla(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _textColor,
        ),
      ),
    );
  }
}

// ─── Skeleton Card ─────────────────────────────────────────────────────────────
class _OrderCardSkeleton extends StatefulWidget {
  const _OrderCardSkeleton();
  @override
  State<_OrderCardSkeleton> createState() => _OrderCardSkeletonState();
}

class _OrderCardSkeletonState extends State<_OrderCardSkeleton>
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
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) {
        final col = Color.lerp(
            const Color(0xFFEFEBE4), const Color(0xFFDDD8CF), _a.value)!;
        Widget bar(double w, double h, [double r = AppRadius.sm]) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
              color: col, borderRadius: BorderRadius.circular(r)),
        );
        return Container(
          height: 132,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration:
                    BoxDecoration(color: col, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(150, 14),
                        const SizedBox(height: 6),
                        bar(96, 10),
                      ],
                    ),
                  ),
                  bar(72, 24, AppRadius.pill),
                ],
              ),
              bar(double.infinity, 1),
              Row(
                children: [
                  bar(70, 18, AppRadius.pill),
                  const SizedBox(width: AppSpacing.sm),
                  bar(64, 18, AppRadius.pill),
                  const Spacer(),
                  bar(64, 16),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── (Custom painters for the old card/empty-state were removed in the ───────
//     My Orders redesign — Material icons now handle the visuals.)