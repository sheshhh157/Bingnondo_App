import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/announcement_model.dart';
import '../services/announcement_provider.dart';
import '../theme/app_theme.dart';

/// Drop this widget into a Stack as the last child (topmost layer)
/// inside HomeMenuScreen's body Stack.
///
/// Usage:
///   Stack(
///     children: [
///       // ... your normal content ...
///       const LanternAnnouncementPanel(),
///     ],
///   )
class LanternAnnouncementPanel extends StatefulWidget {
  const LanternAnnouncementPanel({super.key});

  @override
  State<LanternAnnouncementPanel> createState() =>
      _LanternAnnouncementPanelState();
}

class _LanternAnnouncementPanelState extends State<LanternAnnouncementPanel>
    with TickerProviderStateMixin {
  // ─── Panel slide animation ─────────────────────────────────────────────────
  late AnimationController _panelCtrl;
  late Animation<double> _panelAnim; // 0 = hidden, 1 = fully open

  // ─── Lantern drop-in animation (on first appearance) ──────────────────────
  late AnimationController _dropCtrl;
  late Animation<double> _dropAnim; // 0 = above screen, 1 = resting position

  // ─── Lantern pendulum swing ───────────────────────────────────────────────
  late AnimationController _swingCtrl;
  late Animation<double> _swingAnim; // swing angle in radians

  // ─── Lantern body bob (subtle idle) ───────────────────────────────────────
  late AnimationController _bobCtrl;
  late Animation<double> _bobAnim;

  // ─── Lantern return animation (spring back) ──────────────────────────────
  late AnimationController _returnCtrl;
  late Animation<Offset> _returnAnim;

  // ─── Drag state ────────────────────────────────────────────────────────────
  // Lantern position — starts at right side
  double _lanternX = 0;
  double _lanternY = 0;
  // Resting Y position
  static const double _restY = 130.0;
  // Fixed rope anchor — set once in _initPosition, never changes
  double _anchorX = 0;
  bool _isDragging = false;
  double _dragStartX = 0;
  double _dragStartY = 0;
  double _dragOffsetX = 0;
  double _dragOffsetY = 0;
  bool _positioned = false;

  // Velocity for flick physics
  double _velX = 0;
  double _velY = 0;
  DateTime _lastDragTime = DateTime.now();
  double _lastDragX = 0;
  double _lastDragY = 0;

  // Panel carousel
  int _currentCard = 0;
  final PageController _pageCtrl = PageController();

  bool _panelVisible = false; // true once drop animation completes

  @override
  void initState() {
    super.initState();

    // Panel slide: spring-based
    _panelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _panelAnim = CurvedAnimation(
      parent: _panelCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // Drop-in: lantern falls from above with bounce
    _dropCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _dropAnim = CurvedAnimation(
      parent: _dropCtrl,
      curve: const _BounceOutCurve(),
    );

    // Return animation
    _returnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _returnAnim = _returnCtrl.drive(Tween<Offset>(begin: Offset.zero, end: Offset.zero));

    // Pendulum swing: damped oscillation after drop
    _swingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _swingAnim = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 0.35), weight: 1),
      TweenSequenceItem(
          tween: Tween(begin: 0.35, end: -0.22), weight: 1),
      TweenSequenceItem(
          tween: Tween(begin: -0.22, end: 0.12), weight: 1),
      TweenSequenceItem(
          tween: Tween(begin: 0.12, end: -0.06), weight: 1),
      TweenSequenceItem(
          tween: Tween(begin: -0.06, end: 0.02), weight: 1),
      TweenSequenceItem(
          tween: Tween(begin: 0.02, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _swingCtrl, curve: Curves.linear));

    // Idle bob
    _bobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _bobAnim = Tween<double>(begin: -2.0, end: 2.0).animate(
        CurvedAnimation(parent: _bobCtrl, curve: Curves.easeInOut));

    // Trigger drop after short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPosition();
      _startDropSequence();
    });
  }

  void _initPosition() {
    final size = MediaQuery.of(context).size;
    // Right side, below the persistent header area (~120px)
    _lanternX = size.width - 52;
    _lanternY = _restY;
    // Anchor is fixed at top of screen, same X as initial lantern position
    _anchorX = size.width - 52;
  }

  Future<void> _startDropSequence() async {
    // Load announcements
    await context.read<AnnouncementProvider>().load();
    if (!mounted) return;

    final provider = context.read<AnnouncementProvider>();
    if (!provider.hasAnnouncements) return;

    // Wait a moment then drop
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() => _panelVisible = true);

    // Drop animation
    await _dropCtrl.forward();
    if (!mounted) return;

    // Then swing
    await _swingCtrl.forward();
    if (!mounted) return;

    // Auto-open panel after settling if has new announcements
    if (provider.hasNew) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      _openPanel();
    }
  }

  void _openPanel() {
    context.read<AnnouncementProvider>().openPanel();
    context.read<AnnouncementProvider>().markSeen();
    _panelCtrl.forward();
  }

  void _closePanel() {
    context.read<AnnouncementProvider>().closePanel();
    _panelCtrl.reverse();
  }

  void _togglePanel() {
    final provider = context.read<AnnouncementProvider>();
    if (provider.panelOpen) {
      _closePanel();
    } else {
      _openPanel();
    }
  }

  // ─── Drag handlers ─────────────────────────────────────────────────────────
  void _onDragStart(DragStartDetails d) {
    _returnCtrl.stop();
    setState(() => _isDragging = true);
    _dragStartX = _lanternX;
    _dragStartY = _lanternY;
    _dragOffsetX = d.globalPosition.dx - _lanternX;
    _dragOffsetY = d.globalPosition.dy - _lanternY;
    _lastDragX = d.globalPosition.dx;
    _lastDragY = d.globalPosition.dy;
    _lastDragTime = DateTime.now();
    _velX = 0;
    _velY = 0;

    // Pause swing while dragging
    _swingCtrl.stop();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final now = DateTime.now();
    final dt = now.difference(_lastDragTime).inMilliseconds / 1000.0;
    if (dt > 0) {
      _velX = (d.globalPosition.dx - _lastDragX) / dt;
      _velY = (d.globalPosition.dy - _lastDragY) / dt;
    }
    _lastDragX = d.globalPosition.dx;
    _lastDragY = d.globalPosition.dy;
    _lastDragTime = now;

    final size = MediaQuery.of(context).size;
    setState(() {
      _lanternX = (d.globalPosition.dx - _dragOffsetX)
          .clamp(20.0, size.width - 20.0);
      _lanternY = (d.globalPosition.dy - _dragOffsetY)
          .clamp(50.0, size.height * 0.6);
    });
  }

  void _onDragEnd(DragEndDetails d) {
    setState(() => _isDragging = false);

    final dragDistY = _lanternY - _dragStartY;

    // Physics-based return animation using SpringSimulation
    final spring = const SpringDescription(
      mass: 1.0, 
      stiffness: 450.0, // Higher stiffness for "snappy" return
      damping: 8.0,    // Lower damping for more bounce/oscillation
    );

    _returnAnim = _returnCtrl.drive(
      Tween<Offset>(
        begin: Offset(_lanternX, _lanternY),
        end: Offset(_anchorX, _restY),
      ),
    );

    // Initial velocity proportional to pull distance + flick speed
    final initialVel = -(_velY.abs() / 400) - (dragDistY.abs() / 100);
    final simulation = SpringSimulation(spring, 0, 1, initialVel);
    _returnCtrl.animateWith(simulation);

    // Dragged DOWN enough → open panel
    if (dragDistY > 30 || _velY > 200) {
      _openPanel();
      _triggerFlingSwing(_velX);
      return;
    }

    // Dragged UP enough → close panel
    if (dragDistY < -30 || _velY < -200) {
      _closePanel();
      _triggerFlingSwing(_velX);
      return;
    }

    // Just a tap-ish drag → toggle
    if ((dragDistY).abs() < 15) {
      _togglePanel();
    }

    _triggerFlingSwing(_velX);
  }

  void _triggerFlingSwing(double velocityX) {
    // Convert horizontal velocity to swing angle
    final maxAngle = math.pi / 5;
    final targetAngle = (velocityX / 2000).clamp(-maxAngle, maxAngle);

    _swingCtrl.reset();
    final seq = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: targetAngle), weight: 1),
      TweenSequenceItem(
          tween: Tween(begin: targetAngle, end: -targetAngle * 0.55),
          weight: 1),
      TweenSequenceItem(
          tween: Tween(begin: -targetAngle * 0.55, end: targetAngle * 0.25),
          weight: 1),
      TweenSequenceItem(
          tween: Tween(begin: targetAngle * 0.25, end: 0.0), weight: 1),
    ]);

    final tempAnim = seq.animate(
        CurvedAnimation(parent: _swingCtrl, curve: Curves.linear));
    // Use tempAnim for one-shot swing
    _swingCtrl.duration = const Duration(milliseconds: 1600);
    _swingCtrl.forward();
  }

  @override
  void dispose() {
    _panelCtrl.dispose();
    _dropCtrl.dispose();
    _swingCtrl.dispose();
    _bobCtrl.dispose();
    _returnCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AnnouncementProvider>(
      builder: (context, provider, _) {
        if (!_panelVisible || !provider.hasAnnouncements) {
          return const SizedBox.shrink();
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Announcement panel (slides down from top) ──────────────────
            AnimatedBuilder(
              animation: _panelAnim,
              builder: (_, __) {
                final panelH = MediaQuery.of(context).size.height * 0.48;
                final slideY = -panelH * (1 - _panelAnim.value);

                return Positioned(
                  top: slideY,
                  left: 0,
                  right: 0,
                  child: _AnnouncementPanel(
                    height: panelH,
                    announcements: provider.announcements,
                    currentCard: _currentCard,
                    pageController: _pageCtrl,
                    onCardChanged: (i) => setState(() => _currentCard = i),
                    onClose: _closePanel,
                    panelProgress: _panelAnim.value,
                  ),
                );
              },
            ),

            // ── Rope + Lantern (draggable, physics-animated) ───────────────
            AnimatedBuilder(
              animation: Listenable.merge(
                  [_swingAnim, _panelAnim, _returnCtrl]),
              builder: (_, __) {
                // ── Fixed anchor point ──────────────────────────────────────
                final anchorX = _anchorX;
                const anchorY = 0.0;

                // ── Lantern position ────────────────────────────────────────
                final panelPullY = _panelAnim.value * 18.0;

                double lx, ly;
                if (_isDragging) {
                  lx = _lanternX;
                  ly = _lanternY;
                } else if (_returnCtrl.isAnimating) {
                  lx = _returnAnim.value.dx;
                  ly = _returnAnim.value.dy;
                } else {
                  lx = anchorX;
                  ly = _restY - panelPullY;
                }

                // Sync stored coordinates for next interaction
                if (!_isDragging && !_returnCtrl.isAnimating) {
                  _lanternX = lx;
                  _lanternY = ly;
                }

                // ── Swing angle (applied to lantern only) ───────────────────
                final angle = _swingAnim.value;

                // ── Rope: straight line from fixed anchor to lantern top ────
                final dx = lx - anchorX;
                final dy = ly - anchorY;
                final ropeLength = math.sqrt(dx * dx + dy * dy);
                // Corrected: Invert the angle to match Flutter's coordinate system
                final ropeAngle = -math.atan2(dx, dy);

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ── Rope — fixed at top, stretches to lantern ──────────
                    Positioned(
                      left: anchorX - 1,
                      top: anchorY,
                      child: IgnorePointer(
                        child: Transform.rotate(
                          angle: ropeAngle,
                          alignment: Alignment.topCenter,
                          child: CustomPaint(
                            size: Size(2, math.max(0, ropeLength)),
                            painter: _RopePainter(
                              ropeLength: math.max(0, ropeLength),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Lantern body (draggable) ────────────────────────────
                    Positioned(
                      left: lx - 20,
                      top: ly,
                      child: GestureDetector(
                        onPanStart: _onDragStart,
                        onPanUpdate: _onDragUpdate,
                        onPanEnd: _onDragEnd,
                        onTap: _togglePanel,
                        child: Transform.rotate(
                          angle: angle,
                          alignment: Alignment.topCenter,
                          child: _LanternBodyWidget(
                            hasNew: provider.hasNew,
                            isPanelOpen: provider.panelOpen,
                            isDragging: _isDragging,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// ─── Lantern Body Widget (no rope — rope is separate Positioned widget) ──────────
class _LanternBodyWidget extends StatelessWidget {
  final bool hasNew;
  final bool isPanelOpen;
  final bool isDragging;

  const _LanternBodyWidget({
    required this.hasNew,
    required this.isPanelOpen,
    required this.isDragging,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 52, // just the lantern body + tassel, no rope
      child: CustomPaint(
        painter: _LanternBodyPainter(
          hasNew: hasNew,
          isPanelOpen: isPanelOpen,
          isDragging: isDragging,
        ),
      ),
    );
  }
}

// ─── Rope Painter ─────────────────────────────────────────────────────────────
// Draws a STRAIGHT line from top (anchor) to bottom (lantern attachment).
// The widget itself is rotated by the caller to point toward the lantern,
// so the rope is always a clean vertical line within its own coordinate space.
// Length = pixel distance from fixed anchor to current lantern position.
class _RopePainter extends CustomPainter {
  final double ropeLength;

  const _RopePainter({required this.ropeLength});

  @override
  void paint(Canvas canvas, Size size) {
    if (ropeLength < 1) return;

    // Straight rope line — anchor at top, lantern attachment at bottom
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, ropeLength),
      Paint()
        ..color = AppColors.gold.withOpacity(0.92)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Small gold knot/hook dot at the fixed anchor point (top of screen)
    canvas.drawCircle(
      Offset(size.width / 2, 0),
      3.0,
      Paint()
        ..color = AppColors.gold
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _RopePainter old) =>
      old.ropeLength != ropeLength;
}

class _LanternBodyPainter extends CustomPainter {
  final bool hasNew;
  final bool isPanelOpen;
  final bool isDragging;

  const _LanternBodyPainter({
    required this.hasNew,
    required this.isPanelOpen,
    required this.isDragging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; // center x of lantern

    // ── Lantern body ───────────────────────────────────────────────────────
    const baseY = 2.0; // small offset from top
    final lh = 32.0; // lantern height

    final goldFill = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.fill;
    final darkFill = Paint()
      ..color = AppColors.primaryDark
      ..style = PaintingStyle.fill;
    final goldStroke = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // Top string/hook
    canvas.drawLine(
        Offset(cx, baseY - 2),
        Offset(cx, baseY + 3),
        goldStroke);

    // Top cap
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - 8, baseY + 2, 16, 5),
            const Radius.circular(2)),
        goldFill);

    // Body
    final bodyPath = Path()
      ..moveTo(cx - 6, baseY + 7)
      ..quadraticBezierTo(cx - 14, baseY + lh * 0.5, cx - 6, baseY + lh - 4)
      ..lineTo(cx + 6, baseY + lh - 4)
      ..quadraticBezierTo(cx + 14, baseY + lh * 0.5, cx + 6, baseY + 7)
      ..close();
    canvas.drawPath(bodyPath, darkFill);
    canvas.drawPath(bodyPath, goldStroke);

    // Horizontal stripes
    for (int i = 1; i <= 2; i++) {
      final y = baseY + 7 + (lh - 11) * (i / 3.0);
      final xLeft = cx - 10 * math.sin(math.pi * (i / 3.0)) - 4;
      final xRight = cx + 10 * math.sin(math.pi * (i / 3.0)) + 4;
      canvas.drawLine(
          Offset(xLeft.toDouble(), y),
          Offset(xRight.toDouble(), y),
          goldStroke..color = AppColors.gold.withOpacity(0.35)
            ..strokeWidth = 0.8);
    }

    // Glow dot center
    if (isPanelOpen) {
      canvas.drawCircle(
          Offset(cx, baseY + lh * 0.5),
          3,
          Paint()..color = AppColors.goldLight.withOpacity(0.6)
            ..style = PaintingStyle.fill);
    }

    // Bottom cap
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - 8, baseY + lh - 4, 16, 5),
            const Radius.circular(2)),
        goldFill..color = AppColors.gold);

    // Tassel
    for (int i = 0; i < 3; i++) {
      final tx = cx - 4 + i * 4.0;
      canvas.drawLine(
          Offset(tx, baseY + lh + 1),
          Offset(tx + (i == 1 ? 0 : i == 0 ? -2 : 2),
              baseY + lh + 7),
          goldStroke..strokeWidth = 1.0..color = AppColors.gold.withOpacity(0.8));
    }

    // New badge dot
    if (hasNew) {
      canvas.drawCircle(
          Offset(cx + 9, baseY + 4),
          4,
          Paint()..color = AppColors.error..style = PaintingStyle.fill);
      canvas.drawCircle(
          Offset(cx + 9, baseY + 4),
          4,
          Paint()
            ..color = AppColors.primaryDark
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
    }

    // Open/close arrow hint (↕)
    final arrowPaint = Paint()
      ..color = AppColors.gold.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    if (!isPanelOpen) {
      // Down arrow
      canvas.drawPath(
          Path()
            ..moveTo(cx - 3, baseY + lh * 0.45)
            ..lineTo(cx, baseY + lh * 0.6)
            ..lineTo(cx + 3, baseY + lh * 0.45),
          arrowPaint);
    } else {
      // Up arrow
      canvas.drawPath(
          Path()
            ..moveTo(cx - 3, baseY + lh * 0.6)
            ..lineTo(cx, baseY + lh * 0.45)
            ..lineTo(cx + 3, baseY + lh * 0.6),
          arrowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LanternBodyPainter old) =>
      old.hasNew != hasNew ||
          old.isPanelOpen != isPanelOpen ||
          old.isDragging != isDragging;
}

// ─── Announcement Panel ────────────────────────────────────────────────────────
class _AnnouncementPanel extends StatelessWidget {
  final double height;
  final List<Announcement> announcements;
  final int currentCard;
  final PageController pageController;
  final void Function(int) onCardChanged;
  final VoidCallback onClose;
  final double panelProgress; // 0–1

  const _AnnouncementPanel({
    required this.height,
    required this.announcements,
    required this.currentCard,
    required this.pageController,
    required this.onCardChanged,
    required this.onClose,
    required this.panelProgress,
  });

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final isWide = MediaQuery.of(context).size.width >= 600;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x50000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Corner decorations
          Positioned(
            top: safeTop + 8,
            left: 12,
            child: _CornerDeco(size: 32),
          ),
          Positioned(
            top: safeTop + 8,
            right: 12,
            child: _CornerDeco(size: 32, flipH: true),
          ),

          // Lantern row along top edge
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: const Size(double.infinity, 28),
              painter: _MiniLanternRowPainter(),
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.fromLTRB(
              0,
              safeTop + 28,
              0,
              20,
            ),
            child: Column(
              children: [
                // Header row
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
                  child: Row(
                    children: [
                      CustomPaint(
                        size: const Size(14, 14),
                        painter: _LanternDotPainter(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Announcements',
                        style: GoogleFonts.playfairDisplaySc(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textOnDark,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Spacer(),
                      // Close button
                      GestureDetector(
                        onTap: onClose,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.gold.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.gold.withOpacity(0.6),
                                width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_up_rounded,
                            color: AppColors.gold,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Swipeable cards
                Expanded(
                  child: PageView.builder(
                    controller: pageController,
                    itemCount: announcements.length,
                    onPageChanged: onCardChanged,
                    padEnds: true,
                    itemBuilder: (context, i) {
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isWide ? 32 : 16,
                          vertical: 4,
                        ),
                        child: _AnnouncementCard(
                            announcement: announcements[i]),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // Page dots
                if (announcements.length > 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      announcements.length,
                          (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == currentCard ? 20 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == currentCard
                              ? AppColors.gold
                              : AppColors.gold.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Single Announcement Card ──────────────────────────────────────────────────
class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;

  const _AnnouncementCard({required this.announcement});

  Color get _typeColor {
    switch (announcement.type) {
      case AnnouncementType.discount:  return const Color(0xFF15803D);
      case AnnouncementType.newMenu:   return AppColors.gold;
      case AnnouncementType.event:     return const Color(0xFF7C3AED);
      case AnnouncementType.general:   return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _typeColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _typeColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge + new dot
          Row(
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: _typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                      color: _typeColor.withOpacity(0.4), width: 1),
                ),
                child: Text(
                  announcement.type.badge,
                  style: GoogleFonts.karla(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _typeColor,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              if (announcement.isNew) ...[
                const SizedBox(width: 6),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: AppColors.error, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(
                  'New',
                  style: GoogleFonts.karla(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ],
              const Spacer(),
              // Chinese corner accent
              CustomPaint(
                  size: const Size(20, 20),
                  painter: _SmallCornerPainter()),
            ],
          ),

          const SizedBox(height: 12),

          // Title
          Text(
            announcement.title,
            style: GoogleFonts.playfairDisplaySc(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 8),

          // Body
          Expanded(
            child: Text(
              announcement.body,
              style: GoogleFonts.karla(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // CTA button
          if (announcement.ctaLabel != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: handle ctaRoute navigation
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _typeColor,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: _typeColor.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  announcement.ctaLabel!.toUpperCase(),
                  style: GoogleFonts.karla(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Helper widgets ─────────────────────────────────────────────────────────────
class _CornerDeco extends StatelessWidget {
  final double size;
  final bool flipH;
  const _CornerDeco({required this.size, this.flipH = false});

  @override
  Widget build(BuildContext context) {
    Widget w = CustomPaint(
      size: Size(size, size),
      painter: _CornerPainter(),
    );
    if (flipH) {
      w = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(-1.0, 1.0),
        child: w,
      );
    }
    return w;
  }
}

// ─── Painters ──────────────────────────────────────────────────────────────────
class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.gold.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(
        Path()
          ..moveTo(size.width * 0.1, size.height * 0.6)
          ..lineTo(size.width * 0.1, size.height * 0.1)
          ..lineTo(size.width * 0.6, size.height * 0.1),
        p);

    canvas.drawArc(
        Rect.fromLTWH(size.width * 0.15, size.height * 0.15,
            size.width * 0.35, size.height * 0.35),
        math.pi, math.pi * 0.5, false, p);

    canvas.drawCircle(
        Offset(size.width * 0.1, size.height * 0.1),
        2.5,
        Paint()
          ..color = AppColors.gold.withOpacity(0.45)
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

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

class _MiniLanternRowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = AppColors.gold.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = AppColors.gold.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final spacing = size.width / 7;
    for (int i = 0; i < 7; i++) {
      final cx = spacing * i + spacing / 2;
      final top = 0.0;
      final capH = size.height * 0.22;
      final bodyH = size.height * 0.55;

      // String
      canvas.drawLine(
          Offset(cx, top),
          Offset(cx, top + capH * 0.4),
          stroke..color = AppColors.gold.withOpacity(0.5)..strokeWidth = 0.7);

      // Cap
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx - 5, top + capH * 0.3, 10, capH * 0.5),
              const Radius.circular(1.5)),
          fill..color = AppColors.gold.withOpacity(0.4));

      // Body
      final bodyPath = Path()
        ..moveTo(cx - 4, top + capH)
        ..quadraticBezierTo(cx - 8, top + capH + bodyH * 0.5,
            cx - 4, top + capH + bodyH - 2)
        ..lineTo(cx + 4, top + capH + bodyH - 2)
        ..quadraticBezierTo(cx + 8, top + capH + bodyH * 0.5,
            cx + 4, top + capH)
        ..close();
      canvas.drawPath(bodyPath, fill..color = AppColors.primaryDark.withOpacity(0.7));
      canvas.drawPath(bodyPath, stroke..strokeWidth = 0.8);

      // Tassel
      canvas.drawLine(
          Offset(cx, top + capH + bodyH - 2),
          Offset(cx, top + capH + bodyH + 4),
          stroke..strokeWidth = 0.7..color = AppColors.gold.withOpacity(0.4));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _SmallCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.gold.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
        Path()
          ..moveTo(size.width * 0.15, size.height * 0.7)
          ..lineTo(size.width * 0.15, size.height * 0.15)
          ..lineTo(size.width * 0.7, size.height * 0.15),
        p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── Custom bounce curve ───────────────────────────────────────────────────────
class _BounceOutCurve extends Curve {
  const _BounceOutCurve();

  @override
  double transformInternal(double t) {
    if (t < 0.6) {
      return (t / 0.6) * (t / 0.6);
    } else if (t < 0.8) {
      final t2 = (t - 0.7) / 0.1;
      return 0.9 + t2 * 0.1 + math.sin(t2 * math.pi) * 0.08;
    } else if (t < 0.93) {
      final t2 = (t - 0.87) / 0.06;
      return 0.97 + math.sin(t2 * math.pi) * 0.04;
    } else {
      return 1.0;
    }
  }
}