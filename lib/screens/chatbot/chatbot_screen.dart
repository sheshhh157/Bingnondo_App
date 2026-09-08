import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/menu_models.dart';
import '../../services/chatbot_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  late final AnimationController _headerAnim;
  late final Animation<double> _headerFade;

  // Quick suggestion chips — common questions for Binondo cafe
  static const List<String> _suggestions = [
    'What\'s available now?',
    'Do you have vegetarian options?',
    'What are your bestsellers?',
    'How much is delivery?',
    'What time do you close?',
  ];

  @override
  void initState() {
    super.initState();

    _headerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _headerFade =
        CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _headerAnim.forward();

    // Load history
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatbotProvider>().loadHistory().then((_) {
        _scrollToBottom();
      });
    });
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          maxExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(maxExtent);
      }
    });
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _inputController.clear();
    _inputFocus.unfocus();

    await context.read<ChatbotProvider>().sendMessage(text);
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
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Consumer<ChatbotProvider>(
                builder: (context, chatbot, _) {
                  if (chatbot.isEmpty) {
                    return _buildWelcomeState(context);
                  }
                  return _buildMessageList(context, chatbot);
                },
              ),
            ),
            _buildInputBar(context),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return FadeTransition(
      opacity: _headerFade,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
        decoration: const BoxDecoration(
          color: AppColors.primaryDark,
        ),
        child: Row(
          children: [
            // Back button
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              color: AppColors.textOnDark,
              onPressed: () => Navigator.pop(context),
              tooltip: 'Back to Menu',
            ),

            // Bot avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold, width: 1.5),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/ndo_bot.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return CustomPaint(
                      painter: _BotAvatarPainter(),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(width: AppSpacing.sm),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ndo — Bingnondo Bot',
                    style: GoogleFonts.playfairDisplaySc(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textOnDark,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Online · Menu & FAQ',
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

            // Corner decorations
            const ChineseCornerDecoration(size: 28),
          ],
        ),
      ),
    );
  }

  // ─── Welcome / empty state ─────────────────────────────────────────────────
  Widget _buildWelcomeState(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: AppSpacing.md),

          // Bot Avatar Image
          Image.asset(
            'assets/images/ndo_bot.png',
            width: 100,
            height: 100,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),

          const SizedBox(height: AppSpacing.md),

          // Decorative lanterns
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomPaint(
                  size: const Size(36, 50),
                  painter: _SingleLanternPainter(tilt: -0.12)),
              const SizedBox(width: 12),
              CustomPaint(
                  size: const Size(48, 68),
                  painter: _SingleLanternPainter(tilt: 0)),
              const SizedBox(width: 12),
              CustomPaint(
                  size: const Size(36, 50),
                  painter: _SingleLanternPainter(tilt: 0.12)),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          Text(
            'Kamusta! I\'m Ndo',
            style: AppTextStyles.display2(context),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.sm),

          Text(
            'Your Bingnondo guide — ask me anything about our menu, prices, or what\'s available today.',
            style: AppTextStyles.bodyMedium(context),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.xl),

          // Disclaimer banner
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceWarm,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CustomPaint(
                  size: const Size(14, 14),
                  painter: _SmallLanternDot(),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'For order updates, use the Order Chat once you\'ve placed an order.',
                    style: GoogleFonts.karla(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Suggestion chips
          Text(
            'Try asking:',
            style: AppTextStyles.label(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.center,
            children: _suggestions
                .map((s) => _SuggestionChip(
              label: s,
              onTap: () => _send(s),
            ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ─── Message list ──────────────────────────────────────────────────────────
  Widget _buildMessageList(BuildContext context, ChatbotProvider chatbot) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      itemCount: chatbot.messages.length +
          (_suggestions.isNotEmpty && chatbot.messages.length < 3 ? 1 : 0),
      itemBuilder: (context, index) {
        // Show suggestions after first exchange if fewer than 3 messages
        if (index == chatbot.messages.length &&
            chatbot.messages.length < 3) {
          return _buildSuggestionRow(context);
        }

        final msg = chatbot.messages[index];
        return _ChatBubble(message: msg);
      },
    );
  }

  Widget _buildSuggestionRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _suggestions
            .take(3)
            .map((s) => _SuggestionChip(label: s, onTap: () => _send(s)))
            .toList(),
      ),
    );
  }

  // ─── Input bar ─────────────────────────────────────────────────────────────
  Widget _buildInputBar(BuildContext context) {
    return Consumer<ChatbotProvider>(
      builder: (context, chatbot, _) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm + MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Input field
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: AppColors.inputBorder, width: 1.5),
                  ),
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocus,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    keyboardType: TextInputType.multiline,
                    enabled: !chatbot.isSending,
                    onSubmitted: (v) => _send(v),
                    style: GoogleFonts.karla(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ask about the menu…',
                      hintStyle: GoogleFonts.karla(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: AppSpacing.sm),

              // Send button
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: GestureDetector(
                  onTap: chatbot.isSending
                      ? null
                      : () => _send(_inputController.text),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: chatbot.isSending
                          ? AppColors.primary.withOpacity(0.5)
                          : AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: chatbot.isSending ? [] : AppShadows.goldGlow,
                    ),
                    child: chatbot.isSending
                        ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        color: AppColors.textOnDark,
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(
                      Icons.send_rounded,
                      color: AppColors.textOnDark,
                      size: 20,
                    ),
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

// ─── Chat Bubble ───────────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == MessageSender.user;

    return Padding(
      padding: EdgeInsets.only(
        top: AppSpacing.xs,
        bottom: AppSpacing.xs,
        left: isUser ? 60 : 0,
        right: isUser ? 0 : 60,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // Bot avatar
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 6, bottom: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold, width: 1),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/ndo_bot.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return CustomPaint(painter: _BotAvatarPainter());
                  },
                ),
              ),
            ),
          ],

          // Bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.lg),
                  topRight: const Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(isUser ? AppRadius.lg : 4),
                  bottomRight: Radius.circular(isUser ? 4 : AppRadius.lg),
                ),
                boxShadow: AppShadows.card,
                border: isUser
                    ? null
                    : Border.all(color: AppColors.border, width: 1),
              ),
              child: message.isLoading
                  ? _TypingIndicator()
                  : Text(
                message.content,
                style: GoogleFonts.karla(
                  fontSize: 14,
                  color: isUser
                      ? AppColors.textOnDark
                      : AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ),

          if (isUser) ...[
            const SizedBox(width: 6),
            // Timestamp dot
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                _formatTime(message.timestamp),
                style: AppTextStyles.caption(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}

// ─── Typing indicator (three dots) ────────────────────────────────────────────
class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
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
    return SizedBox(
      width: 36,
      height: 16,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (i) {
              final offset = (i * 0.33).clamp(0.0, 1.0);
              final opacity = ((_anim.value - offset).abs() < 0.4)
                  ? 0.9
                  : 0.3;
              return Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(opacity),
                  shape: BoxShape.circle,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// ─── Suggestion Chip ───────────────────────────────────────────────────────────
class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SuggestionChip({required this.label, required this.onTap});

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
          border: Border.all(color: AppColors.gold.withOpacity(0.5), width: 1),
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

// ─── Custom Painters ───────────────────────────────────────────────────────────

class _BotAvatarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.fill;
    final s = size.width / 28;
    canvas.scale(s, s);

    // Cat head
    canvas.drawOval(const Rect.fromLTWH(4, 4, 20, 18), gold);

    // Ears
    final lEar = Path()..moveTo(5, 10)..lineTo(2, 2)..lineTo(10, 7)..close();
    final rEar = Path()..moveTo(23, 10)..lineTo(26, 2)..lineTo(18, 7)..close();
    canvas.drawPath(lEar, gold);
    canvas.drawPath(rEar, gold);

    // Eyes
    final eyePaint = Paint()
      ..color = AppColors.primaryDark
      ..style = PaintingStyle.fill;
    canvas.drawOval(const Rect.fromLTWH(9, 10, 3, 3), eyePaint);
    canvas.drawOval(const Rect.fromLTWH(16, 10, 3, 3), eyePaint);

    // Nose
    canvas.drawCircle(const Offset(14, 16), 1.5,
        eyePaint..color = AppColors.primaryDark.withOpacity(0.6));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SingleLanternPainter extends CustomPainter {
  final double tilt;
  const _SingleLanternPainter({required this.tilt});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(tilt);
    canvas.translate(-size.width / 2, -size.height / 2);

    final fill = Paint()
      ..color = AppColors.primaryDark
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final goldFill = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // String
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h * 0.08), stroke);

    // Top cap
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.1, h * 0.06, w * 0.8, h * 0.1),
            const Radius.circular(3)),
        goldFill);

    // Body
    final body = Path()
      ..moveTo(w * 0.05, h * 0.18)
      ..quadraticBezierTo(0, h * 0.5, w * 0.05, h * 0.78)
      ..lineTo(w * 0.95, h * 0.78)
      ..quadraticBezierTo(w, h * 0.5, w * 0.95, h * 0.18)
      ..close();
    canvas.drawPath(body, fill);
    canvas.drawPath(body, stroke);

    // Cross lines
    canvas.drawLine(Offset(w / 2, h * 0.18), Offset(w / 2, h * 0.78),
        stroke..color = AppColors.gold.withOpacity(0.3)..strokeWidth = 1);
    canvas.drawLine(Offset(w * 0.05, h * 0.48), Offset(w * 0.95, h * 0.48),
        stroke..color = AppColors.gold.withOpacity(0.3)..strokeWidth = 1);

    // Bottom cap
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.1, h * 0.76, w * 0.8, h * 0.08),
            const Radius.circular(3)),
        goldFill..color = AppColors.gold);

    // Tassel
    final tasselPaint = Paint()
      ..color = AppColors.gold
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      final x = w * 0.25 + i * w * 0.17;
      canvas.drawLine(
          Offset(x, h * 0.84), Offset(x + (i.isOdd ? 3 : -3), h), tasselPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SmallLanternDot extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(
        Rect.fromLTWH(0, size.height * 0.2, size.width, size.height * 0.6),
        Paint()
          ..color = AppColors.gold.withOpacity(0.5)
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}