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

// ─── Filter tabs (shown as gold pill chips in the maroon header) ─────────────
enum _NotifFilter { all, orders, payments, support }

// ─── Navigation helper ───────────────────────────────────────────────────────
// Order + payment notifications both carry the order id, so both open the
// tracker (a rejected payment should land the customer back on the order so
// they can re-upload the receipt).
bool _canTrack(AppNotification notif) {
  if (notif.relatedOrderId == null) return false;
  return notif.type.isOrderRelated ||
      notif.type == NotificationType.paymentReceived ||
      notif.type == NotificationType.paymentFailed;
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  _NotifFilter _filter = _NotifFilter.all;

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

  bool _matchesFilter(AppNotification n) {
    switch (_filter) {
      case _NotifFilter.all:
        return true;
      case _NotifFilter.orders:
        return n.type.isOrderRelated;
      case _NotifFilter.payments:
        return n.type == NotificationType.paymentReceived ||
            n.type == NotificationType.paymentFailed;
      case _NotifFilter.support:
        return n.type == NotificationType.supportMessage;
    }
  }

  void _handleTap(BuildContext context, AppNotification notif) {
    // Always mark as read the moment the customer opens it.
    context.read<NotificationsProvider>().markRead(notif.id);

    if (_canTrack(notif)) {
      context.read<OrderTrackingProvider>().loadOrder(notif.relatedOrderId!);
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, anim, __) => OrderTrackingScreen(
            orderId: notif.relatedOrderId!,
            orderNumber:
                notif.relatedOrderNumber ?? '#${notif.relatedOrderId}',
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
    } else if (notif.type == NotificationType.supportMessage) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, anim, __) =>
              SupportChatScreen(activeOrderId: notif.relatedOrderId),
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
  }

  @override
  Widget build(BuildContext context) {
    // The header now runs full-bleed under the status bar (same as the home
    // screen), so the status bar icons must be light on the dark maroon.
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fade,
        child: Consumer<NotificationsProvider>(
          builder: (context, provider, _) {
            return Column(
              children: [
                _buildHeader(context, provider),
                Expanded(
                  child: SafeArea(
                    top: false,
                    child: _buildBody(context, provider),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, NotificationsProvider provider) {
    final safeTop = MediaQuery.of(context).padding.top;
    final unread = provider.unreadCount;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: safeTop),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, Color(0xFF7C1220)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Title row ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, AppSpacing.md, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  color: AppColors.textOnDark,
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Back',
                  padding: const EdgeInsets.all(8),
                  constraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
                const SizedBox(width: 2),
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
                          letterSpacing: 0.3,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        unread > 0
                            ? '$unread unread update${unread == 1 ? '' : 's'}'
                            : 'You\u2019re all caught up',
                        style: GoogleFonts.karla(
                          fontSize: 11,
                          color: AppColors.textOnDark.withOpacity(0.7),
                          letterSpacing: 0.2,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unread > 0) _MarkAllReadButton(onPressed: provider.markAllRead),
              ],
            ),
          ),

          // ── Filter chips ───────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm + 2, AppSpacing.md, AppSpacing.md),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filter == _NotifFilter.all,
                  onTap: () => setState(() => _filter = _NotifFilter.all),
                ),
                _FilterChip(
                  label: 'Orders',
                  selected: _filter == _NotifFilter.orders,
                  onTap: () => setState(() => _filter = _NotifFilter.orders),
                ),
                _FilterChip(
                  label: 'Payments',
                  selected: _filter == _NotifFilter.payments,
                  onTap: () => setState(() => _filter = _NotifFilter.payments),
                ),
                _FilterChip(
                  label: 'Support',
                  selected: _filter == _NotifFilter.support,
                  onTap: () => setState(() => _filter = _NotifFilter.support),
                ),
              ],
            ),
          ),

          // ── Gold hairline separating the header from the list ──────────────
          Container(
            height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, AppColors.gold, Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody(BuildContext context, NotificationsProvider provider) {
    switch (provider.state) {
      case NotifLoadState.initial:
      case NotifLoadState.loading:
        return _buildSkeleton();
      case NotifLoadState.error:
        return _buildError(context, provider);
      case NotifLoadState.loaded:
        if (provider.notifications.isEmpty) return _buildEmpty(context);

        final filtered =
            provider.notifications.where(_matchesFilter).toList(growable: false);
        if (filtered.isEmpty) return _buildNoMatch(context);

        return _buildList(context, provider, filtered);
    }
  }

  Widget _buildList(
    BuildContext context,
    NotificationsProvider provider,
    List<AppNotification> items,
  ) {
    final grouped = _groupByDate(items);
    final bottomPad =
        AppSpacing.xxl + MediaQuery.of(context).padding.bottom;

    return RefreshIndicator(
      onRefresh: provider.refresh,
      color: AppColors.gold,
      backgroundColor: AppColors.background,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(0, AppSpacing.sm, 0, bottomPad),
        itemCount: grouped.length,
        itemBuilder: (context, i) {
          final entry = grouped[i];
          if (entry is String) return _DateHeader(label: entry);

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
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  // ─── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceWarm,
                shape: BoxShape.circle,
                border:
                    Border.all(color: AppColors.gold.withOpacity(0.4), width: 1.5),
              ),
              child: const Icon(Icons.notifications_none_rounded,
                  color: AppColors.gold, size: 44),
            ),
            const SizedBox(height: AppSpacing.lg),
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

  // ─── Filter matched nothing ────────────────────────────────────────────────
  Widget _buildNoMatch(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_alt_off_outlined,
                color: AppColors.textMuted, size: 44),
            const SizedBox(height: AppSpacing.md),
            Text('Nothing in this category',
                style: AppTextStyles.headline(context),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'You have notifications, but none match this filter yet.',
              style: AppTextStyles.bodyMedium(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            GoldOutlineButton(
              label: 'SHOW ALL',
              onPressed: () => setState(() => _filter = _NotifFilter.all),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Loading skeleton ──────────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxl),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm + 2),
      itemBuilder: (_, __) => const _NotifSkeleton(),
    );
  }

  // ─── Error state ───────────────────────────────────────────────────────────
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
            if (p.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(p.errorMessage!,
                  style: AppTextStyles.bodyMedium(context),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(label: 'TRY AGAIN', onPressed: p.refresh, isSmall: true),
          ],
        ),
      ),
    );
  }
}

