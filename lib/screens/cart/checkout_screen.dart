import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/cart_models.dart';
import '../../services/cart_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
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

    // Start at delivery step
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().goToStep(CheckoutStep.delivery);
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        // Show full-screen placing overlay
        if (cart.step == CheckoutStep.placing) {
          return const _PlacingOrderScreen();
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                children: [
                  _buildHeader(context, cart),
                  _buildStepIndicator(context, cart),
                  Expanded(
                    child: _buildStepBody(context, cart),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, CartProvider cart) {
    final isConfirmation = cart.step == CheckoutStep.confirmation;

    return Container(
      color: AppColors.primaryDark,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      child: Row(
        children: [
          if (!isConfirmation)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              color: AppColors.textOnDark,
              onPressed: () {
                if (cart.step == CheckoutStep.delivery) {
                  Navigator.pop(context);
                } else {
                  cart.goBack();
                }
              },
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Text(
              _headerTitle(cart.step),
              style: GoogleFonts.playfairDisplaySc(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textOnDark,
              ),
            ),
          ),
          const ChineseCornerDecoration(size: 28, flipH: true),
        ],
      ),
    );
  }

  String _headerTitle(CheckoutStep step) {
    switch (step) {
      case CheckoutStep.delivery:
        return 'Delivery';
      case CheckoutStep.payment:
        return 'Payment';
      case CheckoutStep.confirmation:
        return 'Order Placed!';
      default:
        return 'Checkout';
    }
  }

  // ─── Step indicator ────────────────────────────────────────────────────────
  Widget _buildStepIndicator(BuildContext context, CartProvider cart) {
    if (cart.step == CheckoutStep.confirmation) return const SizedBox.shrink();

    const steps = ['Delivery', 'Payment', 'Done'];
    final currentIdx = cart.step == CheckoutStep.delivery
        ? 0
        : cart.step == CheckoutStep.payment
        ? 1
        : 2;

    return Container(
      color: AppColors.primaryDark,
      padding:
      const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            // connector
            final leftDone = (i ~/ 2) < currentIdx;
            return Expanded(
              child: Container(
                height: 2,
                color: leftDone
                    ? AppColors.gold
                    : AppColors.textOnDark.withOpacity(0.2),
              ),
            );
          }
          final stepIdx = i ~/ 2;
          final isDone = stepIdx < currentIdx;
          final isActive = stepIdx == currentIdx;

          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? AppColors.gold
                      : isActive
                      ? AppColors.textOnDark
                      : Colors.transparent,
                  border: Border.all(
                    color: isDone || isActive
                        ? AppColors.gold
                        : AppColors.textOnDark.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check_rounded,
                      size: 14, color: AppColors.primaryDark)
                      : Text(
                    '${stepIdx + 1}',
                    style: GoogleFonts.karla(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? AppColors.primaryDark
                          : AppColors.textOnDark.withOpacity(0.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[stepIdx],
                style: GoogleFonts.karla(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isDone || isActive
                      ? AppColors.gold
                      : AppColors.textOnDark.withOpacity(0.4),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ─── Step body ─────────────────────────────────────────────────────────────
  Widget _buildStepBody(BuildContext context, CartProvider cart) {
    switch (cart.step) {
      case CheckoutStep.delivery:
        return _DeliveryStep(cart: cart);
      case CheckoutStep.payment:
        return _PaymentStep(cart: cart);
      case CheckoutStep.confirmation:
        return _ConfirmationStep(cart: cart);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── Step 1: Delivery Preference ──────────────────────────────────────────────
class _DeliveryStep extends StatelessWidget {
  final CartProvider cart;
  const _DeliveryStep({required this.cart});

  @override
  Widget build(BuildContext context) {
    final profile = cart.profile;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Deliver to
                if (profile != null) ...[
                  Text('Deliver to', style: AppTextStyles.label(context)),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppShadows.card,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: CustomPaint(
                            size: const Size(18, 18),
                            painter: _PinPainter(),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(profile.displayName,
                                  style: GoogleFonts.karla(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary)),
                              if (profile.address != null) ...[
                                const SizedBox(height: 2),
                                Text(profile.address!,
                                    style: AppTextStyles.bodySmall(context),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],

                Text('How should we deliver?',
                    style: AppTextStyles.label(context)),
                const SizedBox(height: AppSpacing.sm),

                _DeliveryOption(
                  pref: DeliveryPreference.ownDelivery,
                  selected: cart.deliveryPreference,
                  onTap: () =>
                      cart.setDeliveryPreference(DeliveryPreference.ownDelivery),
                ),
                const SizedBox(height: AppSpacing.sm),
                _DeliveryOption(
                  pref: DeliveryPreference.lalamove,
                  selected: cart.deliveryPreference,
                  onTap: () =>
                      cart.setDeliveryPreference(DeliveryPreference.lalamove),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Info note
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWarm,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomPaint(
                          size: const Size(14, 14),
                          painter: _InfoDotPainter()),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'This is a delivery request. Our staff will confirm and assign a rider once your order is prepared.',
                          style: GoogleFonts.karla(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // CTA
        _CheckoutBottomBar(
          cart: cart,
          label: 'CONTINUE TO PAYMENT',
          onPressed: () => cart.goToStep(CheckoutStep.payment),
        ),
      ],
    );
  }
}

class _DeliveryOption extends StatelessWidget {
  final DeliveryPreference pref;
  final DeliveryPreference selected;
  final VoidCallback onTap;

  const _DeliveryOption({
    required this.pref,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = pref == selected;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.05) : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            // Radio dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
                color: isSelected ? AppColors.primary : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                  size: 13, color: AppColors.textOnDark)
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pref.label,
                    style: GoogleFonts.karla(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(pref.description,
                      style: AppTextStyles.bodySmall(context)),
                ],
              ),
            ),
            // Icon
            CustomPaint(
              size: const Size(28, 28),
              painter: pref == DeliveryPreference.ownDelivery
                  ? _RiderPainter(isSelected: isSelected)
                  : _LalamovePainter(isSelected: isSelected),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step 2: Payment Method ────────────────────────────────────────────────────
class _PaymentStep extends StatelessWidget {
  final CartProvider cart;
  const _PaymentStep({required this.cart});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Error banner
                if (cart.error != CartError.none) ...[
                  StatusBanner(
                      message: cart.errorMessage ?? 'Something went wrong.',
                      isError: true),
                  const SizedBox(height: AppSpacing.md),
                ],

                Text('How will you pay?',
                    style: AppTextStyles.label(context)),
                const SizedBox(height: AppSpacing.sm),

                // GCash
                _PaymentOption(
                  method: PaymentMethod.gcash,
                  selected: cart.paymentMethod,
                  isDisabled: false,
                  onTap: () => cart.setPaymentMethod(PaymentMethod.gcash),
                ),
                const SizedBox(height: AppSpacing.sm),

                // COD — hidden if restricted
                if (cart.canUseCod) ...[
                  _PaymentOption(
                    method: PaymentMethod.cod,
                    selected: cart.paymentMethod,
                    isDisabled: false,
                    onTap: () => cart.setPaymentMethod(PaymentMethod.cod),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                          color: AppColors.error.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.block_rounded,
                            color: AppColors.error, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Cash on Delivery is unavailable for your account. Please use GCash.',
                            style: GoogleFonts.karla(
                                fontSize: 12,
                                color: AppColors.error,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),

                // Order summary
                _OrderSummaryCard(cart: cart),
              ],
            ),
          ),
        ),

        _CheckoutBottomBar(
          cart: cart,
          label: cart.paymentMethod == PaymentMethod.gcash
              ? 'PAY WITH GCASH'
              : 'PLACE ORDER (COD)',
          onPressed: () => cart.placeOrder(),
        ),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final PaymentMethod method;
  final PaymentMethod selected;
  final bool isDisabled;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.method,
    required this.selected,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = method == selected && !isDisabled;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isDisabled ? 0.4 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color:
            isSelected ? AppColors.primary.withOpacity(0.05) : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: 2,
                  ),
                  color: isSelected ? AppColors.primary : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded,
                    size: 13, color: AppColors.textOnDark)
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.label,
                      style: GoogleFonts.karla(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(method.description,
                        style: AppTextStyles.bodySmall(context)),
                  ],
                ),
              ),
              CustomPaint(
                size: const Size(32, 20),
                painter: method == PaymentMethod.gcash
                    ? _GCashBadgePainter(isSelected: isSelected)
                    : _CashBadgePainter(isSelected: isSelected),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Order Summary Card ────────────────────────────────────────────────────────
class _OrderSummaryCard extends StatelessWidget {
  final CartProvider cart;
  const _OrderSummaryCard({required this.cart});

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
                size: const Size(14, 14), painter: _LanternDotPainter()),
            const SizedBox(width: 6),
            Text('Order Summary', style: AppTextStyles.label(context)),
          ]),
          const SizedBox(height: AppSpacing.md),
          ...cart.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 28,
                  child: Text('${item.quantity}×',
                      style: GoogleFonts.karla(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                      )),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(item.name,
                      style: AppTextStyles.bodyMedium(context)
                          .copyWith(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                Text(
                  '₱${item.subtotal.toStringAsFixed(2)}',
                  style: GoogleFonts.karla(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
              ],
            ),
          )),
          const Divider(color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal',
                  style: AppTextStyles.label(context)
                      .copyWith(color: AppColors.textPrimary)),
              Text(
                '₱${cart.totalAmount.toStringAsFixed(2)}',
                style: GoogleFonts.playfairDisplaySc(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Step 3: Confirmation ─────────────────────────────────────────────────────
class _ConfirmationStep extends StatelessWidget {
  final CartProvider cart;
  const _ConfirmationStep({required this.cart});

  @override
  Widget build(BuildContext context) {
    final order = cart.lastOrder;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),

          // Success lanterns
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomPaint(
                  size: const Size(40, 56), painter: _ConfirmLantern(tilt: -0.15)),
              const SizedBox(width: 12),
              CustomPaint(
                  size: const Size(52, 72), painter: _ConfirmLantern(tilt: 0)),
              const SizedBox(width: 12),
              CustomPaint(
                  size: const Size(40, 56), painter: _ConfirmLantern(tilt: 0.15)),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          Text('Order placed!',
              style: AppTextStyles.display2(context),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your order is being prepared.\nWe\'ll notify you every step of the way.',
            style: AppTextStyles.bodyMedium(context),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.xl),

          // Order number card
          if (order != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.gold.withOpacity(0.4), width: 1.5),
                boxShadow: AppShadows.goldGlow,
              ),
              child: Column(
                children: [
                  const ChineseDivider(),
                  const SizedBox(height: AppSpacing.md),
                  Text('Order Number',
                      style: AppTextStyles.label(context)
                          .copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    order.orderNumber,
                    style: GoogleFonts.playfairDisplaySc(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const ChineseDivider(),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Payment note for GCash
            if (cart.paymentMethod == PaymentMethod.gcash && order.paymentUrl != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWarm,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CustomPaint(
                        size: const Size(14, 14),
                        painter: _InfoDotPainter()),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'You will be redirected to GCash to complete payment.',
                        style: GoogleFonts.karla(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: 'PAY NOW (GCASH)',
                onPressed: () {
                  // TODO: Launch PayMongo URL in webview/browser
                  // launch(order.paymentUrl!)
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],

          const SizedBox(height: AppSpacing.lg),

          PrimaryButton(
            label: 'TRACK MY ORDER',
            onPressed: () {
              // Clear cart and go to order tracking
              cart.clearCart();
              Navigator.popUntil(context, (route) => route.isFirst);
              // TODO: Navigate to order tracking screen (§1.6)
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          GoldOutlineButton(
            label: 'BACK TO MENU',
            onPressed: () {
              cart.clearCart();
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }
}

// ─── Placing Order overlay ─────────────────────────────────────────────────────
class _PlacingOrderScreen extends StatelessWidget {
  const _PlacingOrderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandCatIcon(size: 72),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Placing your order…',
              style: GoogleFonts.playfairDisplaySc(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textOnDark,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Hold on a moment',
              style: GoogleFonts.karla(
                fontSize: 13,
                color: AppColors.textOnDark.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const CircularProgressIndicator(
                color: AppColors.gold, strokeWidth: 2.5),
          ],
        ),
      ),
    );
  }
}

// ─── Checkout Bottom Bar ───────────────────────────────────────────────────────
class _CheckoutBottomBar extends StatelessWidget {
  final CartProvider cart;
  final String label;
  final VoidCallback onPressed;

  const _CheckoutBottomBar({
    required this.cart,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
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
              color: AppColors.shadow, blurRadius: 12, offset: const Offset(0, -4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order Total',
                      style: AppTextStyles.label(context)
                          .copyWith(color: AppColors.textMuted, fontSize: 11)),
                  Text(
                    '₱${cart.totalAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.playfairDisplaySc(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: 196,
                child: PrimaryButton(
                  label: label,
                  onPressed: cart.isLoading ? null : onPressed,
                  isLoading: cart.isLoading,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Custom Painters ───────────────────────────────────────────────────────────

class _PinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..addOval(Rect.fromLTWH(w * 0.1, 0, w * 0.8, h * 0.65))
      ..moveTo(w / 2, h * 0.65)
      ..lineTo(w * 0.35, h * 0.45)
      ..lineTo(w * 0.65, h * 0.45)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawOval(
        Rect.fromLTWH(w * 0.3, h * 0.15, w * 0.4, h * 0.35),
        Paint()
          ..color = AppColors.primaryDark
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InfoDotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.width / 2,
        Paint()
          ..color = AppColors.gold.withOpacity(0.5)
          ..style = PaintingStyle.fill);
    canvas.drawLine(
        Offset(size.width / 2, size.height * 0.3),
        Offset(size.width / 2, size.height * 0.75),
        Paint()
          ..color = AppColors.primaryDark
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LanternDotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(
        Rect.fromLTWH(0, size.height * 0.2, size.width, size.height * 0.6),
        Paint()
          ..color = AppColors.gold
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RiderPainter extends CustomPainter {
  final bool isSelected;
  const _RiderPainter({required this.isSelected});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color =
      isSelected ? AppColors.primary : AppColors.textMuted.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Simple bike icon
    canvas.drawCircle(Offset(size.width * 0.22, size.height * 0.65),
        size.width * 0.2, p);
    canvas.drawCircle(Offset(size.width * 0.78, size.height * 0.65),
        size.width * 0.2, p);
    final body = Path()
      ..moveTo(size.width * 0.22, size.height * 0.65)
      ..lineTo(size.width * 0.42, size.height * 0.28)
      ..lineTo(size.width * 0.65, size.height * 0.28)
      ..lineTo(size.width * 0.78, size.height * 0.65)
      ..moveTo(size.width * 0.5, size.height * 0.28)
      ..lineTo(size.width * 0.5, size.height * 0.12)
      ..lineTo(size.width * 0.62, size.height * 0.12);
    canvas.drawPath(body, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LalamovePainter extends CustomPainter {
  final bool isSelected;
  const _LalamovePainter({required this.isSelected});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color =
      isSelected ? AppColors.primary : AppColors.textMuted.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Simple van icon
    final van = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(
              0, size.height * 0.2, size.width * 0.75, size.height * 0.55),
          const Radius.circular(3)))
      ..moveTo(size.width * 0.75, size.height * 0.35)
      ..lineTo(size.width * 0.98, size.height * 0.45)
      ..lineTo(size.width * 0.98, size.height * 0.75)
      ..lineTo(size.width * 0.75, size.height * 0.75);
    canvas.drawPath(van, p);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.8),
        size.width * 0.09, p);
    canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.8),
        size.width * 0.09, p);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.8),
        size.width * 0.09, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GCashBadgePainter extends CustomPainter {
  final bool isSelected;
  const _GCashBadgePainter({required this.isSelected});
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color =
      isSelected ? AppColors.primary.withOpacity(0.15) : AppColors.border
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, size.width, size.height),
            const Radius.circular(4)),
        fill);
    final text = TextPainter(
      text: TextSpan(
        text: 'G',
        style: GoogleFonts.karla(
          fontSize: size.height * 0.7,
          fontWeight: FontWeight.w900,
          color: isSelected ? AppColors.primary : AppColors.textMuted,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas,
        Offset((size.width - text.width) / 2, (size.height - text.height) / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CashBadgePainter extends CustomPainter {
  final bool isSelected;
  const _CashBadgePainter({required this.isSelected});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color =
      isSelected ? AppColors.primary : AppColors.textMuted.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(
                size.width * 0.05, size.height * 0.15, size.width * 0.9, size.height * 0.7),
            const Radius.circular(3)),
        p);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2),
        size.width * 0.18, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ConfirmLantern extends CustomPainter {
  final double tilt;
  const _ConfirmLantern({required this.tilt});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(tilt);
    canvas.translate(-size.width / 2, -size.height / 2);

    final gFill = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.fill;
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
            Rect.fromLTWH(w * 0.15, h * 0.06, w * 0.7, h * 0.08),
            const Radius.circular(2)),
        gFill);

    final body = Path()
      ..moveTo(w * 0.05, h * 0.16)
      ..quadraticBezierTo(0, h * 0.5, w * 0.05, h * 0.76)
      ..lineTo(w * 0.95, h * 0.76)
      ..quadraticBezierTo(w, h * 0.5, w * 0.95, h * 0.16)
      ..close();
    canvas.drawPath(body, mFill);
    canvas.drawPath(body, stroke);

    // Glow dot
    canvas.drawCircle(Offset(w / 2, h * 0.46), w * 0.08,
        Paint()..color = AppColors.goldLight.withOpacity(0.4));

    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.15, h * 0.74, w * 0.7, h * 0.08),
            const Radius.circular(2)),
        gFill);

    // Tassel
    for (int i = 0; i < 4; i++) {
      final x = w * 0.22 + i * w * 0.19;
      canvas.drawLine(Offset(x, h * 0.82),
          Offset(x + (i.isOdd ? 3 : -3), h), stroke..strokeWidth = 1);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}