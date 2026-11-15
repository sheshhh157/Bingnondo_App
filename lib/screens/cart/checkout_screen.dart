/**
 * checkout_screen.dart  —  §1.5 Cart & Checkout
 * ─────────────────────────────────────────────────────────────
 * Steps: Payment → GCash Detail / COD Detail → (placing overlay) → Confirmation
 *
 * GCash flow:
 *   1. Customer picks GCash on Payment Selection screen
 *   2. GCash Detail screen: shows QR code + upload receipt section
 *      • Upload screenshot → OCR → ref extracted
 *      • Order summary shown
 *      • "Confirm & Place Order" button
 *   3. Placing overlay
 *   4. Confirmation screen
 *
 * COD flow:
 *   1. Customer picks COD on Payment Selection screen
 *   2. COD Detail screen: shows order list + total
 *   3. "Place Order (COD)" button
 *   4. Placing overlay
 *   5. Confirmation screen
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/cart_models.dart';
import '../../models/geo_models.dart';
import '../../services/address_history_service.dart';
import '../../services/cart_provider.dart';
import '../../services/cart_service.dart';
import '../../services/business_hours_provider.dart';
import '../../services/camera_permission_service.dart';
import '../../services/orders_provider.dart';
import '../../services/gcash_receipt_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/business_hours_banner.dart';
import '../address/address_picker_screen.dart';
import '../orders/my_orders_screen.dart';

// ── Internal sub-step enum (within the payment step) ─────────────────────────
enum _PaymentSubStep { selection, gcashDetail, codDetail }

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double>   _fade;

  _PaymentSubStep _subStep = _PaymentSubStep.selection;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().goToStep(CheckoutStep.payment);
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _goToSubStep(_PaymentSubStep sub) {
    setState(() => _subStep = sub);
  }

  // Handle system back when in a detail sub-step
  Future<bool> _onWillPop() async {
    if (_subStep != _PaymentSubStep.selection) {
      setState(() => _subStep = _PaymentSubStep.selection);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        if (cart.step == CheckoutStep.placing) {
          return const _PlacingOrderScreen();
        }

        return WillPopScope(
          onWillPop: _onWillPop,
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: FadeTransition(
                opacity: _fade,
                child: Column(
                  children: [
                    if (cart.step != CheckoutStep.confirmation)
                      _buildTopBar(context, cart),
                    Expanded(child: _buildBody(context, cart)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context, CartProvider cart) {
    String subtitle;
    switch (_subStep) {
      case _PaymentSubStep.gcashDetail:
        subtitle = 'GCash payment details';
        break;
      case _PaymentSubStep.codDetail:
        subtitle = 'Cash on Delivery details';
        break;
      default:
        subtitle = 'Choose your payment method';
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius:
        BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.md),
      child: Column(
        children: [
          Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              color: AppColors.textOnDark,
              onPressed: () {
                if (_subStep != _PaymentSubStep.selection) {
                  setState(() => _subStep = _PaymentSubStep.selection);
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Checkout',
                    style: GoogleFonts.playfairDisplaySc(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textOnDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.karla(
                      fontSize: 12,
                      color: AppColors.textOnDark.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 48),
          ]),
          const SizedBox(height: AppSpacing.md),
          _buildStepIndicator(cart),
        ],
      ),
    );
  }

  // ─── Step indicator ────────────────────────────────────────────────────────
  Widget _buildStepIndicator(CartProvider cart) {
    final steps     = ['Payment', 'Details', 'Done'];
    int currentIdx;
    if (cart.step == CheckoutStep.confirmation) {
      currentIdx = 2;
    } else if (_subStep != _PaymentSubStep.selection) {
      currentIdx = 1;
    } else {
      currentIdx = 0;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Padding(
            padding: const EdgeInsets.only(top: 13, left: 10, right: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 36,
              height: 2,
              decoration: BoxDecoration(
                color: (i ~/ 2) < currentIdx
                    ? AppColors.gold
                    : AppColors.textOnDark.withOpacity(0.2),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          );
        }
        final idx      = i ~/ 2;
        final isDone   = idx < currentIdx;
        final isActive = idx == currentIdx;
        return Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 28, height: 28,
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
                  : Text('${idx + 1}',
                  style: GoogleFonts.karla(
                    fontSize:   12,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? AppColors.primaryDark
                        : AppColors.textOnDark.withOpacity(0.4),
                  )),
            ),
          ),
          const SizedBox(height: 4),
          Text(steps[idx],
              style: GoogleFonts.karla(
                fontSize:   10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: isDone || isActive
                    ? AppColors.gold
                    : AppColors.textOnDark.withOpacity(0.4),
              )),
        ]);
      }),
    );
  }

  // ─── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody(BuildContext context, CartProvider cart) {
    switch (cart.step) {
      case CheckoutStep.payment:
        switch (_subStep) {
          case _PaymentSubStep.selection:
            return _PaymentSelectionStep(
              cart:         cart,
              onGcashTap:   () => _goToSubStep(_PaymentSubStep.gcashDetail),
              onCodTap:     () => _goToSubStep(_PaymentSubStep.codDetail),
            );
          case _PaymentSubStep.gcashDetail:
            return _GcashDetailStep(cart: cart);
          case _PaymentSubStep.codDetail:
            return _CodDetailStep(cart: cart);
        }
      case CheckoutStep.confirmation:
        return _ConfirmationStep(cart: cart);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Step 1 — Payment Method Selection
// ══════════════════════════════════════════════════════════════════════════════
class _PaymentSelectionStep extends StatefulWidget {
  final CartProvider cart;
  final VoidCallback onGcashTap;
  final VoidCallback onCodTap;

  const _PaymentSelectionStep({
    required this.cart,
    required this.onGcashTap,
    required this.onCodTap,
  });

  @override
  State<_PaymentSelectionStep> createState() => _PaymentSelectionStepState();
}

class _PaymentSelectionStepState extends State<_PaymentSelectionStep> {
  CartProvider get cart => widget.cart;

  // ── Confirm address before proceeding to payment detail ─────────────────
  Future<void> _confirmAndProceed({
    required PaymentMethod method,
    required VoidCallback onConfirmed,
  }) async {
    if (!cart.ridersAvailable) {
      cart.setPaymentMethod(method);
      onConfirmed();
      return;
    }

    final address = cart.deliveryAddress!.address;
    final methodLabel = method == PaymentMethod.gcash ? 'GCash' : 'Cash on Delivery';

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // Title
            Text(
              'Confirm Delivery Address',
              style: GoogleFonts.playfairDisplaySc(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your order will be delivered to this address.',
              style: GoogleFonts.karla(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Address card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                boxShadow: AppShadows.card,
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on_rounded,
                      color: AppColors.gold, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    address,
                    style: GoogleFonts.karla(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: AppSpacing.md),

            // Payment method reminder
            Row(children: [
              const Icon(Icons.info_outline_rounded,
                  size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                'Payment via $methodLabel',
                style: GoogleFonts.karla(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.lg),

            // Buttons
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    Navigator.pop(ctx, false);
                    await _changeAddress(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Change',
                      style: GoogleFonts.karla(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Confirm & Continue',
                      style: GoogleFonts.karla(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      cart.setPaymentMethod(method);
      onConfirmed();
    }
  }

  // ── Open the address picker (map), then save to history ──────────────────
  Future<void> _openMapPicker() async {
    final picked = await Navigator.push<PickedAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressPickerScreen(initial: cart.deliveryAddress),
      ),
    );
    if (picked != null && !picked.isEmpty) {
      cart.setDeliveryAddress(picked);
      await AddressHistoryService.add(picked);
    }
  }

  // ── Show address history bottom sheet ────────────────────────────────────
  Future<void> _changeAddress(BuildContext context) async {
    final history = await AddressHistoryService.load();

    if (!mounted) return;

    // If no history yet, go straight to the map picker
    if (history.isEmpty) {
      await _openMapPicker();
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddressHistorySheet(
        history: history,
        onSelect: (picked) async {
          Navigator.pop(ctx);
          cart.setDeliveryAddress(picked);
          // Bubble selected address to top of history
          await AddressHistoryService.add(picked);
        },
        onAddNew: () async {
          Navigator.pop(ctx);
          await _openMapPicker();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Kapag walang rider (pickup only), hindi na required ang delivery address —
    // ang checkout ay proceed nang walang address field.
    final hasAddress = !cart.ridersAvailable ||
        (cart.deliveryAddress != null && !cart.deliveryAddress!.isEmpty);

    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Deliver to ────────────────────────────────────────────────
              // Itago kung walang rider — pickup lang, hindi na kailangan ng address.
              if (cart.profile != null && cart.ridersAvailable) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Deliver to', style: AppTextStyles.label(context)),
                    GestureDetector(
                      onTap: () => _changeAddress(context),
                      child: Text(
                        'CHANGE',
                        style: GoogleFonts.karla(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _DeliverToCard(
                  profile: cart.profile!,
                  address: cart.deliveryAddress?.address,
                  onTap:   () => _changeAddress(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                _SaveAddressToggle(
                  value:     cart.saveAddressToProfile,
                  onChanged: cart.setSaveAddressToProfile,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],

              // ── Error banner ──────────────────────────────────────────────
              if (cart.error != CartError.none) ...[
                _ErrorBanner(message: cart.errorMessage ?? 'Something went wrong.'),
                const SizedBox(height: AppSpacing.md),
              ],

              // ── Pickup-only notice (walang rider online) ──────────────────
              if (!cart.ridersAvailable) ...[
                const _PickupOnlyBanner(),
                const SizedBox(height: AppSpacing.md),
              ],

              // ── Payment method selection ───────────────────────────────────
              Row(
                children: [
                  Text('Select Payment Method',
                      style: AppTextStyles.label(context)),
                  if (!hasAddress) ...[
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(Icons.lock_rounded,
                        size: 14, color: AppColors.textMuted),
                  ],
                ],
              ),
              if (!hasAddress) ...[
                const SizedBox(height: 4),
                Text(
                  'Please select a delivery address first.',
                  style: GoogleFonts.karla(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),

              // GCash option
              _PaymentMethodCard(
                icon:        Icons.account_balance_wallet_rounded,
                tint:        const Color(0xFF1E88E5),
                title:       'GCash',
                description: 'Pay via GCash e-wallet',
                badge:       'QR PAYMENT',
                badgeColor:  const Color(0xFF1E88E5),
                disabled:    !hasAddress,
                onTap: !hasAddress ? null : () => _confirmAndProceed(
                  method:      PaymentMethod.gcash,
                  onConfirmed: widget.onGcashTap,
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // COD option
              if (cart.canUseCod)
                _PaymentMethodCard(
                  icon:        Icons.payments_rounded,
                  tint:        AppColors.success,
                  title:       'Cash on Delivery',
                  description: 'Pay when your order arrives',
                  badge:       'COD',
                  badgeColor:  AppColors.success,
                  disabled:    !hasAddress,
                  onTap: !hasAddress ? null : () => _confirmAndProceed(
                    method:      PaymentMethod.cod,
                    onConfirmed: widget.onCodTap,
                  ),
                )
              else
                _CodRestrictedBanner(),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    ]);
  }
}

// ── Address History Bottom Sheet ──────────────────────────────────────────────
class _AddressHistorySheet extends StatelessWidget {
  final List<PickedAddress>      history;
  final ValueChanged<PickedAddress> onSelect;
  final VoidCallback             onAddNew;

  const _AddressHistorySheet({
    required this.history,
    required this.onSelect,
    required this.onAddNew,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 4, AppSpacing.lg, AppSpacing.sm),
            child: Text(
              'Recent Addresses',
              style: GoogleFonts.playfairDisplaySc(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 0.4,
              ),
            ),
          ),

          // History list
          ...history.map((addr) => ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: 2),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_rounded,
                  color: AppColors.gold, size: 18),
            ),
            title: Text(
              addr.address,
              style: GoogleFonts.karla(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 20),
            onTap: () => onSelect(addr),
          )),

          const Divider(height: 1, indent: AppSpacing.lg, endIndent: AppSpacing.lg),
          const SizedBox(height: AppSpacing.sm),

          // Add new address button
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: 2),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_location_alt_rounded,
                  color: AppColors.primary, size: 18),
            ),
            title: Text(
              'Add a new address',
              style: GoogleFonts.karla(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            onTap: onAddNew,
          ),

          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

// ── Big tappable payment method card ─────────────────────────────────────────
class _PaymentMethodCard extends StatelessWidget {
  final IconData      icon;
  final Color         tint;
  final String        title;
  final String        description;
  final String        badge;
  final Color         badgeColor;
  final VoidCallback? onTap;
  final bool          disabled;

  const _PaymentMethodCard({
    required this.icon,
    required this.tint,
    required this.title,
    required this.description,
    required this.badge,
    required this.badgeColor,
    this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color:        AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border:       Border.all(color: AppColors.border),
            boxShadow:    disabled ? null : AppShadows.card,
          ),
          child: Row(children: [
            // Icon
            Container(
              width: 52, height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:        tint.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border:       Border.all(color: tint.withOpacity(0.25)),
              ),
              child: Icon(icon, color: tint, size: 26),
            ),
            const SizedBox(width: AppSpacing.md),

            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(title,
                        style: GoogleFonts.karla(
                            fontSize:   15,
                            fontWeight: FontWeight.w700,
                            color:      AppColors.textPrimary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:        badgeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                        border:       Border.all(
                            color: badgeColor.withOpacity(0.3)),
                      ),
                      child: Text(badge,
                          style: GoogleFonts.karla(
                              fontSize:      9,
                              fontWeight:    FontWeight.w800,
                              color:         badgeColor,
                              letterSpacing: 0.5)),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text(description,
                      style: AppTextStyles.bodySmall(context)),
                ],
              ),
            ),

            // Chevron or lock
            Icon(
              disabled
                  ? Icons.lock_rounded
                  : Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Step 2a — GCash Detail Screen
// ══════════════════════════════════════════════════════════════════════════════
class _GcashDetailStep extends StatefulWidget {
  final CartProvider cart;
  const _GcashDetailStep({required this.cart});

  @override
  State<_GcashDetailStep> createState() => _GcashDetailStepState();
}

class _GcashDetailStepState extends State<_GcashDetailStep> {
  File?   _pickedImage;
  String? _imageMime;
  bool    _isExtracting = false;
  String? _extractError;

  final _picker = ImagePicker();

  CartProvider get cart => widget.cart;

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera && !await requestCameraAccess(context)) {
      return;
    }
    final picked = await _picker.pickImage(
      source:       source,
      imageQuality: 85,
      maxWidth:     1600,
    );
    if (picked == null) return;

    setState(() {
      _pickedImage  = File(picked.path);
      _imageMime    = picked.path.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
      _extractError = null;
    });

    cart.clearGcashReceipt();
  }

  void _showImageSourceSheet() {
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
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded,
                color: AppColors.primary),
            title: Text('Take a Photo',
                style: GoogleFonts.karla(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _extractReceipt() async {
    if (_pickedImage == null) return;

    setState(() {
      _isExtracting = true;
      _extractError = null;
    });

    try {
      final result = await GcashReceiptService.instance.extractReceipt(
        imageFile: _pickedImage!,
        mimeType:  _imageMime ?? 'image/jpeg',
      );
      cart.setGcashExtractResult(result);
    } on GcashExtractException catch (e) {
      setState(() => _extractError = e.message);
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final extractResult = cart.gcashExtractResult;
    final receiptReady  = cart.gcashReceiptReady;

    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── QR Code card ──────────────────────────────────────────────
              _GcashQrCard(),
              const SizedBox(height: AppSpacing.xl),

              // ── Upload receipt ─────────────────────────────────────────────
              Text('Upload GCash Receipt', style: AppTextStyles.label(context)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'After sending payment, upload a screenshot of your GCash receipt.',
                style: AppTextStyles.bodySmall(context),
              ),
              const SizedBox(height: AppSpacing.md),

              _ReceiptPickerCard(
                pickedImage:   _pickedImage,
                isExtracting:  _isExtracting,
                extractError:  _extractError,
                extractResult: extractResult,
                onPickTap:     _showImageSourceSheet,
                onExtractTap:  _pickedImage != null &&
                    !_isExtracting &&
                    extractResult == null
                    ? _extractReceipt
                    : null,
                onReuploadTap: extractResult != null
                    ? () {
                  cart.clearGcashReceipt();
                  setState(() {
                    _pickedImage  = null;
                    _extractError = null;
                  });
                }
                    : null,
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Order summary ─────────────────────────────────────────────
              Text('Order Summary', style: AppTextStyles.label(context)),
              const SizedBox(height: AppSpacing.sm),
              _OrderSummaryCard(cart: cart, extractResult: extractResult),

              const SizedBox(height: AppSpacing.md),

              // ── Error ──────────────────────────────────────────────────────
              if (cart.error != CartError.none) ...[
                _ErrorBanner(
                    message: cart.errorMessage ?? 'Something went wrong.'),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
      ),

      // ── Bottom bar ────────────────────────────────────────────────────────
      _CheckoutBottomBar(
        cart:      cart,
        isEnabled: receiptReady && !cart.isLoading,
        isLoading: cart.isLoading,
        label:     extractResult != null
            ? 'CONFIRM & PLACE ORDER'
            : 'UPLOAD RECEIPT FIRST',
        onPressed: () async {
          final res = await cart.placeOrder();
          if (res != null && context.mounted) {
            context.read<OrdersProvider>().loadOrders();
          }
        },
      ),
    ]);
  }
}

// ── GCash QR Code card ────────────────────────────────────────────────────────
// ── _GcashQrCard — fetches QR code from GET /api/payments/qr-code ─────────────
class _GcashQrCard extends StatefulWidget {
  @override
  State<_GcashQrCard> createState() => _GcashQrCardState();
}

class _GcashQrCardState extends State<_GcashQrCard> {
  bool    _loading   = true;
  bool    _saving    = false;
  String? _imageUrl;
  String  _name      = 'Bingnondo Cafe';
  String  _number    = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchQrCode();
  }

  Future<void> _fetchQrCode() async {
    try {
      final data = await CartService.instance.fetchActiveQrCode();
      if (mounted) {
        setState(() {
          _imageUrl = data['image_url'] as String?;
          _name     = (data['name']   as String?) ?? 'Bingnondo Cafe';
          _number   = (data['number'] as String?) ?? '';
          _loading  = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error   = e.toString();
        });
      }
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }

  /// Copies the GCash account number to the clipboard.
  Future<void> _copyNumber() async {
    if (_number.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _number));
    if (mounted) _showMessage('GCash number copied: $_number');
  }

  /// Downloads the admin-uploaded QR image and saves it to the phone gallery.
  Future<void> _saveQr() async {
    final url = _imageUrl;
    if (url == null || url.isEmpty || _saving) return;

    setState(() => _saving = true);
    File? tempFile;
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          if (mounted) {
            _showMessage('Please allow photo access to save the QR code.');
          }
          return;
        }
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('QR image download failed (${response.statusCode}).');
      }

      // Write to a temp .jpg file first. Saving from a path lets the plugin
      // use the file extension instead of guessing the format from bytes,
      // which is what makes putImageBytes fail on some devices.
      tempFile = File(
        '${Directory.systemTemp.path}/bingnondo_gcash_qr_'
        '${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(response.bodyBytes, flush: true);

      await Gal.putImage(tempFile.path);
      if (mounted) _showMessage('QR code saved to your gallery.');
    } on GalException catch (e) {
      debugPrint('[SaveQR] GalException (${e.type.code}): ${e.type.message}');
      if (mounted) _showMessage('Could not save QR code: ${e.type.message}');
    } catch (e, stack) {
      debugPrint('[SaveQR] Failed: $e\n$stack');
      if (mounted) {
        _showMessage('Could not save QR code: $e');
      }
    } finally {
      if (tempFile != null) {
        try {
          if (await tempFile.exists()) await tempFile.delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _saving = false);
    }
  }

  ButtonStyle get _actionStyle => OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1E88E5),
        side: BorderSide(color: const Color(0xFF1E88E5).withOpacity(0.45)),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: GoogleFonts.karla(
            fontSize: 12, fontWeight: FontWeight.w700),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width:      double.infinity,
      padding:    const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [
            const Color(0xFF1E88E5).withOpacity(0.08),
            const Color(0xFF1565C0).withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: const Color(0xFF1E88E5).withOpacity(0.3), width: 1.5),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(children: [
            Container(
              padding:    const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color:  const Color(0xFF1E88E5).withOpacity(0.12),
                shape:  BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF1E88E5).withOpacity(0.3)),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  color: Color(0xFF1E88E5), size: 16),
            ),
            const SizedBox(width: 8),
            Text('GCash Payment',
                style: GoogleFonts.karla(
                    fontSize:   14,
                    fontWeight: FontWeight.w800,
                    color:      const Color(0xFF1E88E5))),
          ]),

          const SizedBox(height: AppSpacing.md),

          // ── QR image ─────────────────────────────────────────────────────
          Container(
            width:   200,
            height:  200,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                  color: const Color(0xFF1E88E5).withOpacity(0.4), width: 2),
              boxShadow: [
                BoxShadow(
                    color:      Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset:     const Offset(0, 2)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: _buildQrImage(),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Account name + number ────────────────────────────────────────
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                  color: const Color(0xFF1E88E5).withOpacity(0.2)),
            ),
            child: Column(children: [
              Text(_name,
                  style: GoogleFonts.karla(
                      fontSize:   15,
                      fontWeight: FontWeight.w800,
                      color:      AppColors.textPrimary)),
              if (_number.isNotEmpty) ...[
                const SizedBox(height: 2),
                InkWell(
                  onTap: _copyNumber,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_number,
                            style: GoogleFonts.karla(
                                fontSize: 13,
                                color:    AppColors.textSecondary)),
                        const SizedBox(width: 6),
                        const Icon(Icons.copy_rounded,
                            size: 14, color: Color(0xFF1E88E5)),
                      ],
                    ),
                  ),
                ),
              ],
            ]),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Save QR / copy number actions ────────────────────────────────
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (_imageUrl != null &&
                        _imageUrl!.isNotEmpty &&
                        !_saving)
                    ? _saveQr
                    : null,
                icon: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_rounded, size: 16),
                label: Text(_saving ? 'Saving...' : 'Save QR'),
                style: _actionStyle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _number.isEmpty ? null : _copyNumber,
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy Number'),
                style: _actionStyle,
              ),
            ),
          ]),

          const SizedBox(height: AppSpacing.sm),

          Text(
            'Send the exact amount shown in your order total below.\nDelivery fee is already included.',
            textAlign: TextAlign.center,
            style: GoogleFonts.karla(
                fontSize: 11,
                color:    AppColors.textMuted,
                height:   1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildQrImage() {
    // Loading spinner
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    // Error or no QR configured — show icon fallback
    if (_error != null || _imageUrl == null || _imageUrl!.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2_rounded,
              size: 110, color: AppColors.primaryDark),
          const SizedBox(height: 6),
          Text('SCAN TO PAY',
              style: GoogleFonts.karla(
                  fontSize:      10,
                  fontWeight:    FontWeight.w800,
                  color:         AppColors.textMuted,
                  letterSpacing: 1.2)),
        ],
      );
    }

    // Live QR image from Cloudinary
    return Image.network(
      _imageUrl!,
      fit: BoxFit.contain,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      },
      errorBuilder: (_, __, ___) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2_rounded,
              size: 110, color: AppColors.primaryDark),
          const SizedBox(height: 6),
          Text('SCAN TO PAY',
              style: GoogleFonts.karla(
                  fontSize:      10,
                  fontWeight:    FontWeight.w800,
                  color:         AppColors.textMuted,
                  letterSpacing: 1.2)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Step 2b — COD Detail Screen
// ══════════════════════════════════════════════════════════════════════════════
class _CodDetailStep extends StatelessWidget {
  final CartProvider cart;
  const _CodDetailStep({required this.cart});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── COD info banner ───────────────────────────────────────────
              Container(
                padding:    const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color:        AppColors.success.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                      color: AppColors.success.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding:    const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.12),
                          shape: BoxShape.circle),
                      child: Icon(Icons.payments_rounded,
                          color: AppColors.success, size: 18),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cash on Delivery',
                              style: GoogleFonts.karla(
                                  fontSize:   14,
                                  fontWeight: FontWeight.w800,
                                  color:      AppColors.success)),
                          const SizedBox(height: 4),
                          Text(
                            'Please prepare the exact amount. '
                                'Our delivery rider will collect payment upon arrival.',
                            style: GoogleFonts.karla(
                                fontSize: 12,
                                color:    AppColors.textSecondary,
                                height:   1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Order list ────────────────────────────────────────────────
              Text('Your Order', style: AppTextStyles.label(context)),
              const SizedBox(height: AppSpacing.sm),

              Container(
                padding:    const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color:        AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border:       Border.all(color: AppColors.border),
                  boxShadow:    AppShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...cart.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Row(children: [
                        FoodThumb(
                            url: item.photoUrl, size: 44, radius: AppRadius.sm),
                        const SizedBox(width: AppSpacing.sm),
                        // Quantity badge
                        Container(
                          width: 28, height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color:        AppColors.gold.withOpacity(0.12),
                            shape:        BoxShape.circle,
                            border: Border.all(
                                color: AppColors.gold.withOpacity(0.4)),
                          ),
                          child: Text('${item.quantity}',
                              style: GoogleFonts.karla(
                                  fontSize:   12,
                                  fontWeight: FontWeight.w800,
                                  color:      AppColors.gold)),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name,
                                  style: AppTextStyles.bodyMedium(context)
                                      .copyWith(fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              Text('₱${item.price.toStringAsFixed(2)} each',
                                  style: AppTextStyles.bodySmall(context)),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text('₱${item.subtotal.toStringAsFixed(2)}',
                            style: GoogleFonts.karla(
                                fontSize:   14,
                                fontWeight: FontWeight.w700,
                                color:      AppColors.textPrimary)),
                      ]),
                    )),

                    const Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: AppSpacing.md),

                    // ── Subtotal row ──────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal',
                            style: GoogleFonts.karla(
                                fontSize: 13,
                                color:    AppColors.textSecondary)),
                        Text('₱${cart.subtotal.toStringAsFixed(2)}',
                            style: GoogleFonts.karla(
                                fontSize:   13,
                                fontWeight: FontWeight.w600,
                                color:      AppColors.textPrimary)),
                      ],
                    ),
                    if (cart.ridersAvailable) ...[
                      const SizedBox(height: 6),
                      // ── Delivery fee row ────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            const Icon(Icons.delivery_dining_rounded,
                                size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text('Delivery Fee',
                                style: GoogleFonts.karla(
                                    fontSize: 13,
                                    color:    AppColors.textSecondary)),
                          ]),
                          Text('₱${cart.deliveryFee.toStringAsFixed(2)}',
                              style: GoogleFonts.karla(
                                  fontSize:   13,
                                  fontWeight: FontWeight.w600,
                                  color:      AppColors.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    const Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: AppSpacing.sm),

                    // ── Grand Total ───────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total to Pay',
                            style: GoogleFonts.karla(
                                fontSize:   14,
                                fontWeight: FontWeight.w700,
                                color:      AppColors.textPrimary)),
                        Text('₱${cart.totalAmount.toStringAsFixed(2)}',
                            style: GoogleFonts.playfairDisplaySc(
                                fontSize:   22,
                                fontWeight: FontWeight.w700,
                                color:      AppColors.primary)),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // Reminder chip
                    Container(
                      width:   double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color:        AppColors.gold.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                            color: AppColors.gold.withOpacity(0.25)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppColors.gold, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Please prepare exact change.',
                            style: GoogleFonts.karla(
                                fontSize: 11,
                                color:    AppColors.gold,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // ── Error ──────────────────────────────────────────────────────
              if (cart.error != CartError.none) ...[
                _ErrorBanner(
                    message: cart.errorMessage ?? 'Something went wrong.'),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
      ),

      // ── Bottom bar ────────────────────────────────────────────────────────
      _CheckoutBottomBar(
        cart:      cart,
        isEnabled: !cart.isLoading,
        isLoading: cart.isLoading,
        label:     'PLACE ORDER (COD)',
        onPressed: () async {
          final res = await cart.placeOrder();
          if (res != null && context.mounted) {
            context.read<OrdersProvider>().loadOrders();
          }
        },
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Receipt Picker Card (GCash upload)
// ══════════════════════════════════════════════════════════════════════════════
class _ReceiptPickerCard extends StatelessWidget {
  final File?               pickedImage;
  final bool                isExtracting;
  final String?             extractError;
  final GcashExtractResult? extractResult;
  final VoidCallback        onPickTap;
  final VoidCallback?       onExtractTap;
  final VoidCallback?       onReuploadTap;

  const _ReceiptPickerCard({
    required this.pickedImage,
    required this.isExtracting,
    required this.extractError,
    required this.extractResult,
    required this.onPickTap,
    required this.onExtractTap,
    required this.onReuploadTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = extractResult != null;

    return Container(
      width:      double.infinity,
      padding:    const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color:        AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isSuccess ? Colors.green.shade300 : AppColors.border,
          width: isSuccess ? 2 : 1,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Image preview ──────────────────────────────────────────────────
          GestureDetector(
            onTap: isExtracting || isSuccess ? null : onPickTap,
            child: AnimatedContainer(
              duration:    const Duration(milliseconds: 200),
              // Fixed height only for the empty placeholder; when image is
              // loaded, let it expand naturally so nothing is cropped.
              height:      pickedImage != null ? null : 160,
              width:       double.infinity,
              decoration: BoxDecoration(
                color:        AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isSuccess
                      ? Colors.green.shade300
                      : pickedImage != null
                      ? AppColors.gold.withOpacity(0.5)
                      : AppColors.border,
                  width: pickedImage != null ? 2 : 1,
                ),
              ),
              child: pickedImage != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md - 1),
                child: Image.file(
                  pickedImage!,
                  fit:   BoxFit.contain, // show full image, no cropping
                  width: double.infinity,
                ),
              )
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.upload_rounded,
                      size: 36, color: AppColors.textMuted),
                  const SizedBox(height: 8),
                  Text('Tap to select receipt screenshot',
                      style: GoogleFonts.karla(
                          color: AppColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('JPG, PNG or WebP • Max 5 MB',
                      style: GoogleFonts.karla(
                          color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
          ),

          // ── OCR result banner ──────────────────────────────────────────────
          if (isSuccess) ...[
            const SizedBox(height: AppSpacing.md),
            _ExtractResultBanner(result: extractResult!),
          ],

          // ── Error banner ───────────────────────────────────────────────────
          if (extractError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _ErrorBanner(message: extractError!),
          ],

          const SizedBox(height: AppSpacing.md),

          // ── Action buttons ─────────────────────────────────────────────────
          if (!isSuccess) ...[
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isExtracting ? null : onPickTap,
                  icon:  const Icon(Icons.photo_library_rounded, size: 16),
                  label: Text(
                    pickedImage != null ? 'Change' : 'Select',
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
                  onPressed: onExtractTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:         AppColors.primary,
                    foregroundColor:         Colors.white,
                    disabledBackgroundColor: AppColors.border,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                    padding:
                    const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: isExtracting
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                                Colors.white)),
                      ),
                      const SizedBox(width: 8),
                      Text('Scanning…',
                          style: GoogleFonts.karla(
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ],
                  )
                      : Text(
                    pickedImage != null
                        ? 'Scan Receipt'
                        : 'Select First',
                    style: GoogleFonts.karla(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ]),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onReuploadTap,
                icon:  const Icon(Icons.refresh_rounded, size: 16),
                label: Text('Upload Different Receipt',
                    style: GoogleFonts.karla(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Extract Result Banner ─────────────────────────────────────────────────────
class _ExtractResultBanner extends StatelessWidget {
  final GcashExtractResult result;
  const _ExtractResultBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    final hasRef    = result.refFound    && result.gcashRefNumber != null;
    final hasAmount = result.amountFound && result.gcashAmount    != null;

    return Container(
      padding:    const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color:        Colors.green.shade50,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border:       Border.all(color: Colors.green.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Row(children: [
            Icon(Icons.check_circle_rounded,
                color: Colors.green.shade600, size: 16),
            const SizedBox(width: 6),
            Text(
              'Receipt scanned!',
              style: GoogleFonts.karla(
                  fontWeight: FontWeight.w700,
                  color:      Colors.green.shade700,
                  fontSize:   13),
            ),
          ]),

          const SizedBox(height: AppSpacing.md),

          // ── Ref number row ────────────────────────────────────────────────
          _ExtractRow(
            label:    'Reference No.',
            value:    hasRef ? result.gcashRefNumber! : null,
            fallback: 'Not found — staff will verify',
            isLarge:  true,
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Amount row ────────────────────────────────────────────────────
          _ExtractRow(
            label:    'Amount Sent',
            value:    hasAmount
                ? '₱${result.gcashAmount!.toStringAsFixed(2)}'
                : null,
            fallback: 'Not found — staff will verify',
            isLarge:  true,
          ),

          // ── Warning if either is missing ──────────────────────────────────
          if (!hasRef || !hasAmount) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 6),
              decoration: BoxDecoration(
                color:        Colors.orange.shade50,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Colors.orange.shade600, size: 13),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Some details couldn\'t be read clearly. '
                          'You may still proceed — our staff will verify manually.',
                      style: GoogleFonts.karla(
                          fontSize: 11,
                          color:    Colors.orange.shade700,
                          height:   1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Single extracted field row ────────────────────────────────────────────────
class _ExtractRow extends StatelessWidget {
  final String  label;
  final String? value;
  final String  fallback;
  final bool    isLarge;

  const _ExtractRow({
    required this.label,
    required this.value,
    required this.fallback,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final found = value != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          found ? Icons.check_rounded : Icons.remove_rounded,
          size:  14,
          color: found ? Colors.green.shade600 : Colors.orange.shade400,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.karla(
                      fontSize: 11,
                      color:    found
                          ? Colors.green.shade600
                          : Colors.orange.shade600)),
              Text(
                found ? value! : fallback,
                style: found
                    ? GoogleFonts.karla(
                    fontSize:      isLarge ? 17 : 14,
                    fontWeight:    FontWeight.w900,
                    color:         Colors.green.shade800,
                    letterSpacing: isLarge ? 0.8 : 0)
                    : GoogleFonts.karla(
                    fontSize: 12,
                    color:    Colors.orange.shade700,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Confirmation Step
// ══════════════════════════════════════════════════════════════════════════════
class _ConfirmationStep extends StatelessWidget {
  final CartProvider cart;
  const _ConfirmationStep({required this.cart});

  @override
  Widget build(BuildContext context) {
    final order   = cart.lastOrder;
    final isGcash = cart.paymentMethod == PaymentMethod.gcash;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(children: [
        const SizedBox(height: AppSpacing.lg),

        // ── Success badge ────────────────────────────────────────────────
        Container(
          width: 104, height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.gold.withOpacity(0.12),
            border: Border.all(
                color: AppColors.gold.withOpacity(0.3), width: 1.5),
          ),
          child: Center(
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape:     BoxShape.circle,
                color:     AppColors.gold,
                boxShadow: AppShadows.goldGlow,
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.primaryDark, size: 40),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        Text('Order placed!',
            style:     AppTextStyles.display2(context),
            textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        Text(
          isGcash
              ? 'Your receipt has been submitted.\nWe\'ll verify your payment shortly.'
              : 'Your order is being prepared.\nWe\'ll notify you every step of the way.',
          style:     AppTextStyles.bodyMedium(context),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AppSpacing.xl),

        // ── Order summary card ───────────────────────────────────────────
        if (order != null) ...[
          Container(
            width:      double.infinity,
            padding:    const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color:        AppColors.card,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                  color: AppColors.gold.withOpacity(0.4), width: 1.5),
              boxShadow: AppShadows.goldGlow,
            ),
            child: Column(children: [
              const ChineseDivider(),
              const SizedBox(height: AppSpacing.md),
              Text('Order Number',
                  style: AppTextStyles.label(context)
                      .copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                order.orderNumber,
                style: GoogleFonts.playfairDisplaySc(
                    fontSize:      24,
                    fontWeight:    FontWeight.w700,
                    color:         AppColors.primary,
                    letterSpacing: 1),
              ),
              const SizedBox(height: AppSpacing.md),
              const ChineseDivider(),
              const SizedBox(height: AppSpacing.md),
              _ConfirmRow(
                label: 'Items',
                value: '${cart.totalItemCount} '
                    '${cart.totalItemCount == 1 ? 'item' : 'items'}',
              ),
              const SizedBox(height: AppSpacing.sm),
              _ConfirmRow(
                label: 'Payment',
                value: isGcash ? 'GCash' : 'Cash on Delivery',
              ),
              if (cart.ridersAvailable &&
                  (cart.deliveryAddress?.address.isNotEmpty ?? false)) ...[
                const SizedBox(height: AppSpacing.sm),
                _ConfirmRow(
                  label: 'Deliver to',
                  value: cart.deliveryAddress!.address,
                ),
              ],

              // ── GCash ref + amount — above Total ─────────────────────
              if (isGcash && cart.gcashExtractResult != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _ConfirmRow(
                  label: 'GCash Ref No.',
                  value: cart.gcashExtractResult!.refFound
                      ? cart.gcashExtractResult!.gcashRefNumber!
                      : 'To be verified',
                ),
                const SizedBox(height: AppSpacing.sm),
                _ConfirmRow(
                  label: 'Amount Sent',
                  value: cart.gcashExtractResult!.amountFound
                      ? '₱${cart.gcashExtractResult!.gcashAmount!.toStringAsFixed(2)}'
                      : 'To be verified',
                ),
              ],

              const SizedBox(height: AppSpacing.sm),
              _ConfirmRow(
                label: 'Subtotal',
                value: '₱${order.subtotal.toStringAsFixed(2)}',
              ),
              if (cart.ridersAvailable) ...[
                const SizedBox(height: AppSpacing.sm),
                _ConfirmRow(
                  label: '🛵  Delivery Fee',
                  value: order.deliveryFee > 0
                      ? '₱${order.deliveryFee.toStringAsFixed(2)}'
                      : 'Free',
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.12)),
                ),
                child: _ConfirmRow(
                  label:     'Total',
                  value:     '₱${order.totalAmount.toStringAsFixed(2)}',
                  emphasize: true,
                ),
              ),

              const SizedBox(height: AppSpacing.md),
              const ChineseDivider(),
            ]),
          ),
        ],

        const SizedBox(height: AppSpacing.lg),

        PrimaryButton(
          label:     'VIEW MY ORDERS',
          onPressed: () {
            cart.clearCart();
            Navigator.popUntil(context, (r) => r.isFirst);
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder:        (_, a, __) => const MyOrdersScreen(),
                transitionsBuilder: (_, a, __, child) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end:   Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: a, curve: Curves.easeOutCubic)),
                  child: child,
                ),
                transitionDuration: const Duration(milliseconds: 400),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        GoldOutlineButton(
          label:     'BACK TO MENU',
          onPressed: () {
            cart.clearCart();
            Navigator.popUntil(context, (r) => r.isFirst);
          },
        ),
        const SizedBox(height: AppSpacing.xl),
      ]),
    );
  }
}

// ─── Confirmation row ─────────────────────────────────────────────────────────
class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;
  final bool   emphasize;
  const _ConfirmRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.bodyMedium(context)
                .copyWith(color: AppColors.textMuted)),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: emphasize
                ? GoogleFonts.playfairDisplaySc(
                fontSize:   18,
                fontWeight: FontWeight.w700,
                color:      AppColors.primary)
                : GoogleFonts.karla(
                fontSize:   14,
                fontWeight: FontWeight.w700,
                color:      AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Placing Order overlay
// ══════════════════════════════════════════════════════════════════════════════
class _PlacingOrderScreen extends StatelessWidget {
  const _PlacingOrderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          BrandCatIcon(size: 72),
          const SizedBox(height: AppSpacing.xl),
          Text('Placing your order…',
              style: GoogleFonts.playfairDisplaySc(
                  fontSize:   20,
                  fontWeight: FontWeight.w700,
                  color:      AppColors.textOnDark)),
          const SizedBox(height: AppSpacing.sm),
          Text('Hold on a moment',
              style: GoogleFonts.karla(
                  fontSize: 13,
                  color:    AppColors.textOnDark.withOpacity(0.6))),
          const SizedBox(height: AppSpacing.xl),
          const CircularProgressIndicator(
              color: AppColors.gold, strokeWidth: 2.5),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Checkout Bottom Bar
// ══════════════════════════════════════════════════════════════════════════════
class _CheckoutBottomBar extends StatelessWidget {
  final CartProvider cart;
  final bool         isEnabled;
  final bool         isLoading;
  final String       label;
  final VoidCallback onPressed;

  const _CheckoutBottomBar({
    required this.cart,
    required this.isEnabled,
    required this.isLoading,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isClosed =
        context.watch<BusinessHoursProvider>().isKnownClosed;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md, AppSpacing.md, AppSpacing.md,
        AppSpacing.md + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: BoxDecoration(
        color:  AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
              color:      AppColors.shadow,
              blurRadius: 12,
              offset:     const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BusinessHoursBanner(compact: true),
          // ── Subtotal + Delivery Fee ─────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal',
                  style: GoogleFonts.karla(
                      fontSize: 12, color: AppColors.textMuted)),
              Text('₱${cart.subtotal.toStringAsFixed(2)}',
                  style: GoogleFonts.karla(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          if (cart.ridersAvailable) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.delivery_dining_rounded,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text('Delivery Fee',
                      style: GoogleFonts.karla(
                          fontSize: 12, color: AppColors.textMuted)),
                ]),
                Text('₱${cart.deliveryFee.toStringAsFixed(2)}',
                    style: GoogleFonts.karla(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ],
          const SizedBox(height: 6),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order Total',
                  style: AppTextStyles.label(context)
                      .copyWith(color: AppColors.textMuted)),
              Text(
                '₱${cart.totalAmount.toStringAsFixed(2)}',
                style: GoogleFonts.playfairDisplaySc(
                    fontSize:   22,
                    fontWeight: FontWeight.w700,
                    color:      AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label:     label,
              onPressed: (isEnabled && !isClosed) ? onPressed : null,
              isLoading: isLoading,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared Widgets
// ══════════════════════════════════════════════════════════════════════════════

class _DeliverToCard extends StatelessWidget {
  final CustomerProfile profile;
  final String?         address;
  final VoidCallback?   onTap;
  const _DeliverToCard({required this.profile, this.address, this.onTap});

  @override
  Widget build(BuildContext context) {
    final displayAddress = (address != null && address!.trim().isNotEmpty)
        ? address
        : profile.address;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:    const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color:        AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border:       Border.all(color: AppColors.border),
          boxShadow:    AppShadows.card,
        ),
        child: Row(children: [
          Container(
            padding:    const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.location_on_rounded,
                color: AppColors.gold, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.displayName,
                    style: GoogleFonts.karla(
                        fontSize:   14,
                        fontWeight: FontWeight.w700,
                        color:      AppColors.textPrimary)),
                if (displayAddress != null) ...[
                  const SizedBox(height: 2),
                  Text(displayAddress,
                      style:    AppTextStyles.bodySmall(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 20),
          ],
        ]),
      ),
    );
  }
}

class _SaveAddressToggle extends StatelessWidget {
  final bool             value;
  final ValueChanged<bool> onChanged;
  const _SaveAddressToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          SizedBox(
            width: 24, height: 24,
            child: Checkbox(
              value:     value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor:              AppColors.primary,
              materialTapTargetSize:    MaterialTapTargetSize.shrinkWrap,
              visualDensity:            VisualDensity.compact,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Save as my default address',
              style: GoogleFonts.karla(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodRestrictedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color:        AppColors.error.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border:       Border.all(color: AppColors.error.withOpacity(0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.block_rounded, color: AppColors.error, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Cash on Delivery is unavailable for your account. Please use GCash.',
            style: GoogleFonts.karla(
                fontSize: 12, color: AppColors.error, height: 1.4),
          ),
        ),
      ]),
    );
  }
}

// ── Pickup-Only Banner ────────────────────────────────────────────────────────
/// Shown at the top of the checkout screen when no riders are currently online.
/// Informs the customer that only pickup is available today.
class _PickupOnlyBanner extends StatelessWidget {
  const _PickupOnlyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        // Warm amber tone — noticeable pero hindi alarming (hindi pula)
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: const Color(0xFFFFCA28), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.store_mall_directory_rounded,
              size: 18,
              color: Color(0xFFF57C00),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pickup Only — Walang Available na Rider',
                  style: GoogleFonts.karla(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7B4F00),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hindi available ang delivery ngayon. '
                  'I-pick up ang iyong order sa Bingnondo Cafe.',
                  style: GoogleFonts.karla(
                    fontSize: 11.5,
                    color: const Color(0xFF7B4F00),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color:        AppColors.error.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border:       Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 16),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(message,
              style: GoogleFonts.karla(
                  fontSize: 12, color: AppColors.error, height: 1.4)),
        ),
      ]),
    );
  }
}

class _OrderSummaryCard extends StatefulWidget {
  final CartProvider       cart;
  final GcashExtractResult? extractResult;

  const _OrderSummaryCard({
    required this.cart,
    this.extractResult,
  });

  @override
  State<_OrderSummaryCard> createState() => _OrderSummaryCardState();
}

class _OrderSummaryCardState extends State<_OrderSummaryCard> {
  // Local editable copies — only active when OCR found the value
  late TextEditingController _refCtrl;
  late TextEditingController _amountCtrl;

  bool _editingRef    = false;
  bool _editingAmount = false;

  @override
  void initState() {
    super.initState();
    _refCtrl    = TextEditingController(
        text: widget.extractResult?.gcashRefNumber ?? '');
    _amountCtrl = TextEditingController(
        text: widget.extractResult?.gcashAmount != null
            ? widget.extractResult!.gcashAmount!.toStringAsFixed(2)
            : '');
  }

  @override
  void didUpdateWidget(_OrderSummaryCard old) {
    super.didUpdateWidget(old);
    // Sync controllers when extractResult changes (new scan)
    final newRef    = widget.extractResult?.gcashRefNumber ?? '';
    final newAmount = widget.extractResult?.gcashAmount != null
        ? widget.extractResult!.gcashAmount!.toStringAsFixed(2)
        : '';
    if (old.extractResult != widget.extractResult) {
      _refCtrl.text    = newRef;
      _amountCtrl.text = newAmount;
      _editingRef      = false;
      _editingAmount   = false;
    }
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  // Commit edits back to the cart provider
  void _commitRef() {
    final val = _refCtrl.text.trim();
    if (val.isNotEmpty) widget.cart.overrideGcashRef(val);
    setState(() => _editingRef = false);
  }

  void _commitAmount() {
    final val = double.tryParse(_amountCtrl.text.trim());
    if (val != null) widget.cart.overrideGcashAmount(val);
    setState(() => _editingAmount = false);
  }

  @override
  Widget build(BuildContext context) {
    final extract   = widget.extractResult;
    final hasRef    = extract != null && extract.refFound;
    final hasAmount = extract != null && extract.amountFound;
    final hasAny    = extract != null;

    return Container(
      padding:    const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color:        AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border:       Border.all(color: AppColors.border),
        boxShadow:    AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header ──────────────────────────────────────────────────────
          Row(children: [
            Text('Order Summary', style: AppTextStyles.label(context)),
            const Spacer(),
            Text(
              '${widget.cart.totalItemCount} '
                  '${widget.cart.totalItemCount == 1 ? 'item' : 'items'}',
              style: AppTextStyles.caption(context),
            ),
          ]),

          const SizedBox(height: AppSpacing.md),

          // ── Items list ───────────────────────────────────────────────────
          ...widget.cart.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(children: [
              FoodThumb(url: item.photoUrl, size: 40, radius: AppRadius.sm),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 26,
                child: Text('${item.quantity}×',
                    style: GoogleFonts.karla(
                        fontSize:   13,
                        fontWeight: FontWeight.w700,
                        color:      AppColors.gold)),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(item.name,
                    style: AppTextStyles.bodyMedium(context)
                        .copyWith(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('₱${item.subtotal.toStringAsFixed(2)}',
                  style: GoogleFonts.karla(
                      fontSize:   13,
                      fontWeight: FontWeight.w600,
                      color:      AppColors.textPrimary)),
            ]),
          )),

          const Divider(color: AppColors.border),

          // ── Subtotal ──────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal',
                  style: GoogleFonts.karla(
                      fontSize: 12, color: AppColors.textSecondary)),
              Text('₱${widget.cart.subtotal.toStringAsFixed(2)}',
                  style: GoogleFonts.karla(
                      fontSize: 12, color: AppColors.textPrimary)),
            ],
          ),
          if (widget.cart.ridersAvailable) ...[
            const SizedBox(height: 4),
            // ── Delivery Fee ────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.delivery_dining_rounded,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text('Delivery Fee',
                      style: GoogleFonts.karla(
                          fontSize: 12, color: AppColors.textSecondary)),
                ]),
                Text('₱${widget.cart.deliveryFee.toStringAsFixed(2)}',
                    style: GoogleFonts.karla(
                        fontSize: 12, color: AppColors.textPrimary)),
              ],
            ),
          ],
          const SizedBox(height: 6),
          const Divider(color: AppColors.border),

          // ── Total ────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: AppTextStyles.label(context)),
              Text('₱${widget.cart.totalAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.playfairDisplaySc(
                      fontSize:   16,
                      fontWeight: FontWeight.w700,
                      color:      AppColors.primary)),
            ],
          ),

          // ── GCash fields — only shown after a scan ────────────────────
          if (hasAny) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(color: AppColors.border),
            const SizedBox(height: AppSpacing.sm),

            // Reference Number
            _EditableSummaryField(
              label:       'Reference No.',
              controller:  _refCtrl,
              isEditable:  hasRef,
              isEditing:   _editingRef,
              placeholder: hasRef ? null : 'Not detected',
              icon:        Icons.tag_rounded,
              onEditTap:   hasRef
                  ? () => setState(() => _editingRef = true)
                  : null,
              onDone:      _commitRef,
              onCancel:    () {
                _refCtrl.text =
                    extract?.gcashRefNumber ?? '';
                setState(() => _editingRef = false);
              },
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            // Amount Sent
            _EditableSummaryField(
              label:       'Amount Sent',
              controller:  _amountCtrl,
              isEditable:  hasAmount,
              isEditing:   _editingAmount,
              placeholder: hasAmount ? null : 'Not detected',
              icon:        Icons.payments_rounded,
              prefix:      '₱ ',
              onEditTap:   hasAmount
                  ? () => setState(() => _editingAmount = true)
                  : null,
              onDone:      _commitAmount,
              onCancel:    () {
                _amountCtrl.text = extract?.gcashAmount != null
                    ? extract!.gcashAmount!.toStringAsFixed(2)
                    : '';
                setState(() => _editingAmount = false);
              },
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Single editable field row ─────────────────────────────────────────────────
class _EditableSummaryField extends StatelessWidget {
  final String                    label;
  final TextEditingController     controller;
  final bool                      isEditable;   // OCR found the value
  final bool                      isEditing;    // currently in edit mode
  final String?                   placeholder;  // shown when not found
  final String?                   prefix;       // e.g. "₱ "
  final IconData                  icon;
  final VoidCallback?             onEditTap;
  final VoidCallback              onDone;
  final VoidCallback              onCancel;
  final TextInputType             keyboardType;
  final List<TextInputFormatter>  inputFormatters;

  const _EditableSummaryField({
    required this.label,
    required this.controller,
    required this.isEditable,
    required this.isEditing,
    required this.icon,
    required this.onDone,
    required this.onCancel,
    required this.keyboardType,
    required this.inputFormatters,
    this.placeholder,
    this.prefix,
    this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Icon
        Container(
          width: 30, height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isEditable
                ? AppColors.primary.withOpacity(0.08)
                : AppColors.border.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(icon,
              size:  14,
              color: isEditable ? AppColors.primary : AppColors.textMuted),
        ),
        const SizedBox(width: AppSpacing.sm),

        // Label + value/input
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.karla(
                      fontSize: 10,
                      color:    AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3)),
              const SizedBox(height: 2),
              if (isEditing) ...[
                // ── Edit mode ────────────────────────────────────────────
                SizedBox(
                  height: 36,
                  child: TextField(
                    controller:      controller,
                    autofocus:       true,
                    keyboardType:    keyboardType,
                    inputFormatters: inputFormatters,
                    style: GoogleFonts.karla(
                        fontSize:   14,
                        fontWeight: FontWeight.w700,
                        color:      AppColors.textPrimary),
                    decoration: InputDecoration(
                      prefixText:     prefix,
                      prefixStyle:    GoogleFonts.karla(
                          fontSize:   14,
                          fontWeight: FontWeight.w700,
                          color:      AppColors.textPrimary),
                      isDense:        true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                              color: AppColors.primary)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2)),
                    ),
                    onSubmitted: (_) => onDone(),
                  ),
                ),
              ] else ...[
                // ── Display mode ─────────────────────────────────────────
                Text(
                  isEditable
                      ? (prefix ?? '') + controller.text
                      : placeholder ?? '—',
                  style: isEditable
                      ? GoogleFonts.karla(
                      fontSize:   14,
                      fontWeight: FontWeight.w800,
                      color:      AppColors.textPrimary,
                      letterSpacing: 0.4)
                      : GoogleFonts.karla(
                      fontSize:  13,
                      color:     AppColors.textMuted,
                      fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),

        // Action buttons
        if (isEditing) ...[
          // ── Confirm / Cancel ─────────────────────────────────────────
          IconButton(
            onPressed:  onDone,
            icon:       const Icon(Icons.check_rounded),
            color:      AppColors.success,
            iconSize:   20,
            padding:    EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip:    'Save',
          ),
          IconButton(
            onPressed:  onCancel,
            icon:       const Icon(Icons.close_rounded),
            color:      AppColors.textMuted,
            iconSize:   20,
            padding:    EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip:    'Cancel',
          ),
        ] else if (isEditable) ...[
          // ── Edit pencil ───────────────────────────────────────────────
          IconButton(
            onPressed:  onEditTap,
            icon:       const Icon(Icons.edit_rounded),
            color:      AppColors.primary,
            iconSize:   16,
            padding:    EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip:    'Edit',
          ),
        ] else ...[
          // ── Locked ────────────────────────────────────────────────────
          const SizedBox(
            width: 32, height: 32,
            child: Icon(Icons.lock_outline_rounded,
                size: 14, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}
