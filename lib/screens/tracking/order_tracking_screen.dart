import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';        // §1.9 rider map
import 'package:latlong2/latlong.dart' hide Path;               // §1.9 LatLng
import '../../models/tracking_models.dart';
import '../../services/gcash_receipt_service.dart';
import '../../services/order_tracking_provider.dart';
import '../../services/orders_service.dart';
import '../../services/socket_service.dart';
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

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  // Steam animation for "Preparing" hero icon
  late AnimationController _steamCtrl;
  late Animation<double> _steam;

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

    _steamCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _steam = CurvedAnimation(parent: _steamCtrl, curve: Curves.easeInOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Join the per-order room so live `order_status_update` events reach the
      // stepper instantly instead of waiting for the 15 s poll fallback.
      SocketService.instance.joinOrderRoom(widget.orderId);
      context.read<OrderTrackingProvider>().loadOrder(widget.orderId);
    });
  }

  @override
  void dispose() {
    SocketService.instance.leaveOrderRoom(widget.orderId);
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _steamCtrl.dispose();
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
      decoration: const BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius:
        BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
      ),
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
          // Chat shortcut
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
                  CustomPaint(
                      size: const Size(14, 14),
                      painter: _ChatIconPainter()),
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
                  // ── Option C: Split hero (compact) ───────────────────────
                  _StatusHeroCard(
                    order: order,
                    pulse: _pulse,
                    steam: _steam,
                  ),

                  // ── GCash rejection banner + re-upload ────────────────────
                  if (order.isGcash && order.isPaymentRejected) ...[
                    const SizedBox(height: AppSpacing.md),
                    _GcashRejectionBanner(
                      orderId:         order.id,
                      rejectionReason: order.rejectionReason,
                      onUploaded:      tracking.refresh,
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // ── Option Z: Bigger vertical timeline ───────────────────
                  if (!isCancelled) ...[
                    _buildSectionLabel(context, 'Order Progress'),
                    const SizedBox(height: AppSpacing.sm),
                    _OrderTimeline(order: order, pulse: _pulse),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // ── §1.9 Rider live-location map ─────────────────────────
                  if (tracking.showRiderMap) ...[
                    _buildSectionLabel(context, 'Rider Location'),
                    const SizedBox(height: AppSpacing.sm),
                    _RiderMapCard(
                      riderLocation: tracking.riderLocation!,
                      deliveryInfo:  order.delivery,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Delivery info
                  if (order.delivery != null && order.delivery!.hasRider) ...[
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

                  if (tracking.errorMessage != null) ...[
                    StatusBanner(
                        message: tracking.errorMessage!, isError: true),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  if (order.status.canCancel) ...[
                    _CancelOrderButton(
                      isCancelling: tracking.isCancelling,
                      onCancel: () => _confirmCancel(context, tracking),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  if (!isCancelled && !order.status.isFinal)
                    _ChatCta(onTap: () => _openChat(context, order.id)),

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
        Text(
          label.toUpperCase(),
          style: AppTextStyles.label(context).copyWith(
            fontSize: 12,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBox(height: 132, radius: AppRadius.lg),
          const SizedBox(height: AppSpacing.lg),
          _SkeletonBox(height: 320, radius: AppRadius.lg),
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

// ─── Option C: Status Hero Card (split layout, compact) ───────────────────────
//
// Smaller card — icon LEFT, text RIGHT — frees up more vertical space for
// the timeline below. Icon changes per status and animates when active.
class _StatusHeroCard extends StatelessWidget {
  final OrderDetail order;
  final Animation<double> pulse;
  final Animation<double> steam;

  const _StatusHeroCard({
    required this.order,
    required this.pulse,
    required this.steam,
  });

  @override
  Widget build(BuildContext context) {
    final isCancelled = order.status == OrderStatus.cancelled;
    final isCompleted = order.status == OrderStatus.completed;
    final isFinal     = isCancelled || isCompleted;

    final Color statusColor = isCancelled
        ? AppColors.error
        : isCompleted
        ? AppColors.success
        : AppColors.gold;

    final lastUpdate = order.updatedAt ?? order.createdAt;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md + 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.goldGlow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Animated status icon ────────────────────────────────────
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulse ring — only for active (not final) states
                    if (!isFinal)
                      AnimatedBuilder(
                        animation: pulse,
                        builder: (_, __) => Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.gold
                                .withOpacity(pulse.value * 0.15),
                          ),
                        ),
                      ),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCancelled
                            ? AppColors.error.withOpacity(0.15)
                            : isCompleted
                            ? AppColors.success.withOpacity(0.12)
                            : AppColors.gold.withOpacity(0.16),
                        border: Border.all(color: statusColor, width: 2),
                      ),
                      child: Center(
                        child: _HeroStatusIcon(
                          status: order.status,
                          steam: steam,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: AppSpacing.md),

              // ── Text block ──────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Micro label
                    Text(
                      'Current status',
                      style: GoogleFonts.karla(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textOnDark.withOpacity(0.4),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      order.status.label,
                      style: GoogleFonts.playfairDisplaySc(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.status.description,
                      style: GoogleFonts.karla(
                        fontSize: 12,
                        color: AppColors.textOnDark.withOpacity(0.6),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                            color: AppColors.gold.withOpacity(0.35), width: 1),
                      ),
                      child: Text(
                        order.orderNumber,
                        style: GoogleFonts.karla(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm + 2),
          Divider(color: AppColors.textOnDark.withOpacity(0.12), height: 1),
          const SizedBox(height: AppSpacing.sm + 2),

          // ── Footer: last updated + live indicator ─────────────────────────
          Row(
            children: [
              Icon(Icons.schedule_rounded,
                  size: 13, color: AppColors.textOnDark.withOpacity(0.5)),
              const SizedBox(width: 5),
              Text(
                'Updated ${_timeAgo(lastUpdate)}',
                style: GoogleFonts.karla(
                  fontSize: 11,
                  color: AppColors.textOnDark.withOpacity(0.55),
                ),
              ),
              const Spacer(),
              if (!isFinal)
                AnimatedBuilder(
                  animation: pulse,
                  builder: (_, __) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold
                              .withOpacity(0.4 + 0.6 * pulse.value),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Live updates',
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
    );
  }
}

// ─── Relative time helper ───────────────────────────────────────────────────────
String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.month}/${dt.day}';
}

// ─── Hero status icon — changes per order status ───────────────────────────────
// Preparing → steaming bowl (with animation)
// Out for Delivery → motorbike
// Completed → checkmark
// Cancelled → X
// Everything else → clock/check
class _HeroStatusIcon extends StatelessWidget {
  final OrderStatus status;
  final Animation<double> steam;
  final Color color;

  const _HeroStatusIcon({
    required this.status,
    required this.steam,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case OrderStatus.preparing:
        return AnimatedBuilder(
          animation: steam,
          builder: (_, __) => CustomPaint(
            size: const Size(28, 28),
            painter: _SteamingBowlPainter(color: color, steamOffset: steam.value),
          ),
        );
      case OrderStatus.outForDelivery:
        return CustomPaint(
          size: const Size(28, 28),
          painter: _BikeIconPainter(color: color),
        );
      case OrderStatus.completed:
        return CustomPaint(
          size: const Size(28, 28),
          painter: _CheckIconPainter(color: color),
        );
      case OrderStatus.cancelled:
        return CustomPaint(
          size: const Size(28, 28),
          painter: _XIconPainter(color: color),
        );
      case OrderStatus.pending:
        return CustomPaint(
          size: const Size(28, 28),
          painter: _ClockIconPainter(color: color),
        );
      case OrderStatus.confirmed:
      case OrderStatus.ready:
        return CustomPaint(
          size: const Size(28, 28),
          painter: _CheckIconPainter(color: color),
        );
    }
  }
}

// ─── Option Z: Order Timeline (bigger rows, unique icon per step) ──────────────
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
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
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
          // ── Icon + connector line ─────────────────────────────────────────
          SizedBox(
            width: 44,
            child: Column(
              children: [
                // Icon circle — bigger than before (44px)
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: isActive
                        ? AnimatedBuilder(
                      animation: pulse,
                      builder: (_, __) => Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold
                              .withOpacity(0.12 * pulse.value + 0.06),
                          border: Border.all(
                              color: AppColors.gold, width: 2),
                        ),
                        child: Center(
                          child: CustomPaint(
                            size: const Size(22, 22),
                            painter: _TimelineIconPainter(
                              status: status,
                              isDone: isDone,
                              isActive: isActive,
                            ),
                          ),
                        ),
                      ),
                    )
                        : Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? AppColors.gold
                            : AppColors.surfaceWarm,
                        border: isDone
                            ? null
                            : Border.all(
                            color: AppColors.border, width: 1.5),
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check_rounded,
                            size: 18,
                            color: AppColors.primaryDark)
                            : CustomPaint(
                          size: const Size(22, 22),
                          painter: _TimelineIconPainter(
                            status: status,
                            isDone: isDone,
                            isActive: isActive,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Connector
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: isDone
                              ? AppColors.gold.withOpacity(0.7)
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.md),

          // ── Text ──────────────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: 10,
                bottom: isLast ? 4 : AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.label,
                    style: GoogleFonts.karla(
                      fontSize: 15,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive
                          ? AppColors.primary
                          : isDone
                          ? AppColors.textSecondary
                          : AppColors.textMuted,
                      height: 1.2,
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(height: 3),
                    Text(
                      status.description,
                      style: GoogleFonts.karla(
                        fontSize: 12,
                        color: AppColors.gold,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ] else if (isDone) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Done',
                      style: GoogleFonts.karla(
                        fontSize: 11,
                        color: AppColors.textMuted,
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

// ─── Timeline Icon Painter — unique icon per step ─────────────────────────────
class _TimelineIconPainter extends CustomPainter {
  final OrderStatus status;
  final bool isDone;
  final bool isActive;

  const _TimelineIconPainter({
    required this.status,
    required this.isDone,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final color = isActive
        ? AppColors.gold
        : isDone
        ? AppColors.primaryDark // on gold bg
        : AppColors.textMuted;

    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    switch (status) {
    // Pending → clock
      case OrderStatus.pending:
        canvas.drawCircle(Offset(w / 2, h / 2), w * 0.42, p);
        canvas.drawLine(
            Offset(w / 2, h * 0.25), Offset(w / 2, h / 2), p);
        canvas.drawLine(
            Offset(w / 2, h / 2), Offset(w * 0.68, h * 0.62), p);
        break;

    // Confirmed → document tick
      case OrderStatus.confirmed:
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(w * 0.15, 0, w * 0.7, h),
                const Radius.circular(3)),
            p);
        canvas.drawPath(
            Path()
              ..moveTo(w * 0.3, h * 0.5)
              ..lineTo(w * 0.45, h * 0.65)
              ..lineTo(w * 0.7, h * 0.38),
            p..strokeWidth = 1.8);
        break;

    // Preparing → steaming bowl (static for timeline, animated only in hero)
      case OrderStatus.preparing:
      // Bowl
        canvas.drawOval(
            Rect.fromLTWH(w * 0.05, h * 0.5, w * 0.9, h * 0.38),
            p..strokeWidth = 1.5);
        canvas.drawLine(
            Offset(w * 0.05, h * 0.69), Offset(w * 0.95, h * 0.69),
            p..strokeWidth = 1.2);
        // Three steam wisps
        for (int i = 0; i < 3; i++) {
          final x = w * (0.28 + i * 0.22);
          canvas.drawPath(
              Path()
                ..moveTo(x, h * 0.48)
                ..quadraticBezierTo(x + w * 0.07, h * 0.35, x, h * 0.22)
                ..quadraticBezierTo(x - w * 0.07, h * 0.09, x, 0),
              p..strokeWidth = 1.2
                ..color = color.withOpacity(0.65));
        }
        break;

    // Ready → box / package
      case OrderStatus.ready:
      // Box body
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(w * 0.1, h * 0.3, w * 0.8, h * 0.65),
                const Radius.circular(2)),
            p..strokeWidth = 1.5..color = color);
        // Box lid
        canvas.drawPath(
            Path()
              ..moveTo(0, h * 0.3)
              ..lineTo(w * 0.5, h * 0.1)
              ..lineTo(w, h * 0.3),
            p..strokeWidth = 1.4);
        // Box stripe
        canvas.drawLine(
            Offset(w / 2, h * 0.1), Offset(w / 2, h * 0.95),
            p..strokeWidth = 1.2..color = color.withOpacity(0.5));
        break;

    // Out for delivery → motorbike
      case OrderStatus.outForDelivery:
      // Wheels
        canvas.drawCircle(
            Offset(w * 0.22, h * 0.72), w * 0.19,
            p..strokeWidth = 1.6..color = color);
        canvas.drawCircle(
            Offset(w * 0.78, h * 0.72), w * 0.19, p);
        // Frame
        canvas.drawPath(
            Path()
              ..moveTo(w * 0.22, h * 0.72)
              ..lineTo(w * 0.4, h * 0.32)
              ..lineTo(w * 0.62, h * 0.32)
              ..lineTo(w * 0.78, h * 0.72)
              ..moveTo(w * 0.5, h * 0.32)
              ..lineTo(w * 0.5, h * 0.16)
              ..lineTo(w * 0.62, h * 0.16),
            p..strokeWidth = 1.5);
        break;

    // Completed → checkmark in circle
      case OrderStatus.completed:
        canvas.drawCircle(Offset(w / 2, h / 2), w * 0.42,
            p..strokeWidth = 1.5..color = color);
        canvas.drawPath(
            Path()
              ..moveTo(w * 0.24, h * 0.52)
              ..lineTo(w * 0.42, h * 0.70)
              ..lineTo(w * 0.76, h * 0.34),
            p..strokeWidth = 2.0);
        break;

      case OrderStatus.cancelled:
        canvas.drawLine(Offset(w * 0.3, h * 0.3), Offset(w * 0.7, h * 0.7), p);
        canvas.drawLine(Offset(w * 0.7, h * 0.3), Offset(w * 0.3, h * 0.7), p);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Hero Icon Painters ────────────────────────────────────────────────────────

class _SteamingBowlPainter extends CustomPainter {
  final Color color;
  final double steamOffset; // 0.0 → 1.0, drives upward steam

  const _SteamingBowlPainter(
      {required this.color, required this.steamOffset});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Bowl rim
    canvas.drawOval(
        Rect.fromLTWH(w * 0.05, h * 0.52, w * 0.9, h * 0.32), p);
    // Bowl bottom curve
    canvas.drawPath(
        Path()
          ..moveTo(w * 0.05, h * 0.68)
          ..quadraticBezierTo(w * 0.05, h * 0.96, w / 2, h * 0.96)
          ..quadraticBezierTo(w * 0.95, h * 0.96, w * 0.95, h * 0.68),
        p);

    // Animated steam wisps
    final steamDy = steamOffset * h * 0.18;
    final steamAlpha = (1 - steamOffset * 0.6).clamp(0.0, 1.0);

    canvas.save();
    canvas.translate(0, -steamDy);
    for (int i = 0; i < 3; i++) {
      final x = w * (0.28 + i * 0.22);
      canvas.drawPath(
          Path()
            ..moveTo(x, h * 0.50)
            ..quadraticBezierTo(x + w * 0.09, h * 0.35, x, h * 0.20)
            ..quadraticBezierTo(x - w * 0.09, h * 0.05, x, 0),
          p
            ..color = color.withOpacity(steamAlpha * 0.85)
            ..strokeWidth = 1.5);
    }
    canvas.restore();

    // Noodle lines (decorative)
    for (int i = 0; i < 3; i++) {
      final y = h * (0.57 + i * 0.06);
      canvas.drawLine(
          Offset(w * 0.22, y), Offset(w * 0.78, y),
          p..color = color.withOpacity(0.35)..strokeWidth = 1.2);
    }
  }

  @override
  bool shouldRepaint(covariant _SteamingBowlPainter old) =>
      old.steamOffset != steamOffset;
}

class _BikeIconPainter extends CustomPainter {
  final Color color;
  const _BikeIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    canvas.drawCircle(Offset(w * 0.22, h * 0.70), w * 0.19, p);
    canvas.drawCircle(Offset(w * 0.78, h * 0.70), w * 0.19, p);

    canvas.drawPath(
        Path()
          ..moveTo(w * 0.22, h * 0.70)
          ..lineTo(w * 0.40, h * 0.30)
          ..lineTo(w * 0.63, h * 0.30)
          ..lineTo(w * 0.78, h * 0.70)
          ..moveTo(w * 0.50, h * 0.30)
          ..lineTo(w * 0.50, h * 0.12)
          ..lineTo(w * 0.64, h * 0.12),
        p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _CheckIconPainter extends CustomPainter {
  final Color color;
  const _CheckIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(
        Path()
          ..moveTo(size.width * 0.14, size.height * 0.52)
          ..lineTo(size.width * 0.40, size.height * 0.76)
          ..lineTo(size.width * 0.86, size.height * 0.26),
        p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _XIconPainter extends CustomPainter {
  final Color color;
  const _XIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
        Offset(size.width * 0.2, size.height * 0.2),
        Offset(size.width * 0.8, size.height * 0.8), p);
    canvas.drawLine(
        Offset(size.width * 0.8, size.height * 0.2),
        Offset(size.width * 0.2, size.height * 0.8), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _ClockIconPainter extends CustomPainter {
  final Color color;
  const _ClockIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), size.width * 0.42, p);
    canvas.drawLine(
        Offset(size.width / 2, size.height * 0.26),
        Offset(size.width / 2, size.height / 2), p);
    canvas.drawLine(
        Offset(size.width / 2, size.height / 2),
        Offset(size.width * 0.68, size.height * 0.62), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── Other existing widgets (unchanged) ───────────────────────────────────────

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
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: delivery.riderContact!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: const [
                              Icon(Icons.check_circle_rounded,
                                  color: AppColors.gold, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text('Contact number copied'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(delivery.riderContact!,
                            style: AppTextStyles.bodyMedium(context).copyWith(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 5),
                        const Icon(Icons.copy_rounded,
                            size: 13, color: AppColors.gold),
                      ],
                    ),
                  ),
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
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${item.quantity}×',
                    style: GoogleFonts.karla(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 2),
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
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('Note: ${item.note}',
                              style: AppTextStyles.caption(context).copyWith(
                                  color: AppColors.textMuted,
                                  fontStyle: FontStyle.italic)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
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
              Text('Payment: ', style: AppTextStyles.caption(context)),
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: CustomPaint(
                  size: const Size(18, 18), painter: _ChatIconPainter()),
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

// ─── Skeleton ──────────────────────────────────────────────────────────────────
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
        Rect.fromLTWH(size.width * 0.1, size.height * 0.2,
            size.width * 0.8, size.height * 0.6),
        Paint()
          ..color = AppColors.gold
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
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
  bool shouldRepaint(covariant CustomPainter _) => false;
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
  bool shouldRepaint(covariant CustomPainter _) => false;
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
            Rect.fromLTWH(0, size.height * 0.2, size.width * 0.72,
                size.height * 0.55),
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
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
// GCash Rejection Banner + Re-upload
// ══════════════════════════════════════════════════════════════════════════════
class _GcashRejectionBanner extends StatefulWidget {
  final int       orderId;
  final String?   rejectionReason;
  final VoidCallback onUploaded; // called after successful re-upload to refresh

  const _GcashRejectionBanner({
    required this.orderId,
    required this.rejectionReason,
    required this.onUploaded,
  });

  @override
  State<_GcashRejectionBanner> createState() => _GcashRejectionBannerState();
}

class _GcashRejectionBannerState extends State<_GcashRejectionBanner> {
  final _picker = ImagePicker();

  File?   _pickedImage;
  String? _mimeType;
  bool    _isUploading  = false;
  String? _uploadError;
  bool    _uploadDone   = false;

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source:       source,
      imageQuality: 85,
      maxWidth:     1600,
    );
    if (picked == null) return;
    setState(() {
      _pickedImage  = File(picked.path);
      _mimeType     = picked.path.toLowerCase().endsWith('.png')
          ? 'image/png' : 'image/jpeg';
      _uploadError  = null;
      _uploadDone   = false;
    });
  }

  void _showSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded,
                color: AppColors.primary),
            title: Text('Choose from Gallery',
                style: GoogleFonts.karla(fontWeight: FontWeight.w600)),
            onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded,
                color: AppColors.primary),
            title: Text('Take a Photo',
                style: GoogleFonts.karla(fontWeight: FontWeight.w600)),
            onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _submitReupload() async {
    if (_pickedImage == null) return;
    setState(() { _isUploading = true; _uploadError = null; });

    try {
      await OrdersService.instance.reuploadReceipt(
        orderId:   widget.orderId,
        imageFile: _pickedImage!,
        mimeType:  _mimeType ?? 'image/jpeg',
      );
      setState(() { _isUploading = false; _uploadDone = true; });
      widget.onUploaded();
    } on OrdersApiException catch (e) {
      setState(() { _isUploading = false; _uploadError = e.message; });
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadError = 'Upload failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uploadDone) {
      return Container(
        padding:    const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color:        Colors.green.shade50,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border:       Border.all(color: Colors.green.shade300),
        ),
        child: Row(children: [
          Icon(Icons.check_circle_rounded,
              color: Colors.green.shade600, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Receipt re-submitted! We\'ll verify it shortly.',
              style: GoogleFonts.karla(
                  fontSize:   13,
                  fontWeight: FontWeight.w600,
                  color:      Colors.green.shade700),
            ),
          ),
        ]),
      );
    }

    return Container(
      padding:    const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color:        AppColors.error.withOpacity(0.04),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border:       Border.all(
            color: AppColors.error.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Rejection header ────────────────────────────────────────────
          Row(children: [
            Container(
              padding:    const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color:  AppColors.error.withOpacity(0.1),
                shape:  BoxShape.circle,
              ),
              child: Icon(Icons.cancel_rounded,
                  color: AppColors.error, size: 16),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Receipt Rejected',
                style: GoogleFonts.karla(
                    fontSize:   14,
                    fontWeight: FontWeight.w800,
                    color:      AppColors.error),
              ),
            ),
          ]),

          // ── Reason ──────────────────────────────────────────────────────
          if (widget.rejectionReason != null &&
              widget.rejectionReason!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width:   double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color:        AppColors.error.withOpacity(0.06),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                '"${widget.rejectionReason}"',
                style: GoogleFonts.karla(
                    fontSize:  12,
                    color:     AppColors.error,
                    fontStyle: FontStyle.italic,
                    height:    1.4),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          Text(
            'Please upload a clear screenshot of your GCash receipt.',
            style: GoogleFonts.karla(
                fontSize: 12,
                color:    AppColors.textSecondary,
                height:   1.4),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Image preview ────────────────────────────────────────────────
          GestureDetector(
            onTap: _isUploading ? null : _showSourceSheet,
            child: Container(
              width:  double.infinity,
              height: _pickedImage != null ? null : 120,
              decoration: BoxDecoration(
                color:        AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: _pickedImage != null
                      ? AppColors.gold.withOpacity(0.5)
                      : AppColors.border,
                  width: _pickedImage != null ? 2 : 1,
                ),
              ),
              child: _pickedImage != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md - 1),
                child: Image.file(_pickedImage!,
                    fit: BoxFit.contain, width: double.infinity),
              )
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.upload_rounded,
                      size: 28, color: AppColors.textMuted),
                  const SizedBox(height: 6),
                  Text('Tap to select new receipt',
                      style: GoogleFonts.karla(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ),

          // ── Error ────────────────────────────────────────────────────────
          if (_uploadError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              const Icon(Icons.error_outline,
                  color: AppColors.error, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_uploadError!,
                    style: GoogleFonts.karla(
                        fontSize: 12, color: AppColors.error)),
              ),
            ]),
          ],

          const SizedBox(height: AppSpacing.md),

          // ── Buttons ──────────────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isUploading ? null : _showSourceSheet,
                icon:  const Icon(Icons.photo_library_rounded, size: 15),
                label: Text(
                  _pickedImage != null ? 'Change' : 'Select',
                  style: GoogleFonts.karla(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side:  const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: (_pickedImage != null && !_isUploading)
                    ? _submitReupload : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:         AppColors.error,
                  foregroundColor:         Colors.white,
                  disabledBackgroundColor: AppColors.border,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isUploading
                    ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white)),
                )
                    : Text('Re-submit Receipt',
                    style: GoogleFonts.karla(
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─── §1.9 Rider Map Card ──────────────────────────────────────────────────────
//
// Shows an OpenStreetMap tile map (via flutter_map) with two markers:
//   • 🛵  Rider — animated pulsing dot, updates as location streams in
//   • 📍  Customer delivery pin — static, shown when order has coordinates
//
// The map auto-pans to the rider whenever the position changes, keeping
// the rider roughly centred with a slight offset so the info strip at the
// bottom doesn't obscure the marker.

class _RiderMapCard extends StatefulWidget {
  final RiderLocation  riderLocation;
  final DeliveryInfo?  deliveryInfo;

  const _RiderMapCard({
    required this.riderLocation,
    this.deliveryInfo,
  });

  @override
  State<_RiderMapCard> createState() => _RiderMapCardState();
}

class _RiderMapCardState extends State<_RiderMapCard>
    with SingleTickerProviderStateMixin {
  late final MapController      _mapCtrl;
  late AnimationController      _pulseCtrl;
  late Animation<double>        _pulseAnim;
  RiderLocation?                _prev;

  @override
  void initState() {
    super.initState();
    _mapCtrl  = MapController();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 6.0, end: 14.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_RiderMapCard old) {
    super.didUpdateWidget(old);
    // Smooth-pan the map whenever the rider moves
    if (widget.riderLocation.latitude  != old.riderLocation.latitude ||
        widget.riderLocation.longitude != old.riderLocation.longitude) {
      _mapCtrl.move(
        LatLng(widget.riderLocation.latitude, widget.riderLocation.longitude),
        _mapCtrl.camera.zoom,
      );
    }
    _prev = old.riderLocation;
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rider = widget.riderLocation;
    final riderLatLng = LatLng(rider.latitude, rider.longitude);

    // Freshness: dim marker if position is > 60 s old
    final age = rider.updatedAt != null
        ? DateTime.now().difference(rider.updatedAt!)
        : Duration.zero;
    final isStale = age > const Duration(seconds: 60);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.card,
        border: Border.all(
          color: AppColors.gold.withOpacity(0.25),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Map ────────────────────────────────────────────────────────────
          SizedBox(
            height: 220,
            child: FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: riderLatLng,
                initialZoom:   16.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom |
                  InteractiveFlag.doubleTapZoom |
                  InteractiveFlag.drag,
                ),
              ),
              children: [
                // OSM tiles
                TileLayer(
                  urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.bingnondo_app',
                  maxZoom: 19,
                ),

                // Markers layer
                MarkerLayer(
                  markers: [
                    // Rider marker — pulsing gold dot
                    Marker(
                      point:  riderLatLng,
                      width:  48,
                      height: 48,
                      child: AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, __) => Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer pulse ring
                            Container(
                              width:  _pulseAnim.value * 2,
                              height: _pulseAnim.value * 2,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.gold
                                    .withOpacity(isStale ? 0.08 : 0.22),
                              ),
                            ),
                            // Inner dot
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isStale
                                    ? AppColors.textMuted
                                    : AppColors.gold,
                                border: Border.all(
                                    color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.gold.withOpacity(0.5),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text('🛵',
                                    style: TextStyle(fontSize: 9)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Map attribution (required by OSM)
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),

          // ── Info strip ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
            decoration: const BoxDecoration(
              color: AppColors.primaryDark,
            ),
            child: Row(
              children: [
                // Rider icon
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold.withOpacity(0.15),
                    border: Border.all(
                        color: AppColors.gold.withOpacity(0.4), width: 1),
                  ),
                  child: const Center(
                    child: Text('🛵', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),

                // Name + freshness
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.deliveryInfo?.riderName ?? 'Your rider',
                        style: GoogleFonts.karla(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textOnDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isStale
                            ? 'Location may be outdated'
                            : 'Live location · updated ${_formatAge(age)}',
                        style: GoogleFonts.karla(
                          fontSize: 11,
                          color: isStale
                              ? AppColors.error.withOpacity(0.8)
                              : AppColors.gold.withOpacity(0.75),
                        ),
                      ),
                    ],
                  ),
                ),

                // Live indicator dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isStale ? AppColors.textMuted : AppColors.success,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  isStale ? 'Stale' : 'LIVE',
                  style: GoogleFonts.karla(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isStale ? AppColors.textMuted : AppColors.success,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatAge(Duration age) {
    if (age.inSeconds < 10) return 'just now';
    if (age.inSeconds < 60) return '${age.inSeconds}s ago';
    return '${age.inMinutes}m ago';
  }
}