// ─── Mark all read button ────────────────────────────────────────────────────
class _MarkAllReadButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _MarkAllReadButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: AppShadows.goldGlow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.done_all_rounded,
                  size: 15, color: AppColors.primaryDark),
              const SizedBox(width: 5),
              Text(
                'Mark all read',
                style: GoogleFonts.karla(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Filter chip (matches the home screen's category chips) ──────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.gold
                  : AppColors.textOnDark.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: selected
                    ? AppColors.gold
                    : AppColors.textOnDark.withOpacity(0.25),
                width: 1,
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.karla(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected
                    ? AppColors.primaryDark
                    : AppColors.textOnDark.withOpacity(0.75),
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Date header ─────────────────────────────────────────────────────────────
class _DateHeader extends StatelessWidget {
  final String label;
  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          CustomPaint(size: const Size(9, 9), painter: _DiamondPainter()),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.karla(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
        ],
      ),
    );
  }
}

// ─── Notification card ───────────────────────────────────────────────────────
class _NotificationCard extends StatelessWidget {
  final AppNotification notif;
  final VoidCallback onTap;

  const _NotificationCard({super.key, required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnread = !notif.isRead;
    final visual = _notifVisual(notif.type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: isUnread ? AppColors.surfaceWarm : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isUnread
                  ? AppColors.gold.withOpacity(0.45)
                  : AppColors.border,
              width: isUnread ? 1.5 : 1,
            ),
            boxShadow: isUnread ? AppShadows.card : const [],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isUnread)
                  Container(
                    width: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(AppRadius.lg),
                        bottomLeft: Radius.circular(AppRadius.lg),
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TypeIcon(visual: visual),
                        const SizedBox(width: AppSpacing.sm + 4),
                        Expanded(child: _content(context, isUnread, visual)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
  }

  Widget _content(
    BuildContext context,
    bool isUnread,
    _NotifVisual visual,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Title + time (+ unread dot) ──────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                notif.type.title,
                style: GoogleFonts.karla(
                  fontSize: 13.5,
                  fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatTime(notif.createdAt),
              style: GoogleFonts.karla(
                fontSize: 11,
                color: isUnread
                    ? visual.fg
                    : AppColors.textMuted,
                fontWeight: isUnread ? FontWeight.w700 : FontWeight.w400,
                letterSpacing: 0.2,
              ),
            ),
            if (isUnread) ...[
              const SizedBox(width: 6),
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                    color: AppColors.gold, shape: BoxShape.circle),
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
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),

        // ── Order tag ────────────────────────────────────────────────────────
        if (notif.relatedOrderNumber != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                    size: const Size(10, 10), painter: _OrderTagPainter()),
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
                if (_canTrack(notif)) ...[
                  const SizedBox(width: 1),
                  const Icon(Icons.chevron_right_rounded,
                      size: 14, color: AppColors.primary),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Type icon ───────────────────────────────────────────────────────────────
class _TypeIcon extends StatelessWidget {
  final _NotifVisual visual;
  const _TypeIcon({required this.visual});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: visual.bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: visual.fg.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: visual.isImage
          ? ClipOval(
              child: Image.asset(
                'assets/images/ndo_bot.png',
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(visual.icon, color: visual.fg, size: 20),
              ),
            )
          : Icon(visual.icon, color: visual.fg, size: 21),
    );
  }
}

// ─── Per-type colours + icons ────────────────────────────────────────────────
class _NotifVisual {
  final Color fg;
  final Color bg;
  final IconData icon;
  final bool isImage;
  const _NotifVisual({
    required this.fg,
    required this.bg,
    required this.icon,
    this.isImage = false,
  });
}

_NotifVisual _notifVisual(NotificationType t) {
  switch (t) {
    case NotificationType.orderConfirmed:
      return _NotifVisual(
        fg: AppColors.primary,
        bg: AppColors.primary.withOpacity(0.09),
        icon: Icons.receipt_long_rounded,
      );
    case NotificationType.orderPreparing:
      return _NotifVisual(
        fg: AppColors.gold,
        bg: AppColors.gold.withOpacity(0.12),
        icon: Icons.soup_kitchen_rounded,
      );
    case NotificationType.orderReady:
      return _NotifVisual(
        fg: AppColors.success,
        bg: AppColors.success.withOpacity(0.12),
        icon: Icons.inventory_2_rounded,
      );
    case NotificationType.orderOutForDelivery:
      return _NotifVisual(
        fg: AppColors.primary,
        bg: AppColors.primary.withOpacity(0.09),
        icon: Icons.delivery_dining_rounded,
      );
    case NotificationType.orderCompleted:
      return _NotifVisual(
        fg: AppColors.success,
        bg: AppColors.success.withOpacity(0.12),
        icon: Icons.check_circle_rounded,
      );
    case NotificationType.orderCancelled:
      return _NotifVisual(
        fg: AppColors.error,
        bg: AppColors.error.withOpacity(0.10),
        icon: Icons.cancel_rounded,
      );
    case NotificationType.paymentReceived:
      return _NotifVisual(
        fg: AppColors.gold,
        bg: AppColors.gold.withOpacity(0.12),
        icon: Icons.payments_rounded,
      );
    case NotificationType.paymentFailed:
      return _NotifVisual(
        fg: AppColors.error,
        bg: AppColors.error.withOpacity(0.10),
        icon: Icons.error_outline_rounded,
      );
    case NotificationType.supportMessage:
      return _NotifVisual(
        fg: AppColors.primaryDark,
        bg: AppColors.primaryDark.withOpacity(0.12),
        icon: Icons.support_agent_rounded,
        isImage: true,
      );
    case NotificationType.system:
      return _NotifVisual(
        fg: AppColors.textSecondary,
        bg: AppColors.surfaceWarm,
        icon: Icons.notifications_rounded,
      );
  }
}

// ─── Skeleton ────────────────────────────────────────────────────────────────
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
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
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
          height: 96,
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: col, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                        height: 13,
                        width: 140,
                        decoration: BoxDecoration(
                            color: col,
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm))),
                    const SizedBox(height: 6),
                    Container(
                        height: 10,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: col,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.sm))),
                    const SizedBox(height: 5),
                    Container(
                        height: 10,
                        width: 200,
                        decoration: BoxDecoration(
                            color: col,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.sm))),
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

// ─── Small decorative painters ───────────────────────────────────────────────
class _DiamondPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height / 2)
      ..close();
    canvas.drawPath(
        path, Paint()..color = AppColors.gold..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _OrderTagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, size.height * 0.1, size.width * 0.85, size.height * 0.8),
            const Radius.circular(2)),
        p);
    canvas.drawLine(
        Offset(size.width * 0.2, size.height * 0.4),
        Offset(size.width * 0.65, size.height * 0.4),
        p);
    canvas.drawLine(
        Offset(size.width * 0.2, size.height * 0.65),
        Offset(size.width * 0.5, size.height * 0.65),
        p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
