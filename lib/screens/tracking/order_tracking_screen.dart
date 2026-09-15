import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/tracking_models.dart';
import '../../services/order_tracking_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../chat/support_chat_screen.dart';

class OrderTrackingScreen extends StatefulWidget {
  final int orderId;
  final String orderNumber;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  // Pulse for the active status dot
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderTrackingProvider>().loadOrder(widget.orderId);
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
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
          child: Consumer<OrderTrackingProvider>(
            builder: (context, tracking, _) {
              return Column(
                children: [
                  _buildHeader(context, tracking),
                  Expanded(child: _buildBody(context, tracking)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, OrderTrackingProvider tracking) {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Track Order',
                  style: GoogleFonts.playfairDisplaySc(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnDark,
                  ),
                ),
                Text(
                  widget.orderNumber,
                  style: GoogleFonts.karla(
                    fontSize: 12,
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // Chat with staff shortcut
          GestureDetector(
            onTap: () => _openChat(context, tracking.order?.id),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 2, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                    color: AppColors.gold.withOpacity(0.5), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/images/ndo_bot.png',
                      width: 16,
                      height: 16,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => CustomPaint(
                          size: const Size(14, 14),
                          painter: _ChatIconPainter()),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Chat',
                    style: GoogleFonts.karla(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ─── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody(BuildContext context, OrderTrackingProvider tracking) {
    switch (tracking.state) {
      case TrackingLoadState.initial:
      case TrackingLoadState.loading:
        return _buildSkeleton();
      case TrackingLoadState.error:
        return _buildErrorState(context, tracking);
      case TrackingLoadState.loaded:
        return _buildContent(context, tracking);
    }
  }

  Widget _buildContent(BuildContext context, OrderTrackingProvider tracking) {
    final order = tracking.order!;
    final isCancelled = order.status == OrderStatus.cancelled;

    return RefreshIndicator(
      onRefresh: tracking.refresh,
      color: AppColors.gold,
      backgroundColor: AppColors.background,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status hero card
                  _StatusHeroCard(order: order, pulse: _pulse),

                  const SizedBox(height: AppSpacing.lg),

                  // Timeline
                  if (!isCancelled) ...[
                    _buildSectionLabel(context, 'Order Progress'),
                    const SizedBox(height: AppSpacing.sm),
                    _OrderTimeline(order: order, pulse: _pulse),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Delivery info (when assigned)
                  if (order.delivery != null &&
                      order.delivery!.hasRider) ...[
                    _buildSectionLabel(context, 'Delivery Info'),
                    const SizedBox(height: AppSpacing.sm),
                    _DeliveryInfoCard(delivery: order.delivery!),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Order items
                  _buildSectionLabel(context, 'Your Order'),
                  const SizedBox(height: AppSpacing.sm),
                  _OrderItemsCard(order: order),

                  const SizedBox(height: AppSpacing.lg),

                  // Error banner (cancel error)
                  if (tracking.errorMessage != null) ...[
                    StatusBanner(
                        message: tracking.errorMessage!, isError: true),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Cancel button — only while pending
                  if (order.status.canCancel) ...[
                    _CancelOrderButton(
                      isCancelling: tracking.isCancelling,
                      onCancel: () => _confirmCancel(context, tracking),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Chat CTA
                  if (!isCancelled && !order.status.isFinal)
                    _ChatCta(
                      onTap: () => _openChat(context, order.id),
                    ),

                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Row(
      children: [
        CustomPaint(
            size: const Size(12, 12), painter: _LanternDotPainter()),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.label(context)),
      ],
    );
  }

  // ─── Skeleton ──────────────────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBox(height: 120, radius: AppRadius.lg),
          const SizedBox(height: AppSpacing.lg),
          _SkeletonBox(height: 200, radius: AppRadius.lg),
          const SizedBox(height: AppSpacing.lg),
          _SkeletonBox(height: 140, radius: AppRadius.lg),
        ],
      ),
    );
  }

  Widget _buildErrorState(
      BuildContext context, OrderTrackingProvider tracking) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: AppColors.textMuted, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text('Could not load order',
                style: AppTextStyles.headline(context),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(tracking.errorMessage ?? 'Please try again.',
                style: AppTextStyles.bodyMedium(context),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'TRY AGAIN',
              onPressed: tracking.refresh,
              isSmall: true,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context, OrderTrackingProvider tracking) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Cancel order?', style: AppTextStyles.headline(context)),
        content: Text(
          'Are you sure you want to cancel this order? '
              'This may affect your account standing.',
          style: AppTextStyles.bodyMedium(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Keep Order',
                style: AppTextStyles.bodyMedium(context)
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await tracking.cancelOrder();
            },
            child: Text('Cancel Order',
                style: GoogleFonts.karla(
                    color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _openChat(BuildContext context, int? orderId) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) =>
            SupportChatScreen(activeOrderId: orderId),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }
}

// ─── Status Hero Card ──────────────────────────────────────────────────────────
class _StatusHeroCard extends StatelessWidget {
  final OrderDetail order;
  final Animation<double> pulse;

  const _StatusHeroCard({required this.order, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final isCancelled = order.status == OrderStatus.cancelled;
    final isCompleted = order.status == OrderStatus.completed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.goldGlow,
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 4),

              // Animated status icon
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!isCancelled && !isCompleted)
                      AnimatedBuilder(
                        animation: pulse,
                        builder: (_, __) => Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.gold
                                .withOpacity(pulse.value * 0.18),
                          ),
                        ),
                      ),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCancelled
                            ? AppColors.error.withOpacity(0.15)
                            : isCompleted
                            ? AppColors.success.withOpacity(0.15)
                            : AppColors.gold.withOpacity(0.2),
                        border: Border.all(
                          color: isCancelled
                              ? AppColors.error
                              : isCompleted
                              ? AppColors.success
                              : AppColors.gold,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: CustomPaint(
                          size: const Size(28, 28),
                          painter: _StatusIconPainter(order.status),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              Text(
                order.status.label,
                style: GoogleFonts.playfairDisplaySc(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isCancelled
                      ? AppColors.error
                      : isCompleted
                      ? AppColors.success
                      : AppColors.gold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 4),

              Text(
                order.status.description,
                style: GoogleFonts.karla(
                  fontSize: 13,
                  color: AppColors.textOnDark.withOpacity(0.65),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.md),

              // Order number pill
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                      color: AppColors.gold.withOpacity(0.35), width: 1),
                ),
                child: Text(
                  order.orderNumber,
                  style: GoogleFonts.karla(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Order Timeline ────────────────────────────────────────────────────────────
class _OrderTimeline extends StatelessWidget {
  final OrderDetail order;
  final Animation<double> pulse;

  const _OrderTimeline({required this.order, required this.pulse});

  static const _steps = [
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.outForDelivery,
    OrderStatus.completed,
  ];

  @override
  Widget build(BuildContext context) {
    final currentIdx = order.status.timelineIndex;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: List.generate(_steps.length, (i) {
          final step = _steps[i];
          final isDone = i < currentIdx;
          final isActive = i == currentIdx;
          final isLast = i == _steps.length - 1;

          return _TimelineRow(
            status: step,
            isDone: isDone,
            isActive: isActive,
            isLast: isLast,
            pulse: pulse,
          );
        }),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final OrderStatus status;
  final bool isDone;
  final bool isActive;
  final bool isLast;
  final Animation<double> pulse;

  const _TimelineRow({
    required this.status,
    required this.isDone,
    required this.isActive,
    required this.isLast,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot + line column
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Dot
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Center(
                    child: isActive
                        ? AnimatedBuilder(
                      animation: pulse,
                      builder: (_, __) => Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold
                              .withOpacity(0.25 * pulse.value + 0.1),
                        ),
                        child: Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                      ),
                    )
                        : Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? AppColors.gold
                            : AppColors.border,
                        border: Border.all(
                          color: isDone
                              ? AppColors.gold
                              : AppColors.border,
                          width: 2,
                        ),
                      ),
                      child: isDone
                          ? const Icon(Icons.check_rounded,
                          size: 7, color: AppColors.primaryDark)
                          : null,
                    ),
                  ),
                ),
                // Connector line
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          color: isDone
                              ? AppColors.gold.withOpacity(0.6)
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.sm),

          // Label
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: 6,
                bottom: isLast ? 0 : AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.label,
                    style: GoogleFonts.karla(
                      fontSize: 14,
                      fontWeight: isActive
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isActive
                          ? AppColors.primary
                          : isDone
                          ? AppColors.textSecondary
                          : AppColors.textMuted,
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(height: 2),
                    Text(
                      status.description,
                      style: GoogleFonts.karla(
                        fontSize: 12,
                        color: AppColors.gold,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Delivery Info Card ────────────────────────────────────────────────────────
class _DeliveryInfoCard extends StatelessWidget {
  final DeliveryInfo delivery;
  const _DeliveryInfoCard({required this.delivery});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.gold.withOpacity(0.3), width: 1.5),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(22, 22),
                painter: delivery.isLalamove
                    ? _LalamoveIconPainter()
                    : _RiderIconPainter(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  delivery.isLalamove ? 'Lalamove Rider' : 'Bingnondo Rider',
                  style: GoogleFonts.karla(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (delivery.riderName != null) ...[
                  const SizedBox(height: 2),
                  Text(delivery.riderName!,
                      style: AppTextStyles.bodyMedium(context)),
                ],
                if (delivery.riderContact != null) ...[
                  const SizedBox(height: 2),
                  Text(delivery.riderContact!,
                      style: AppTextStyles.bodyMedium(context)
                          .copyWith(color: AppColors.gold)),
                ],
                if (delivery.lalamoveBookingId != null) ...[
                  const SizedBox(height: 2),
                  Text('Booking: ${delivery.lalamoveBookingId}',
                      style: AppTextStyles.caption(context)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Order Items Card ──────────────────────────────────────────────────────────
class _OrderItemsCard extends StatelessWidget {
  final OrderDetail order;
  const _OrderItemsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          ...order.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.quantity}×',
                  style: GoogleFonts.karla(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          style: AppTextStyles.bodyMedium(context)
                              .copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              fontSize: 13)),
                      if (item.note != null && item.note!.isNotEmpty)
                        Text('Note: ${item.note}',
                            style: AppTextStyles.caption(context)
                                .copyWith(
                                color:
                                AppColors.textMuted,
                                fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
                Text(
                  '₱${item.subtotal.toStringAsFixed(2)}',
                  style: GoogleFonts.karla(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          )),

          const Divider(color: AppColors.border, height: AppSpacing.lg),

          if (order.notes != null && order.notes!.isNotEmpty) ...[
            Text('Order note: ${order.notes}',
                style: AppTextStyles.caption(context)
                    .copyWith(fontStyle: FontStyle.italic)),
            const SizedBox(height: AppSpacing.sm),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total',
                  style: AppTextStyles.label(context)
                      .copyWith(color: AppColors.textPrimary)),
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

          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text('Payment: ',
                  style: AppTextStyles.caption(context)),
              Text(
                order.paymentMethod == 'gcash' ? 'GCash' : 'Cash on Delivery',
                style: AppTextStyles.caption(context)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Cancel Button ─────────────────────────────────────────────────────────────
class _CancelOrderButton extends StatelessWidget {
  final bool isCancelling;
  final VoidCallback onCancel;
  const _CancelOrderButton(
      {required this.isCancelling, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isCancelling ? null : onCancel,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: BorderSide(
            color: isCancelling
                ? AppColors.error.withOpacity(0.3)
                : AppColors.error,
            width: 1.5),
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      child: isCancelling
          ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              color: AppColors.error, strokeWidth: 2))
          : Text(
        'CANCEL ORDER',
        style: GoogleFonts.karla(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.error,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Chat CTA ─────────────────────────────────────────────────────────────────
class _ChatCta extends StatelessWidget {
  final VoidCallback onTap;
  const _ChatCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceWarm,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/ndo_bot.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => CustomPaint(
                      size: const Size(18, 18),
                      painter: _ChatIconPainter()),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Questions about your order?',
                      style: GoogleFonts.karla(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  Text('Chat with our staff directly.',
                      style: AppTextStyles.caption(context)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.gold, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton Box ──────────────────────────────────────────────────────────────
class _SkeletonBox extends StatefulWidget {
  final double height;
  final double radius;
  const _SkeletonBox({required this.height, required this.radius});

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
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
      builder: (_, __) => Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
              const Color(0xFFEFEBE4), const Color(0xFFDDD8CF), _anim.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

// ─── Painters ──────────────────────────────────────────────────────────────────

class _LanternDotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(
        Rect.fromLTWH(size.width * 0.1, size.height * 0.2, size.width * 0.8,
            size.height * 0.6),
        Paint()
          ..color = AppColors.gold
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StatusIconPainter extends CustomPainter {
  final OrderStatus status;
  const _StatusIconPainter(this.status);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = status == OrderStatus.cancelled
          ? AppColors.error
          : status == OrderStatus.completed
          ? AppColors.success
          : AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (status) {
      case OrderStatus.cancelled:
        canvas.drawLine(
            Offset(size.width * 0.2, size.height * 0.2),
            Offset(size.width * 0.8, size.height * 0.8), p);
        canvas.drawLine(
            Offset(size.width * 0.8, size.height * 0.2),
            Offset(size.width * 0.2, size.height * 0.8), p);
        break;
      case OrderStatus.completed:
        canvas.drawPath(
            Path()
              ..moveTo(size.width * 0.15, size.height * 0.5)
              ..lineTo(size.width * 0.4, size.height * 0.75)
              ..lineTo(size.width * 0.85, size.height * 0.25),
            p);
        break;
      case OrderStatus.pending:
        canvas.drawCircle(Offset(size.width / 2, size.height / 2),
            size.width * 0.38, p);
        canvas.drawLine(
            Offset(size.width / 2, size.height * 0.25),
            Offset(size.width / 2, size.height / 2), p);
        canvas.drawLine(
            Offset(size.width / 2, size.height / 2),
            Offset(size.width * 0.68, size.height * 0.62), p);
        break;
      case OrderStatus.preparing:
      // flame / fire shape
        final flame = Path()
          ..moveTo(size.width * 0.5, size.height * 0.1)
          ..quadraticBezierTo(size.width * 0.8, size.height * 0.3,
              size.width * 0.75, size.height * 0.65)
          ..quadraticBezierTo(size.width * 0.65, size.height * 0.5,
              size.width * 0.5, size.height * 0.9)
          ..quadraticBezierTo(size.width * 0.35, size.height * 0.5,
              size.width * 0.25, size.height * 0.65)
          ..quadraticBezierTo(size.width * 0.2, size.height * 0.3,
              size.width * 0.5, size.height * 0.1);
        canvas.drawPath(flame, p);
        break;
      case OrderStatus.outForDelivery:
      // motorbike simplified
        canvas.drawCircle(
            Offset(size.width * 0.22, size.height * 0.7), size.width * 0.2, p);
        canvas.drawCircle(
            Offset(size.width * 0.78, size.height * 0.7), size.width * 0.2, p);
        canvas.drawPath(
            Path()
              ..moveTo(size.width * 0.22, size.height * 0.7)
              ..lineTo(size.width * 0.42, size.height * 0.3)
              ..lineTo(size.width * 0.65, size.height * 0.3)
              ..lineTo(size.width * 0.78, size.height * 0.7),
            p);
        break;
      default:
      // checkmark for confirmed/ready
        canvas.drawPath(
            Path()
              ..moveTo(size.width * 0.15, size.height * 0.5)
              ..lineTo(size.width * 0.4, size.height * 0.75)
              ..lineTo(size.width * 0.85, size.height * 0.25),
            p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChatIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, size.width * 0.9, size.height * 0.8),
            const Radius.circular(5)),
        p);
    canvas.drawLine(
        Offset(size.width * 0.1, size.height * 0.8),
        Offset(0, size.height), p);
    for (int i = 0; i < 3; i++) {
      canvas.drawLine(
          Offset(size.width * (0.2 + i * 0.25), size.height * 0.35),
          Offset(size.width * (0.2 + i * 0.25), size.height * 0.45), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RiderIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(
        Offset(size.width * 0.22, size.height * 0.65), size.width * 0.2, p);
    canvas.drawCircle(
        Offset(size.width * 0.78, size.height * 0.65), size.width * 0.2, p);
    canvas.drawPath(
        Path()
          ..moveTo(size.width * 0.22, size.height * 0.65)
          ..lineTo(size.width * 0.42, size.height * 0.28)
          ..lineTo(size.width * 0.65, size.height * 0.28)
          ..lineTo(size.width * 0.78, size.height * 0.65)
          ..moveTo(size.width * 0.5, size.height * 0.28)
          ..lineTo(size.width * 0.5, size.height * 0.12)
          ..lineTo(size.width * 0.62, size.height * 0.12),
        p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LalamoveIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(
                0, size.height * 0.2, size.width * 0.72, size.height * 0.55),
            const Radius.circular(3)),
        p);
    canvas.drawPath(
        Path()
          ..moveTo(size.width * 0.72, size.height * 0.35)
          ..lineTo(size.width * 0.98, size.height * 0.45)
          ..lineTo(size.width * 0.98, size.height * 0.75)
          ..lineTo(size.width * 0.72, size.height * 0.75),
        p);
    canvas.drawCircle(
        Offset(size.width * 0.2, size.height * 0.8), size.width * 0.09, p);
    canvas.drawCircle(
        Offset(size.width * 0.58, size.height * 0.8), size.width * 0.09, p);
    canvas.drawCircle(
        Offset(size.width * 0.88, size.height * 0.8), size.width * 0.09, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}