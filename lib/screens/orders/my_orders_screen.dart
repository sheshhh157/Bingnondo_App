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
              _buildTabBar(),
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

  // ─── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppColors.primaryDark,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: AppColors.textOnDark,
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'My Orders',
              style: GoogleFonts.playfairDisplaySc(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textOnDark,
              ),
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
    );
  }

  // ─── Tab Bar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: AppColors.primaryDark,
      child: TabBar(
        controller: _tabCtrl,
        labelColor: AppColors.gold,
        unselectedLabelColor: AppColors.textOnDark.withOpacity(0.5),
        indicatorColor: AppColors.gold,
        indicatorWeight: 2.5,
        dividerColor: Colors.transparent,
        labelStyle: GoogleFonts.karla(
            fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
        GoogleFonts.karla(fontSize: 13, fontWeight: FontWeight.w400),
        tabs: const [
          Tab(text: 'Active'),
          Tab(text: 'Past Orders'),
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
            // Three lanterns
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomPaint(
                    size: const Size(30, 44),
                    painter: _LanternPainter(tilt: -0.15, opacity: 0.4)),
                const SizedBox(width: 10),
                CustomPaint(
                    size: const Size(40, 58),
                    painter: _LanternPainter(tilt: 0, opacity: 0.55)),
                const SizedBox(width: 10),
                CustomPaint(
                    size: const Size(30, 44),
                    painter: _LanternPainter(tilt: 0.15, opacity: 0.4)),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isActive
                ? AppColors.gold.withOpacity(0.4)
                : AppColors.border,
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            // ── Top row: order number + status badge ─────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: order number + date
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
                  // Right: status badge
                  _StatusBadge(status: order.status),
                ],
              ),
            ),

            // ── Divider ──────────────────────────────────────────────────
            const Divider(
                color: AppColors.border, height: 1, indent: 16, endIndent: 16),

            // ── Bottom row: items count + amount + arrow ──────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
              child: Row(
                children: [
                  // Items count
                  Row(
                    children: [
                      CustomPaint(
                        size: const Size(14, 14),
                        painter: _BowlIconPainter(),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}',
                        style: AppTextStyles.bodySmall(context),
                      ),
                    ],
                  ),

                  const SizedBox(width: AppSpacing.md),

                  // Payment method
                  Row(
                    children: [
                      CustomPaint(
                        size: const Size(14, 14),
                        painter: _PayIconPainter(
                            isGcash: order.paymentMethod == 'gcash'),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        order.paymentMethod == 'gcash'
                            ? 'GCash'
                            : 'Cash on Delivery',
                        style: AppTextStyles.bodySmall(context),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Total
                  Text(
                    '₱${order.totalAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.playfairDisplaySc(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),

                  const SizedBox(width: AppSpacing.sm),

                  // Arrow — only for active / trackable orders
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isActive ? AppColors.gold : AppColors.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),

            // ── Active indicator bar at bottom ────────────────────────────
            if (isActive)
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.6),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(AppRadius.lg),
                    bottomRight: Radius.circular(AppRadius.lg),
                  ),
                ),
              ),
          ],
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
        return Container(
          height: 100,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(height: 14, width: 160,
                      decoration: BoxDecoration(color: col,
                          borderRadius: BorderRadius.circular(AppRadius.sm))),
                  Container(height: 22, width: 80,
                      decoration: BoxDecoration(color: col,
                          borderRadius: BorderRadius.circular(AppRadius.pill))),
                ],
              ),
              Container(height: 10, width: 100,
                  decoration: BoxDecoration(color: col,
                      borderRadius: BorderRadius.circular(AppRadius.sm))),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(height: 10, width: 120,
                      decoration: BoxDecoration(color: col,
                          borderRadius: BorderRadius.circular(AppRadius.sm))),
                  Container(height: 14, width: 70,
                      decoration: BoxDecoration(color: col,
                          borderRadius: BorderRadius.circular(AppRadius.sm))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Painters ──────────────────────────────────────────────────────────────────
class _LanternPainter extends CustomPainter {
  final double tilt;
  final double opacity;
  const _LanternPainter({required this.tilt, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(tilt);
    canvas.translate(-size.width / 2, -size.height / 2);

    final gFill = Paint()
      ..color = AppColors.gold.withOpacity(opacity)
      ..style = PaintingStyle.fill;
    final mFill = Paint()
      ..color = AppColors.primaryDark.withOpacity(opacity)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = AppColors.gold.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final w = size.width;
    final h = size.height;

    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h * 0.08), stroke);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.1, h * 0.06, w * 0.8, h * 0.1),
            const Radius.circular(3)),
        gFill);

    final body = Path()
      ..moveTo(w * 0.05, h * 0.18)
      ..quadraticBezierTo(0, h * 0.5, w * 0.05, h * 0.78)
      ..lineTo(w * 0.95, h * 0.78)
      ..quadraticBezierTo(w, h * 0.5, w * 0.95, h * 0.18)
      ..close();
    canvas.drawPath(body, mFill);
    canvas.drawPath(body, stroke);

    canvas.drawLine(Offset(w / 2, h * 0.18), Offset(w / 2, h * 0.78),
        stroke..color = AppColors.gold.withOpacity(opacity * 0.4)..strokeWidth = 1);
    canvas.drawLine(Offset(w * 0.05, h * 0.48), Offset(w * 0.95, h * 0.48),
        stroke..color = AppColors.gold.withOpacity(opacity * 0.4)..strokeWidth = 1);

    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.1, h * 0.76, w * 0.8, h * 0.08),
            const Radius.circular(3)),
        gFill..color = AppColors.gold.withOpacity(opacity));

    final tp = Paint()
      ..color = AppColors.gold.withOpacity(opacity)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      final x = w * 0.22 + i * w * 0.18;
      canvas.drawLine(Offset(x, h * 0.84),
          Offset(x + (i.isOdd ? 2.5 : -2.5), h), tp);
    }
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _BowlIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.textMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(
        Rect.fromLTWH(
            1, size.height * 0.35, size.width - 2, size.height * 0.55),
        p);
    canvas.drawLine(
        Offset(size.width * 0.18, size.height * 0.35),
        Offset(size.width * 0.82, size.height * 0.35), p);
    canvas.drawArc(
        Rect.fromLTWH(size.width * 0.25, 0, size.width * 0.5, size.height * 0.45),
        3.14 * 1.1, 3.14 * 0.8, false, p);
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _PayIconPainter extends CustomPainter {
  final bool isGcash;
  const _PayIconPainter({required this.isGcash});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.textMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    if (isGcash) {
      // Phone silhouette
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(
                  size.width * 0.2, 0, size.width * 0.6, size.height),
              const Radius.circular(3)),
          p);
      canvas.drawCircle(
          Offset(size.width / 2, size.height * 0.85), 1.5,
          p..style = PaintingStyle.fill);
    } else {
      // Cash / bill silhouette
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(
                  0, size.height * 0.2, size.width, size.height * 0.6),
              const Radius.circular(2)),
          p..style = PaintingStyle.stroke);
      canvas.drawCircle(
          Offset(size.width / 2, size.height / 2), size.width * 0.18,
          p..style = PaintingStyle.stroke);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}