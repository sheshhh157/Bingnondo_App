import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/tracking_models.dart';
import '../../services/support_chat_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

class SupportChatScreen extends StatefulWidget {
  final int? activeOrderId;

  const SupportChatScreen({super.key, this.activeOrderId});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    final provider = context.read<SupportChatProvider>();
    provider.setActiveOrderId(widget.activeOrderId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.loadChat().then((_) => _scrollToBottom(animated: false));
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      final max = _scrollCtrl.position.maxScrollExtent;
      if (animated) {
        _scrollCtrl.animateTo(max,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut);
      } else {
        _scrollCtrl.jumpTo(max);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    _inputFocus.unfocus();

    await context.read<SupportChatProvider>().sendMessage(text);
    _scrollToBottom();
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
          child: Consumer<SupportChatProvider>(
            builder: (context, provider, _) {
              return Column(
                children: [
                  _buildHeader(context, provider),
                  Expanded(child: _buildBody(context, provider)),
                  _buildInputBar(context, provider),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, SupportChatProvider provider) {
    final isLocked = provider.isLocked;

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

          // Staff avatar
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 1.5),
            ),
            child: CustomPaint(painter: _StaffAvatarPainter()),
          ),

          const SizedBox(width: AppSpacing.sm),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bingnondo Staff',
                  style: GoogleFonts.playfairDisplaySc(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnDark,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isLocked
                            ? AppColors.textMuted
                            : AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isLocked ? 'Chat closed' : 'Active',
                      style: GoogleFonts.karla(
                        fontSize: 11,
                        color: AppColors.textOnDark.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Order tag pill
          if (widget.activeOrderId != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                    color: AppColors.gold.withOpacity(0.4), width: 1),
              ),
              child: Text(
                'Order #${widget.activeOrderId}',
                style: GoogleFonts.karla(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gold,
                ),
              ),
            ),

          const SizedBox(width: 4),
          const ChineseCornerDecoration(size: 28, flipH: true),
        ],
      ),
    );
  }

  // ─── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody(BuildContext context, SupportChatProvider provider) {
    switch (provider.state) {
      case ChatLoadState.loading:
      case ChatLoadState.initial:
        return const Center(
          child: CircularProgressIndicator(
              color: AppColors.gold, strokeWidth: 2.5),
        );

      case ChatLoadState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded,
                    color: AppColors.textMuted, size: 48),
                const SizedBox(height: AppSpacing.md),
                Text('Could not load chat',
                    style: AppTextStyles.headline(context),
                    textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                Text(provider.errorMessage ?? 'Please try again.',
                    style: AppTextStyles.bodyMedium(context),
                    textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'TRY AGAIN',
                  onPressed: provider.loadChat,
                  isSmall: true,
                ),
              ],
            ),
          ),
        );

      case ChatLoadState.noActiveOrder:
        return _buildNoActiveOrderState(context);

      case ChatLoadState.loaded:
        if (provider.messages.isEmpty) {
          return _buildEmptyChat(context, provider.isLocked);
        }
        return _buildMessageList(context, provider);
    }
  }

  // ─── No active order ───────────────────────────────────────────────────────
  Widget _buildNoActiveOrderState(BuildContext context) {
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
                    size: const Size(32, 46),
                    painter: _SmallLanternPainter(tilt: -0.15)),
                const SizedBox(width: 10),
                CustomPaint(
                    size: const Size(44, 62),
                    painter: _SmallLanternPainter(tilt: 0)),
                const SizedBox(width: 10),
                CustomPaint(
                    size: const Size(32, 46),
                    painter: _SmallLanternPainter(tilt: 0.15)),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('No active order',
                style: AppTextStyles.display2(context),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Staff chat is available once you have an active order. '
                  'For menu questions, use our AI chatbot.',
              style: AppTextStyles.bodyMedium(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'BACK TO MENU',
              onPressed: () => Navigator.pop(context),
              isSmall: true,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Empty chat (unlocked, no messages yet) ────────────────────────────────
  Widget _buildEmptyChat(BuildContext context, bool isLocked) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomPaint(
                  size: const Size(36, 52),
                  painter: _SmallLanternPainter(tilt: -0.12)),
              const SizedBox(width: 10),
              CustomPaint(
                  size: const Size(48, 68),
                  painter: _SmallLanternPainter(tilt: 0)),
              const SizedBox(width: 10),
              CustomPaint(
                  size: const Size(36, 52),
                  painter: _SmallLanternPainter(tilt: 0.12)),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          Text(
            isLocked ? 'Chat is closed' : 'Chat with our staff',
            style: AppTextStyles.display2(context),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.sm),

          Text(
            isLocked
                ? 'This chat is closed because all your orders are complete. Place a new order to reopen support chat.'
                : 'Have questions about your order? Our staff is here to help. Type your message below.',
            style: AppTextStyles.bodyMedium(context),
            textAlign: TextAlign.center,
          ),

          if (!isLocked) ...[
            const SizedBox(height: AppSpacing.xl),
            // Quick prompts
            Text('Quick messages:', style: AppTextStyles.label(context)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: _quickPrompts
                  .map((p) => _QuickPromptChip(
                label: p,
                onTap: () {
                  _inputCtrl.text = p;
                  _inputFocus.requestFocus();
                },
              ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  static const _quickPrompts = [
    'Is my order ready?',
    'How long will it take?',
    'Can I update my order?',
    'Where is my rider?',
  ];

  // ─── Message list ──────────────────────────────────────────────────────────
  Widget _buildMessageList(BuildContext context, SupportChatProvider provider) {
    final messages = provider.messages;

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      itemCount: messages.length + (provider.isSending ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == messages.length && provider.isSending) {
          return const _SendingIndicator();
        }

        final msg = messages[i];
        final prevMsg = i > 0 ? messages[i - 1] : null;
        final showDateDivider = prevMsg == null ||
            !_isSameDay(msg.sentAt, prevMsg.sentAt);

        return Column(
          children: [
            if (showDateDivider) _DateDivider(date: msg.sentAt),
            _SupportBubble(message: msg),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ─── Input bar ─────────────────────────────────────────────────────────────
  Widget _buildInputBar(BuildContext context, SupportChatProvider provider) {
    final isLocked = provider.isLocked;
    final noOrder = provider.state == ChatLoadState.noActiveOrder;
    final disabled = isLocked || noOrder;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: disabled
          ? Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            isLocked
                ? 'Chat closed — no active orders'
                : 'Place an order to unlock staff chat',
            style: AppTextStyles.caption(context)
                .copyWith(fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
      )
          : Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Input
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                    color: AppColors.inputBorder, width: 1.5),
              ),
              child: TextField(
                controller: _inputCtrl,
                focusNode: _inputFocus,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: GoogleFonts.karla(
                    fontSize: 15, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Message our staff…',
                  hintStyle: GoogleFonts.karla(
                      fontSize: 14, color: AppColors.textMuted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Send button
          GestureDetector(
            onTap: provider.isSending ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: provider.isSending
                    ? AppColors.primary.withOpacity(0.5)
                    : AppColors.primary,
                shape: BoxShape.circle,
                boxShadow:
                provider.isSending ? [] : AppShadows.goldGlow,
              ),
              child: provider.isSending
                  ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                      color: AppColors.textOnDark, strokeWidth: 2))
                  : const Icon(Icons.send_rounded,
                  color: AppColors.textOnDark, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Support Chat Bubble ───────────────────────────────────────────────────────
class _SupportBubble extends StatelessWidget {
  final SupportMessage message;
  const _SupportBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isCustomer = message.isFromCustomer;

    return Padding(
      padding: EdgeInsets.only(
        top: AppSpacing.xs,
        bottom: AppSpacing.xs,
        left: isCustomer ? 60 : 0,
        right: isCustomer ? 0 : 60,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
        isCustomer ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isCustomer) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 6, bottom: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold, width: 1),
              ),
              child: CustomPaint(painter: _StaffAvatarPainter()),
            ),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment: isCustomer
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Order tag (if any)
                if (message.relatedOrderId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                            color: AppColors.gold.withOpacity(0.3), width: 1),
                      ),
                      child: Text(
                        'Re: Order #${message.relatedOrderId}',
                        style: GoogleFonts.karla(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  ),

                // Bubble
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2),
                  decoration: BoxDecoration(
                    color: isCustomer ? AppColors.primary : AppColors.card,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(AppRadius.lg),
                      topRight: const Radius.circular(AppRadius.lg),
                      bottomLeft: Radius.circular(
                          isCustomer ? AppRadius.lg : 4),
                      bottomRight: Radius.circular(
                          isCustomer ? 4 : AppRadius.lg),
                    ),
                    boxShadow: AppShadows.card,
                    border: isCustomer
                        ? null
                        : Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Text(
                    message.content,
                    style: GoogleFonts.karla(
                      fontSize: 14,
                      color: isCustomer
                          ? AppColors.textOnDark
                          : AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 3),
                Text(
                  _formatTime(message.sentAt),
                  style: AppTextStyles.caption(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
  }
}

// ─── Date Divider ──────────────────────────────────────────────────────────────
class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(_label, style: AppTextStyles.caption(context)),
          ),
          const Expanded(child: Divider(color: AppColors.border)),
        ],
      ),
    );
  }
}

// ─── Sending Indicator ─────────────────────────────────────────────────────────
class _SendingIndicator extends StatefulWidget {
  const _SendingIndicator();
  @override
  State<_SendingIndicator> createState() => _SendingIndicatorState();
}

class _SendingIndicatorState extends State<_SendingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
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
    return Padding(
      padding: const EdgeInsets.only(left: 34, top: 4, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 1),
            ),
            child: CustomPaint(painter: _StaffAvatarPainter()),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
                bottomRight: Radius.circular(AppRadius.lg),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: AppColors.border),
            ),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final offset = i * 0.33;
                  final opacity =
                  ((_anim.value - offset).abs() < 0.4) ? 0.9 : 0.25;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(opacity),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Prompt Chip ────────────────────────────────────────────────────────
class _QuickPromptChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickPromptChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceWarm,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
              color: AppColors.gold.withOpacity(0.5), width: 1),
        ),
        child: Text(
          label,
          style: GoogleFonts.karla(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Painters ──────────────────────────────────────────────────────────────────

class _StaffAvatarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.fill;
    final s = size.width / 28;
    canvas.scale(s, s);

    // Head
    canvas.drawOval(const Rect.fromLTWH(5, 3, 18, 16), gold);
    // Hat (staff beret-style)
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 1, 22, 5), const Radius.circular(3)),
        gold..color = AppColors.gold.withOpacity(0.8));
    // Body
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(4, 18, 20, 10), const Radius.circular(4)),
        gold..color = AppColors.primaryDark.withOpacity(0.6));
    // Eyes
    final eye = Paint()
      ..color = AppColors.primaryDark
      ..style = PaintingStyle.fill;
    canvas.drawOval(const Rect.fromLTWH(9, 9, 3, 3), eye);
    canvas.drawOval(const Rect.fromLTWH(16, 9, 3, 3), eye);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SmallLanternPainter extends CustomPainter {
  final double tilt;
  const _SmallLanternPainter({required this.tilt});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(tilt);
    canvas.translate(-size.width / 2, -size.height / 2);

    final gFill = Paint()..color = AppColors.gold..style = PaintingStyle.fill;
    final mFill = Paint()
      ..color = AppColors.primaryDark
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = AppColors.gold
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
        stroke..color = AppColors.gold.withOpacity(0.3)..strokeWidth = 1);
    canvas.drawLine(Offset(w * 0.05, h * 0.48), Offset(w * 0.95, h * 0.48),
        stroke..color = AppColors.gold.withOpacity(0.3)..strokeWidth = 1);

    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.1, h * 0.76, w * 0.8, h * 0.08),
            const Radius.circular(3)),
        gFill..color = AppColors.gold);

    final tp = Paint()
      ..color = AppColors.gold
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      final x = w * 0.22 + i * w * 0.18;
      canvas.drawLine(
          Offset(x, h * 0.84), Offset(x + (i.isOdd ? 3 : -3), h), tp);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}