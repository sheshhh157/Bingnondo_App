import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/cart_models.dart';
import '../../models/menu_models.dart';
import '../../services/cart_provider.dart';
import '../../services/business_hours_provider.dart';
import '../../services/menu_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/business_hours_banner.dart';
import 'checkout_screen.dart';
import '../profile/complete_profile_screen.dart';

class CartScreen extends StatefulWidget {
  final VoidCallback? onBrowseMenu;

  const CartScreen({super.key, this.onBrowseMenu});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    // Delivery fee is public config — fetch it as soon as the cart exists so
    // the summary doesn't show ₱0.00 while the customer is still shopping.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CartProvider>().loadCheckoutConfig();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleProceed(BuildContext context) async {
    final cart = context.read<CartProvider>();
    final menu = context.read<MenuProvider>();

    // Business hours gate — no checkout outside the order window.
    final hours = context.read<BusinessHoursProvider>();
    if (hours.isKnownClosed) {
      _showClosedDialog(context, hours);
      return;
    }

    // Check for unavailable items before even hitting the API
    final unavailableIds = cart.getUnavailableItemIds(menu.allItems);
    if (unavailableIds.isNotEmpty) {
      _showUnavailableDialog(context, unavailableIds, cart, menu.allItems);
      return;
    }

    final passed = await cart.checkProfileGate();

    if (!context.mounted) return;

