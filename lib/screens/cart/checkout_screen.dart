/**
 * checkout_screen.dart  —  §1.5 Cart & Checkout
 * ─────────────────────────────────────────────────────────────
 * Steps: Payment → (placing overlay) → Confirmation
 *
 * GCash flow:
 *   1. Customer picks payment method → GCash
 *   2. Receipt upload section appears
 *   3. Customer picks screenshot → upload → backend OCR
 *   4. Extracted ref shown → "Confirm & Place Order" unlocks
 *   5. Tap confirm → POST /api/orders (with temp_url + ref)
 *   6. Confirmation screen
 *
 * COD flow:
 *   1. Customer picks COD → "Place Order" button available immediately
 *   2. Confirmation screen
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/cart_models.dart';
import '../../services/cart_provider.dart';
import '../../services/orders_provider.dart';
import '../../services/gcash_receipt_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../orders/my_orders_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double>   _fade;

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

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                children: [
                  _buildTopBar(context, cart),
                  Expanded(child: _buildBody(context, cart)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Top bar (header + step indicator) ─────────────────────────────────────
  Widget _buildTopBar(BuildContext context, CartProvider cart) {
    final isConfirmation = cart.step == CheckoutStep.confirmation;

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
            if (!isConfirmation)
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                color: AppColors.textOnDark,
                onPressed: () => Navigator.pop(context),
              )
            else
              const SizedBox(width: 48),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isConfirmation ? 'Order Placed!' : 'Checkout',
                    style: GoogleFonts.playfairDisplaySc(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textOnDark,
                    ),
                  ),
                  if (!isConfirmation)
                    Text(
                      'Review your order and confirm',
                      style: GoogleFonts.karla(
                        fontSize: 12,
                        color: AppColors.textOnDark.withOpacity(0.7),
                      ),
                    ),
                ],
              ),
            ),
            if (!isConfirmation) const SizedBox(width: 48),
          ]),
          if (!isConfirmation) ...[
            const SizedBox(height: AppSpacing.md),
            _buildStepIndicator(cart),
          ],
        ],
      ),
    );
  }

  // ─── Step indicator ────────────────────────────────────────────────────────
  Widget _buildStepIndicator(CartProvider cart) {
    const steps     = ['Payment', 'Done'];
    final currentIdx = cart.step == CheckoutStep.payment ? 0 : 1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Padding(
            padding: const EdgeInsets.only(top: 13, left: 10, right: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 44,
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
        return _PaymentStep(cart: cart);
      case CheckoutStep.confirmation:
        return _ConfirmationStep(cart: cart);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Payment Step
// ══════════════════════════════════════════════════════════════════════════════
class _PaymentStep extends StatefulWidget {
  final CartProvider cart;
  const _PaymentStep({required this.cart});

  @override
  State<_PaymentStep> createState() => _PaymentStepState();
}

class _PaymentStepState extends State<_PaymentStep> {
  File?   _pickedImage;
  String? _imageMime;
  bool    _isExtracting = false;
  String? _extractError;

  final _picker = ImagePicker();

  CartProvider get cart => widget.cart;

  // ── Image picker ───────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
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

    // Clear previous extract result so button locks again
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

  // ── Upload + OCR ───────────────────────────────────────────────────────────
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
    final isGcash        = cart.paymentMethod == PaymentMethod.gcash;
    final extractResult  = cart.gcashExtractResult;
    final receiptReady   = cart.gcashReceiptReady;

    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Deliver to ────────────────────────────────────────────────
              if (cart.profile != null) ...[
                Text('Deliver to', style: AppTextStyles.label(context)),
                const SizedBox(height: AppSpacing.sm),
                _DeliverToCard(profile: cart.profile!),
                const SizedBox(height: AppSpacing.xl),
              ],

              // ── Error banner ──────────────────────────────────────────────
              if (cart.error != CartError.none) ...[
                _ErrorBanner(message: cart.errorMessage ?? 'Something went wrong.'),
                const SizedBox(height: AppSpacing.md),
              ],

              // ── Payment method ────────────────────────────────────────────
              Text('Payment Method', style: AppTextStyles.label(context)),
              const SizedBox(height: AppSpacing.sm),
              _PaymentOption(
                method:   PaymentMethod.gcash,
                selected: cart.paymentMethod,
                onTap:    () => cart.setPaymentMethod(PaymentMethod.gcash),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (cart.canUseCod)
                _PaymentOption(
                  method:   PaymentMethod.cod,
                  selected: cart.paymentMethod,
                  onTap:    () => cart.setPaymentMethod(PaymentMethod.cod),
                )
              else
                _CodRestrictedBanner(),

              // ── GCash receipt section ─────────────────────────────────────
              if (isGcash) ...[
                const SizedBox(height: AppSpacing.xl),
                Text('GCash Receipt', style: AppTextStyles.label(context)),
                const SizedBox(height: AppSpacing.sm),
                _GcashInstructionCard(),
                const SizedBox(height: AppSpacing.md),

                // Image preview / picker
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
              ],

              const SizedBox(height: AppSpacing.xl),

              // ── Order summary ─────────────────────────────────────────────
              _OrderSummaryCard(cart: cart),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),

      // ── Bottom bar ─────────────────────────────────────────────────────────
      _CheckoutBottomBar(
        cart:       cart,
        isEnabled:  receiptReady && !cart.isLoading,
        isLoading:  cart.isLoading,
        label:      isGcash
            ? (extractResult != null
            ? 'CONFIRM & PLACE ORDER'
            : 'UPLOAD RECEIPT FIRST')
            : 'PLACE ORDER (COD)',
        onPressed:  () async {
          final res = await cart.placeOrder();
          if (res != null && context.mounted) {
            // New order → unlock "Message Staff" immediately
            context.read<OrdersProvider>().loadOrders();
          }
        },
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// GCash Instruction Card
// ══════════════════════════════════════════════════════════════════════════════
class _GcashInstructionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color:        AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border:       Border.all(color: AppColors.gold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.gold, size: 16),
            const SizedBox(width: 6),
            Text('How to pay',
                style: GoogleFonts.karla(
                    fontWeight: FontWeight.w700,
                    color:      AppColors.primary,
                    fontSize:   13)),
          ]),
          const SizedBox(height: AppSpacing.sm),
          _InstructionStep(n: '1', text: 'Send GCash payment to our number.'),
          _InstructionStep(n: '2', text: 'Screenshot your GCash receipt.'),
          _InstructionStep(n: '3', text: 'Upload the screenshot below.'),
          _InstructionStep(n: '4', text: 'We extract your ref number, then you confirm.'),
        ],
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final String n;
  final String text;
  const _InstructionStep({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18, height: 18,
            decoration: const BoxDecoration(
                color: AppColors.gold, shape: BoxShape.circle),
            child: Center(
              child: Text(n,
                  style: GoogleFonts.karla(
                      fontSize:   10,
                      fontWeight: FontWeight.w900,
                      color:      AppColors.primaryDark)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: GoogleFonts.karla(
                    fontSize: 12,
                    color:    AppColors.textSecondary,
                    height:   1.4)),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Receipt Picker Card
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
          color: isSuccess
              ? Colors.green.shade300
              : AppColors.border,
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
              duration: const Duration(milliseconds: 200),
              height:   180,
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
                child: Image.file(pickedImage!,
                    fit: BoxFit.cover, width: double.infinity),
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
              // Select / change image
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
              // Extract / scan
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
            // Re-upload button
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
          Row(children: [
            Icon(Icons.check_circle_rounded,
                color: Colors.green.shade600, size: 16),
            const SizedBox(width: 6),
            Text(
              result.refFound
                  ? 'Reference number extracted!'
                  : 'Receipt uploaded',
              style: GoogleFonts.karla(
                  fontWeight: FontWeight.w700,
                  color:      Colors.green.shade700,
                  fontSize:   13),
            ),
          ]),
          if (result.refFound) ...[
            const SizedBox(height: 6),
            Text('Ref No.',
                style: GoogleFonts.karla(
                    fontSize: 11, color: Colors.green.shade600)),
            Text(
              result.gcashRefNumber!,
              style: GoogleFonts.karla(
                  fontSize:      18,
                  fontWeight:    FontWeight.w900,
                  color:         Colors.green.shade800,
                  letterSpacing: 1.2),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'We couldn\'t read the ref number clearly. '
                  'Our staff will verify your receipt manually.',
              style: GoogleFonts.karla(
                  fontSize: 12,
                  color:    Colors.green.shade700,
                  height:   1.4),
            ),
          ],
        ],
      ),
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

        // Lanterns
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomPaint(
                size:    const Size(40, 56),
                painter: _ConfirmLantern(tilt: -0.15)),
            const SizedBox(width: 12),
            CustomPaint(
                size:    const Size(52, 72),
                painter: _ConfirmLantern(tilt: 0)),
            const SizedBox(width: 12),
            CustomPaint(
                size:    const Size(40, 56),
                painter: _ConfirmLantern(tilt: 0.15)),
          ],
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

        // Order number card
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
                label: 'Total',
                value: '₱${order.totalAmount.toStringAsFixed(2)}',
                emphasize: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              _ConfirmRow(
                label: 'Payment',
                value: isGcash ? 'GCash' : 'Cash on Delivery',
              ),
              const SizedBox(height: AppSpacing.md),
              const ChineseDivider(),
            ]),
          ),
          const SizedBox(height: AppSpacing.md),

          // GCash ref summary
          if (isGcash && cart.gcashExtractResult != null) ...[
            Container(
              padding:    const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color:        AppColors.surfaceWarm,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border:       Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                const Icon(Icons.receipt_long_rounded,
                    color: AppColors.gold, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: cart.gcashExtractResult!.refFound
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GCash Ref No.',
                          style: GoogleFonts.karla(
                              fontSize: 11,
                              color:    AppColors.textMuted)),
                      Text(
                        cart.gcashExtractResult!.gcashRefNumber!,
                        style: GoogleFonts.karla(
                            fontSize:   15,
                            fontWeight: FontWeight.w900,
                            color:      AppColors.textPrimary),
                      ),
                    ],
                  )
                      : Text(
                    'Staff will verify your receipt manually.',
                    style: GoogleFonts.karla(
                        fontSize: 12,
                        color:    AppColors.textSecondary,
                        height:   1.4),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
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
                pageBuilder:     (_, a, __) => const MyOrdersScreen(),
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
  final bool emphasize;
  const _ConfirmRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: AppTextStyles.bodyMedium(context)
                .copyWith(color: AppColors.textMuted)),
        Text(
          value,
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
              onPressed: isEnabled ? onPressed : null,
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
  const _DeliverToCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              if (profile.address != null) ...[
                const SizedBox(height: 2),
                Text(profile.address!,
                    style:    AppTextStyles.bodySmall(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ]),
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

class _PaymentOption extends StatelessWidget {
  final PaymentMethod method;
  final PaymentMethod selected;
  final VoidCallback  onTap;
  const _PaymentOption({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  IconData get _icon => method == PaymentMethod.gcash
      ? Icons.account_balance_wallet_rounded
      : Icons.payments_rounded;

  Color get _tint => method == PaymentMethod.gcash
      ? const Color(0xFF1E88E5)
      : AppColors.success;

  @override
  Widget build(BuildContext context) {
    final isSelected = method == selected;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration:   const Duration(milliseconds: 200),
        padding:    const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.05)
              : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Row(children: [
          // ── Method glyph ─────────────────────────────────────────────
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _tint.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: _tint.withOpacity(0.25)),
            ),
            child: Icon(_icon, color: _tint, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),

          // ── Label + description ──────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(method.label,
                    style: GoogleFonts.karla(
                        fontSize:   15,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(method.description,
                    style: AppTextStyles.bodySmall(context)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // ── Radio ────────────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22, height: 22,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 2),
              color: isSelected ? AppColors.primary : Colors.transparent,
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded,
                size: 13, color: AppColors.textOnDark)
                : null,
          ),
        ]),
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final CartProvider cart;
  const _OrderSummaryCard({required this.cart});

  @override
  Widget build(BuildContext context) {
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
          Row(children: [
            Text('Order Summary', style: AppTextStyles.label(context)),
            const Spacer(),
            Text('${cart.totalItemCount} '
                '${cart.totalItemCount == 1 ? 'item' : 'items'}',
                style: AppTextStyles.caption(context)),
          ]),
          const SizedBox(height: AppSpacing.md),
          ...cart.items.map((item) => Padding(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: AppTextStyles.label(context)),
              Text('₱${cart.totalAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.playfairDisplaySc(
                      fontSize:   16,
                      fontWeight: FontWeight.w700,
                      color:      AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Confirmation Lantern painter ─────────────────────────────────────────────
class _ConfirmLantern extends CustomPainter {
  final double tilt;
  const _ConfirmLantern({required this.tilt});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(tilt);
    canvas.translate(-size.width / 2, -size.height / 2);

    final gFill  = Paint()..color = AppColors.gold..style = PaintingStyle.fill;
    final mFill  = Paint()
      ..color = AppColors.primaryDark..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color       = AppColors.gold
      ..style       = PaintingStyle.stroke
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
    canvas.drawCircle(Offset(w / 2, h * 0.46), w * 0.08,
        Paint()..color = AppColors.goldLight.withOpacity(0.4));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.15, h * 0.74, w * 0.7, h * 0.08),
            const Radius.circular(2)),
        gFill);
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