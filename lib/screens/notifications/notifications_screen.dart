import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/notification_settings_models.dart';
import '../../services/notifications_provider.dart';
import '../../services/order_tracking_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../tracking/order_tracking_screen.dart';
import '../chat/support_chat_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationsProvider>().load();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _handleTap(BuildContext context, AppNotification notif) {
    context.read<NotificationsProvider>().markRead(notif.id);

    if (notif.type.isOrderRelated && notif.relatedOrderId != null) {
      context
          .read<OrderTrackingProvider>()
          .loadOrder(notif.relatedOrderId!);
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, anim, __) => OrderTrackingScreen(
            orderId: notif.relatedOrderId!,
            orderNumber: notif.relatedOrderNumber ?? '#${notif.relatedOrderId}',
          ),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0), end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    } else if (notif.type == NotificationType.supportMessage) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, anim, __) => SupportChatScreen(
              activeOrderId: notif.relatedOrderId),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0), end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    }
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
          child: Consumer<NotificationsProvider>(
            builder: (context, provider, _) {
              return Column(
                children: [
                  _buildHeader(context, provider),
                  Expanded(child: _buildBody(context, provider)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, NotificationsProvider provider) {
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
                  'Notifications',
                  style: GoogleFonts.playfairDisplaySc(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnDark,
                  ),
                ),
                if (provider.unreadCount > 0)
                  Text(
                    '${provider.unreadCount} unread',
                    style: GoogleFonts.karla(
                      fontSize: 11,
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (provider.unreadCount > 0)
            TextButton(
              onPressed: provider.markAllRead,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 4),
              ),
              child: Text(
                'Mark all read',
                style: GoogleFonts.karla(
                  fontSize: 12,
                  color: AppColors.gold.withOpacity(0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, NotificationsProvider provider) {
    switch (provider.state) {
      case NotifLoadState.initial:
      case NotifLoadState.loading:
        return _buildSkeleton();
      case NotifLoadState.error:
        return _buildError(context, provider);
      case NotifLoadState.loaded:
        if (provider.notifications.isEmpty) return _buildEmpty(context);
        return _buildList(context, provider);
    }
  }

  Widget _buildList(BuildContext context, NotificationsProvider provider) {
    final grouped = _groupByDate(provider.notifications);

    return RefreshIndicator(
      onRefresh: provider.refresh,
      color: AppColors.gold,
      backgroundColor: AppColors.background,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        itemCount: grouped.length,
        itemBuilder: (context, i) {
          final entry = grouped[i];
          if (entry is String) {
            return _DateHeader(label: entry);
          }
          final notif = entry as AppNotification;
          return _NotificationCard(
            key: ValueKey('notif_${notif.id}'),
            notif: notif,
            onTap: () => _handleTap(context, notif),
          );
        },
      ),
    );
  }

  List<dynamic> _groupByDate(List<AppNotification> notifs) {
    final result = <dynamic>[];
    String? lastDate;
    for (final n in notifs) {
      final label = _dateLabel(n.createdAt);
      if (label != lastDate) {
        result.add(label);
        lastDate = label;
      }
      result.add(n);
    }
    return result;
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size(72, 72),
              painter: _BellPainter(empty: true),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('No notifications yet',
                style: AppTextStyles.headline(context),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Order updates, payment confirmations, and\nstaff messages will appear here.',
              style: AppTextStyles.bodyMedium(context),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, __) => const _NotifSkeleton(),
    );
  }

  Widget _buildError(BuildContext context, NotificationsProvider p) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: AppColors.textMuted, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text('Could not load notifications',
                style: AppTextStyles.headline(context),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(label: 'TRY AGAIN', onPressed: p.refresh, isSmall: true),
          ],
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String label;
  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          CustomPaint(size: const Size(10, 10), painter: _DiamondPainter()),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.karla(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notif;
  final VoidCallback onTap;

  const _NotificationCard({super.key, required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnread = !notif.isRead;
    final isWide = MediaQuery.of(context).size.width >= 600;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isUnread ? AppColors.surfaceWarm : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isUnread ? AppColors.gold.withOpacity(0.35) : AppColors.border,
            width: isUnread ? 1.5 : 1,
          ),
          boxShadow: isUnread ? AppShadows.card : [],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isUnread)
                Container(
                  width: 4,
                  color: AppColors.gold,
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _iconBg(notif.type),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                      child: notif.type == NotificationType.supportMessage
                          ? ClipOval(
                              child: Image.asset(
                                'assets/images/ndo_bot.png',
                                width: 24,
                                height: 24,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => CustomPaint(
                                  size: const Size(20, 20),
                                  painter: _NotifIconPainter(notif.type),
                                ),
                              ),
                            )
                          : CustomPaint(
                              size: const Size(20, 20),
                              painter: _NotifIconPainter(notif.type),
                            ),
                    ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    notif.type.title,
                                    style: GoogleFonts.karla(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatTime(notif.createdAt),
                                  style: AppTextStyles.caption(context),
                                ),
                                if (isUnread) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: AppColors.gold,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notif.message,
                              style: GoogleFonts.karla(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.45,
                              ),
                              maxLines: isWide ? 3 : 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (notif.relatedOrderNumber != null) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                  border: Border.all(
                                      color: AppColors.primary.withOpacity(0.2),
                                      width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CustomPaint(
                                      size: const Size(10, 10),
                                      painter: _OrderTagPainter(),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      notif.relatedOrderNumber!,
                                      style: GoogleFonts.karla(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    if (notif.type.isOrderRelated) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.chevron_right_rounded,
                                          size: 12, color: AppColors.primary),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
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

  Color _iconBg(NotificationType type) {
    switch (type) {
      case NotificationType.orderCompleted:
        return AppColors.success.withOpacity(0.12);
      case NotificationType.orderCancelled:
      case NotificationType.paymentFailed:
        return AppColors.error.withOpacity(0.1);
      case NotificationType.paymentReceived:
        return AppColors.gold.withOpacity(0.12);
      case NotificationType.supportMessage:
        return AppColors.primaryDark.withOpacity(0.12);
      default:
        return AppColors.primary.withOpacity(0.08);
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
  }
}

class _NotifSkeleton extends StatefulWidget {
  const _NotifSkeleton();
  @override
  State<_NotifSkeleton> createState() => _NotifSkeletonState();
}

class _NotifSkeletonState extends State<_NotifSkeleton>
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
          height: 88,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: col, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(height: 13, width: 140,
                        decoration: BoxDecoration(color: col,
                            borderRadius: BorderRadius.circular(AppRadius.sm))),
                    Container(height: 10, width: double.infinity,
                        decoration: BoxDecoration(color: col,
                            borderRadius: BorderRadius.circular(AppSpacing.sm))),
                    Container(height: 10, width: 200,
                        decoration: BoxDecoration(color: col,
                            borderRadius: BorderRadius.circular(AppSpacing.sm))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NotifIconPainter extends CustomPainter {
  final NotificationType type;
  const _NotifIconPainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = _color;

    switch (type.iconIndex) {
      case 0: _drawOrder(canvas, size, p); break;
      case 1: _drawPayment(canvas, size, p); break;
      case 2: _drawChat(canvas, size, p); break;
      default: _drawLantern(canvas, size, p);
    }
  }

  Color get _color {
    switch (type) {
      case NotificationType.orderCompleted:  return AppColors.success;
      case NotificationType.orderCancelled:
      case NotificationType.paymentFailed:   return AppColors.error;
      case NotificationType.paymentReceived: return AppColors.gold;
      case NotificationType.supportMessage:  return AppColors.primaryDark;
      default:                               return AppColors.primary;
    }
  }

  void _drawOrder(Canvas canvas, Size s, Paint p) {
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.1, 0, s.width * 0.8, s.height), const Radius.circular(3)), p);
    for (int i = 0; i < 3; i++) {
      final y = s.height * (0.3 + i * 0.2);
      canvas.drawLine(Offset(s.width * 0.25, y), Offset(s.width * 0.75, y), p);
    }
  }

  void _drawPayment(Canvas canvas, Size s, Paint p) {
    canvas.drawOval(Rect.fromLTWH(s.width * 0.1, s.height * 0.4, s.width * 0.8, s.height * 0.3), p);
    canvas.drawLine(Offset(s.width * 0.1, s.height * 0.55), Offset(s.width * 0.1, s.height * 0.2), p);
    canvas.drawLine(Offset(s.width * 0.9, s.height * 0.55), Offset(s.width * 0.9, s.height * 0.2), p);
    canvas.drawArc(Rect.fromLTWH(s.width * 0.1, s.height * 0.05, s.width * 0.8, s.height * 0.3), 3.14 * 1.0, 3.14, false, p);
  }

  void _drawChat(Canvas canvas, Size s, Paint p) {
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, s.width * 0.9, s.height * 0.75), const Radius.circular(5)), p);
    canvas.drawLine(Offset(s.width * 0.12, s.height * 0.75), Offset(0, s.height), p);
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(s.width * (0.25 + i * 0.25), s.height * 0.38), 1.5, p..style = PaintingStyle.fill);
    }
    p.style = PaintingStyle.stroke;
  }

  void _drawLantern(Canvas canvas, Size s, Paint p) {
    canvas.drawLine(Offset(s.width / 2, 0), Offset(s.width / 2, s.height * 0.15), p);
    final body = Path()..moveTo(s.width * 0.1, s.height * 0.18)..quadraticBezierTo(0, s.height * 0.5, s.width * 0.1, s.height * 0.82)..lineTo(s.width * 0.9, s.height * 0.82)..quadraticBezierTo(s.width, s.height * 0.5, s.width * 0.9, s.height * 0.18)..close();
    canvas.drawPath(body, p);
    canvas.drawLine(Offset(s.width * 0.1, s.height * 0.5), Offset(s.width * 0.9, s.height * 0.5), p..color = _color.withOpacity(0.4)..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _BellPainter extends CustomPainter {
  final bool empty;
  const _BellPainter({this.empty = false});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = AppColors.gold.withOpacity(empty ? 0.3 : 0.8)..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final w = size.width; final h = size.height;
    final bell = Path()..moveTo(w * 0.5, h * 0.05)..quadraticBezierTo(w * 0.1, h * 0.25, w * 0.1, h * 0.65)..lineTo(w * 0.9, h * 0.65)..quadraticBezierTo(w * 0.9, h * 0.25, w * 0.5, h * 0.05);
    canvas.drawPath(bell, p);
    canvas.drawLine(Offset(w * 0.05, h * 0.65), Offset(w * 0.95, h * 0.65), p);
    canvas.drawOval(Rect.fromLTWH(w * 0.38, h * 0.72, w * 0.24, h * 0.15), p);
    canvas.drawLine(Offset(w * 0.5, 0), Offset(w * 0.5, h * 0.05), p);
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _DiamondPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(Path()..moveTo(size.width / 2, 0)..lineTo(size.width, size.height / 2)..lineTo(size.width / 2, size.height)..lineTo(0, size.height / 2)..close(), Paint()..color = AppColors.gold..style = PaintingStyle.fill);
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _OrderTagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = AppColors.primary..style = PaintingStyle.stroke..strokeWidth = 1.2..strokeCap = StrokeCap.round;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, size.height * 0.1, size.width * 0.85, size.height * 0.8), const Radius.circular(2)), p);
    canvas.drawLine(Offset(size.width * 0.2, size.height * 0.4), Offset(size.width * 0.65, size.height * 0.4), p);
    canvas.drawLine(Offset(size.width * 0.2, size.height * 0.65), Offset(size.width * 0.5, size.height * 0.65), p);
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