    if (!passed) {
      if (cart.error == CartError.profileIncomplete) {
        // Redirect to Complete Profile
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CompleteProfileScreen()),
        );
        return;
      }
      // Suspended or network error — shown via banner in UI
      return;
    }

    // All good — go to checkout
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => const CheckoutScreen(),
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

  void _showClosedDialog(
      BuildContext context, BusinessHoursProvider hours) {
    final today = hours.status?.today;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(
          children: [
            const Icon(Icons.lock_clock_rounded,
                color: AppColors.error, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text('We are closed',
                  style: AppTextStyles.headline(context)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hours.message,
              style: AppTextStyles.bodyMedium(context),
            ),
            if (today != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Today: ${today.hoursLabel}',
                style: AppTextStyles.caption(context),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              'You can keep your items in the cart and check out once we reopen.',
              style: AppTextStyles.bodySmall(context),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: AppTextStyles.link(context)),
          ),
        ],
      ),
    );
  }

  void _showUnavailableDialog(
      BuildContext context,
      List<int> ids,
      CartProvider cart,
      List<MenuItem> allItems,
      ) {
    final names = ids
        .map((id) => allItems
        .where((m) => m.id == id)
        .firstOrNull
        ?.name ?? 'Unknown item')
        .join(', ');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Some items sold out',
            style: AppTextStyles.headline(context)),
        content: Text(
          '$names ${ids.length == 1 ? 'is' : 'are'} no longer available. Please remove '
              '${ids.length == 1 ? 'it' : 'them'} before proceeding.',
          style: AppTextStyles.bodyMedium(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Review Cart', style: AppTextStyles.link(context)),
          ),
          TextButton(
            onPressed: () {
              for (final id in ids) {
                cart.removeItem(id);
              }
              Navigator.pop(context);
            },
            child: Text(
              'Remove ${ids.length == 1 ? 'Item' : 'Items'}',
              style: GoogleFonts.karla(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
          ),
        ],
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
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Consumer<CartProvider>(
          builder: (context, cart, _) {
            return SafeArea(
              top: false,
              child: Column(
                children: [
                  _buildHeader(context, cart),
                  Expanded(
                    child: cart.isEmpty
                        ? _buildEmptyState(context)
                        : _buildCartBody(context, cart),
                  ),
                  if (!cart.isEmpty) _buildBottomBar(context, cart),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, CartProvider cart) {
    return Container(
      width: double.infinity,
      color: AppColors.primaryDark,
      padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          MediaQuery.of(context).padding.top + AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md),
      child: Row(
        children: [

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Order',
                  style: GoogleFonts.playfairDisplaySc(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnDark,
                  ),
                ),
                if (!cart.isEmpty)
                  Text(
                    '${cart.totalItemCount} '
                        '${cart.totalItemCount == 1 ? 'item' : 'items'} · '
                        '₱${cart.totalAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.karla(
                      fontSize: 12,
                      color: AppColors.textOnDark.withOpacity(0.75),
                    ),
                  ),
              ],
            ),
          ),
          if (!cart.isEmpty)
            TextButton.icon(
              onPressed: () => _showClearConfirm(context, cart),
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 16, color: AppColors.gold),
              label: Text(
                'Clear',
                style: GoogleFonts.karla(
                  fontSize: 13,
                  color: AppColors.gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.gold,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 4),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Cart Body ─────────────────────────────────────────────────────────────
  Widget _buildCartBody(BuildContext context, CartProvider cart) {
    final menuProvider = context.watch<MenuProvider>();

    return CustomScrollView(
      slivers: [
        // Error banner
        if (cart.error != CartError.none && cart.error != CartError.profileIncomplete)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
              child: StatusBanner(
                  message: cart.errorMessage ?? 'Something went wrong.',
                  isError: true),
            ),
          ),

        // Section label
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
            child: Row(
              children: [
                Text(
                  'ITEMS',
                  style: GoogleFonts.playfairDisplaySc(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${cart.totalItemCount}',
                    style: GoogleFonts.karla(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Swipe to remove',
                  style: AppTextStyles.caption(context),
                ),
              ],
            ),
          ),
        ),

        // Items
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, i) {
                final item = cart.items[i];
                final isUnavailable = menuProvider.allItems
                    .where((m) => m.id == item.menuItemId)
                    .firstOrNull
                    ?.isAvailable ==
                    false;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Dismissible(
                    key: ValueKey('${item.menuItemId}_${item.variantId ?? 0}'),
                    direction: DismissDirection.endToStart,
                    background: _dismissBackground(),
                    onDismissed: (_) => cart.removeItem(item.menuItemId, variantId: item.variantId),
                    child: _CartItemRow(
                      item: item,
                      isUnavailable: isUnavailable,
                      onIncrement: () =>
                          cart.incrementQuantity(item.menuItemId, variantId: item.variantId),
                      onDecrement: () =>
                          cart.decrementQuantity(item.menuItemId, variantId: item.variantId),
                      onRemove: () => cart.removeItem(item.menuItemId, variantId: item.variantId),
                      onNoteChanged: (note) =>
                          cart.updateNote(item.menuItemId, note, variantId: item.variantId),
                    ),
                  ),
                );
              },
              childCount: cart.items.length,
            ),
          ),
        ),

        // Order notes
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: _OrderNotesField(
              initialValue: cart.orderNotes ?? '',
              onChanged: cart.setOrderNotes,
            ),
          ),
        ),

        // Subtotal summary
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.lg, AppSpacing.md, 0),
            child: _CartSummaryCard(cart: cart),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _dismissBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.delete_outline_rounded,
              color: AppColors.error, size: 22),
          const SizedBox(height: 2),
          Text(
            'Remove',
            style: GoogleFonts.karla(
              fontSize: 11,
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size(80, 80),
              painter: _EmptyCartPainter(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Your cart is empty', style: AppTextStyles.headline(context),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text('Head back to the menu and add something delicious!',
                style: AppTextStyles.bodyMedium(context),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'BROWSE MENU',
              onPressed: () {
                if (widget.onBrowseMenu != null) {
                  widget.onBrowseMenu!();
                } else if (Navigator.of(context).canPop()) {
                  Navigator.pop(context);
                }
              },
              isSmall: true,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bottom bar ────────────────────────────────────────────────────────────
  Widget _buildBottomBar(BuildContext context, CartProvider cart) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BusinessHoursBanner(compact: true),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total (${cart.totalItemCount})',
                      style: AppTextStyles.label(context)
                          .copyWith(color: AppColors.textMuted)),
                  Text(
                    '₱${cart.totalAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.playfairDisplaySc(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: 180,
                child: PrimaryButton(
                  label: 'CHECKOUT',
                  onPressed: cart.isLoading ? null : () => _handleProceed(context),
                  isLoading: cart.isLoading,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Delivery fee calculated at checkout',
            style: AppTextStyles.caption(context),
          ),
        ],
      ),
    );
  }

  void _showClearConfirm(BuildContext context, CartProvider cart) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Clear cart?', style: AppTextStyles.headline(context)),
        content: Text('All items will be removed.',
            style: AppTextStyles.bodyMedium(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTextStyles.bodyMedium(context)),
          ),
          TextButton(
            onPressed: () {
              cart.clearCart();
              Navigator.pop(context);
            },
            child: Text('Clear',
                style: GoogleFonts.karla(
                    color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─── Cart Item Row ─────────────────────────────────────────────────────────────
class _CartItemRow extends StatefulWidget {
  final CartItem item;
  final bool isUnavailable;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final void Function(String) onNoteChanged;

  const _CartItemRow({
    required this.item,
    required this.isUnavailable,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onNoteChanged,
  });

  @override
  State<_CartItemRow> createState() => _CartItemRowState();
}

class _CartItemRowState extends State<_CartItemRow> {
  bool _showNote = false;
  late TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.item.note ?? '');
    _showNote = widget.item.note != null && widget.item.note!.isNotEmpty;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: widget.isUnavailable ? 0.55 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: widget.isUnavailable
                ? AppColors.error.withOpacity(0.4)
                : AppColors.border,
            width: widget.isUnavailable ? 1.5 : 1,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Food thumbnail ──────────────────────────────────
                  FoodThumb(
                    url: widget.item.photoUrl,
                    size: 68,
                    isUnavailable: widget.isUnavailable,
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // ── Details ─────────────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.playfairDisplaySc(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                        if (widget.item.variantName != null) ...[
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withOpacity(0.12),
                              borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                              border: Border.all(
                                  color: AppColors.gold.withOpacity(0.35)),
                            ),
                            child: Text(
                              widget.item.variantName!,
                              style: GoogleFonts.karla(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 3),
                        Text(
                          '₱${widget.item.price.toStringAsFixed(2)} each',
                          style: GoogleFonts.karla(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        if (widget.isUnavailable) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                              border: Border.all(
                                  color: AppColors.error.withOpacity(0.3)),
                            ),
                            child: Text(
                              'Sold out — remove to proceed',
                              style: GoogleFonts.karla(
                                  fontSize: 10,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            _QuantityControl(
                              quantity: widget.item.quantity,
                              onIncrement: widget.onIncrement,
                              onDecrement: widget.onDecrement,
                              onRemove: widget.onRemove,
                            ),
                            const Spacer(),
                            Text(
                              '₱${widget.item.subtotal.toStringAsFixed(2)}',
                              style: GoogleFonts.playfairDisplaySc(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
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

            // Note toggle + field
            Padding(
              padding:
              const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _showNote = !_showNote),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomPaint(
                          size: const Size(12, 12),
                          painter: _PencilPainter(
                              color: AppColors.gold.withOpacity(0.7)),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _showNote ? 'Hide note' : 'Add note',
                          style: GoogleFonts.karla(
                            fontSize: 12,
                            color: AppColors.gold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_showNote) ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _noteCtrl,
                      maxLines: 2,
                      maxLength: 120,
                      style: GoogleFonts.karla(
                          fontSize: 13, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'e.g. Less chili, extra sauce…',
                        hintStyle: GoogleFonts.karla(
                            fontSize: 12, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.inputFill,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: const BorderSide(
                              color: AppColors.inputBorder, width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide: const BorderSide(
                              color: AppColors.inputBorder, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          borderSide:
                          const BorderSide(color: AppColors.gold, width: 1.5),
                        ),
                        counterStyle: GoogleFonts.karla(
                            fontSize: 10, color: AppColors.textMuted),
                      ),
                      onChanged: widget.onNoteChanged,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quantity Control ──────────────────────────────────────────────────────────
class _QuantityControl extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _QuantityControl({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QBtn(
            icon: quantity <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
            color: quantity <= 1 ? AppColors.error : AppColors.textSecondary,
            onTap: quantity <= 1 ? onRemove : onDecrement,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '$quantity',
              style: GoogleFonts.playfairDisplaySc(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _QBtn(
            icon: Icons.add_rounded,
            color: AppColors.primary,
            onTap: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _QBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ─── Order Notes Field ─────────────────────────────────────────────────────────
class _OrderNotesField extends StatelessWidget {
  final String initialValue;
  final void Function(String) onChanged;
  const _OrderNotesField(
      {required this.initialValue, required this.onChanged});

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
          Row(children: [
            CustomPaint(
                size: const Size(14, 14),
                painter: _PencilPainter(color: AppColors.gold)),
            const SizedBox(width: 6),
            Text('Order Notes (optional)',
                style: AppTextStyles.label(context)),
          ]),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            initialValue: initialValue,
            maxLines: 3,
            maxLength: 250,
            style: GoogleFonts.karla(
                fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Any special instructions for your whole order…',
              hintStyle:
              GoogleFonts.karla(fontSize: 13, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.inputFill,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide:
                const BorderSide(color: AppColors.inputBorder, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide:
                const BorderSide(color: AppColors.inputBorder, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide:
                const BorderSide(color: AppColors.gold, width: 1.5),
              ),
              counterStyle: GoogleFonts.karla(
                  fontSize: 10, color: AppColors.textMuted),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ─── Cart Summary Card ─────────────────────────────────────────────────────────
class _CartSummaryCard extends StatelessWidget {
  final CartProvider cart;
  const _CartSummaryCard({required this.cart});

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
        children: [
          // Decorative divider top
          const ChineseDivider(),
          const SizedBox(height: AppSpacing.md),

          _SummaryRow(
            label: 'Items (${cart.totalItemCount})',
            value: '₱${cart.subtotal.toStringAsFixed(2)}',
          ),
          const SizedBox(height: AppSpacing.sm),
          if (cart.ridersAvailable) ...[
            const SizedBox(height: AppSpacing.sm),
            _SummaryRow(
              label: 'Delivery Fee',
            value: '₱${cart.deliveryFee.toStringAsFixed(2)}',
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const Divider(color: AppColors.border, thickness: 1),
          const SizedBox(height: AppSpacing.sm),
          _SummaryRow(
            label: 'Total',
            value: '₱${cart.totalAmount.toStringAsFixed(2)}',
            isBold: true,
          ),
          const SizedBox(height: AppSpacing.md),
          const ChineseDivider(),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final TextStyle? valueStyle;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isBold
              ? AppTextStyles.label(context)
              .copyWith(color: AppColors.textPrimary, fontSize: 14)
              : AppTextStyles.bodyMedium(context),
        ),
        Text(
          value,
          style: valueStyle ??
              (isBold
                  ? GoogleFonts.playfairDisplaySc(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)
                  : GoogleFonts.karla(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ),
      ],
    );
  }
}

// ─── Custom Painters ───────────────────────────────────────────────────────────

class _EmptyCartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = AppColors.gold.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Cart outline
    final path = Path()
      ..moveTo(size.width * 0.05, size.height * 0.08)
      ..lineTo(size.width * 0.22, size.height * 0.08)
      ..lineTo(size.width * 0.35, size.height * 0.65)
      ..lineTo(size.width * 0.85, size.height * 0.65)
      ..lineTo(size.width * 0.95, size.height * 0.25)
      ..lineTo(size.width * 0.28, size.height * 0.25);
    canvas.drawPath(path, stroke);

    // Wheels
    final dot = Paint()
      ..color = AppColors.gold.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        Offset(size.width * 0.4, size.height * 0.82), size.width * 0.07, dot);
    canvas.drawCircle(
        Offset(size.width * 0.75, size.height * 0.82), size.width * 0.07, dot);

    // X mark
    final xPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * 0.47, size.height * 0.33),
        Offset(size.width * 0.73, size.height * 0.57), xPaint);
    canvas.drawLine(Offset(size.width * 0.73, size.height * 0.33),
        Offset(size.width * 0.47, size.height * 0.57), xPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PencilPainter extends CustomPainter {
  final Color color;
  const _PencilPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.15, size.height * 0.85)
      ..lineTo(size.width * 0.7, size.height * 0.3)
      ..lineTo(size.width * 0.85, size.height * 0.15)
      ..lineTo(size.width, 0)
      ..moveTo(size.width * 0.85, size.height * 0.15)
      ..lineTo(size.width, size.height * 0.15)
      ..lineTo(size.width, 0)
      ..moveTo(size.width * 0.15, size.height * 0.85)
      ..lineTo(0, size.height)
      ..lineTo(size.width * 0.2, size.height)
      ..lineTo(size.width * 0.15, size.height * 0.85);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}