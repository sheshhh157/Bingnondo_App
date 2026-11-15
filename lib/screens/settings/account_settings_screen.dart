import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/geo_models.dart';
import '../../models/notification_settings_models.dart';
import '../../services/account_settings_provider.dart';
import '../../services/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/address_picker_field.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen>
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
      context.read<AccountSettingsProvider>().loadProfile();
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: FadeTransition(
          opacity: _fade,
          child: Consumer<AccountSettingsProvider>(
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

  // ─── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, AccountSettingsProvider provider) {
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
            child: Text(
              'Account Settings',
              style: GoogleFonts.playfairDisplaySc(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textOnDark,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.gold, size: 22),
            tooltip: 'Sign Out',
            onPressed: () => _confirmSignOut(context),
          ),
        ],
      ),
    );
  }

  // ─── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody(BuildContext context, AccountSettingsProvider provider) {
    if (provider.loadState == SettingsLoadState.loading ||
        provider.loadState == SettingsLoadState.initial) {
      return _buildSkeleton();
    }

    if (provider.loadState == SettingsLoadState.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: AppColors.textMuted, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text('Could not load settings',
                  style: AppTextStyles.headline(context),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  PrimaryButton(
                    label: 'TRY AGAIN',
                    onPressed: provider.loadProfile,
                    isSmall: true,
                  ),
                  OutlinedButton(
                    onPressed: () => _confirmSignOut(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: Text(
                      'SIGN OUT',
                      style: GoogleFonts.karla(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxl + MediaQuery.of(context).viewPadding.bottom + 90,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + name block
          _buildAvatarBlock(context, provider.profile!),

          const SizedBox(height: AppSpacing.lg),

          // ── Section: Personal Info ─────────────────────────────────────
          _SectionHeader(label: 'Personal Info'),
          const SizedBox(height: AppSpacing.sm),
          _SettingsTile(
            icon: _PersonIconPainter(),
            label: 'Edit Profile',
            subtitle: provider.profile!.profileCompleted
                ? '${provider.profile!.displayName}'
                : 'Name, mobile & address not set',
            hasAlert: !provider.profile!.profileCompleted,
            onTap: () => _openEditProfile(context, provider),
          ),

          const SizedBox(height: AppSpacing.sm),
          _SettingsTile(
            icon: _MapPinPainter(),
            label: 'Delivery Address',
            subtitle: provider.profile!.address ?? 'No address saved',
            onTap: () => _openEditProfile(context, provider),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Section: Security ─────────────────────────────────────────
          _SectionHeader(label: 'Security'),
          const SizedBox(height: AppSpacing.sm),
          _SettingsTile(
            icon: _LockIconPainter(),
            label: 'Change Password',
            subtitle: 'Last changed: —',
            onTap: () => _openChangePassword(context, provider),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Section: Account ──────────────────────────────────────────
          // ── Section: Help & Support ───────────────────────────────────
          _SectionHeader(label: 'Help & Support'),
          const SizedBox(height: AppSpacing.sm),
          const _VisitUsCard(),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(label: 'Legal'),
          const SizedBox(height: AppSpacing.sm),
          _SettingsTile(
            icon: _LegalIconPainter(),
            label: 'Terms & Conditions',
            subtitle: 'Read the terms for using Bingnondo Cafe',
            onTap: () => _openTermsAndConditions(context),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(label: 'Account'),
          const SizedBox(height: AppSpacing.sm),
          _SettingsTile(
            icon: _EmailIconPainter(),
            label: 'Email Address',
            subtitle: provider.profile!.email ??
                'No email linked (mobile account)',
            onTap: null,
          ),
          const SizedBox(height: AppSpacing.sm),
          _SettingsTile(
            icon: _SignOutPainter(),
            label: 'Sign Out',
            subtitle: 'You can sign back in anytime',
            labelColor: AppColors.primary,
            onTap: () => _confirmSignOut(context),
          ),
          const SizedBox(height: AppSpacing.lg),
          // ── Danger Zone ───────────────────────────────────────────────
          _buildDangerZone(context),
        ],
      ),
    );
  }

  // ─── Avatar block ──────────────────────────────────────────────────────────
  Widget _buildAvatarBlock(BuildContext context, AccountProfile profile) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          // Avatar circle with initials
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            child: Center(
              child: Text(
                profile.initials,
                style: GoogleFonts.playfairDisplaySc(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: GoogleFonts.playfairDisplaySc(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(profile.email ?? profile.mobileNumber ?? 'No contact info',
                    style: AppTextStyles.bodySmall(context)),
                const SizedBox(height: 4),
                // Profile completeness badge
                _ProfileBadge(completed: profile.profileCompleted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Danger Zone ───────────────────────────────────────────────────────────
  Widget _buildDangerZone(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.04),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.error.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CustomPaint(
                  size: const Size(14, 14), painter: _WarningPainter()),
              const SizedBox(width: 6),
              Text(
                'Danger Zone',
                style: GoogleFonts.karla(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Deleting your account is permanent and cannot be undone. All your data, order history, and saved preferences will be removed.',
            style: GoogleFonts.karla(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: () => _confirmDeleteAccount(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error, width: 1.5),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: Text(
              'DELETE ACCOUNT',
              style: GoogleFonts.karla(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Skeleton ──────────────────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBox(height: 100, radius: AppRadius.lg),
          const SizedBox(height: AppSpacing.lg),
          _SkeletonBox(height: 14, width: 80, radius: AppRadius.sm),
          const SizedBox(height: AppSpacing.sm),
          _SkeletonBox(height: 70, radius: AppRadius.lg),
          const SizedBox(height: AppSpacing.sm),
          _SkeletonBox(height: 70, radius: AppRadius.lg),
          const SizedBox(height: AppSpacing.lg),
          _SkeletonBox(height: 14, width: 80, radius: AppRadius.sm),
          const SizedBox(height: AppSpacing.sm),
          _SkeletonBox(height: 70, radius: AppRadius.lg),
        ],
      ),
    );
  }

  // ─── Sheet launchers ───────────────────────────────────────────────────────
  void _openEditProfile(
      BuildContext context, AccountSettingsProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: _EditProfileSheet(profile: provider.profile!),
      ),
    );
  }

  void _openChangePassword(
      BuildContext context, AccountSettingsProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: const _ChangePasswordSheet(),
      ),
    );
  }

  void _openTermsAndConditions(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _TermsAndConditionsScreen()),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Sign out?', style: AppTextStyles.headline(context)),
        content: Text('You will be returned to the login screen.',
            style: AppTextStyles.bodyMedium(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTextStyles.bodyMedium(context)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AuthProvider>().logout();
            },
            child: Text('Sign Out',
                style: GoogleFonts.karla(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountConfirmationDialog(),
    );

    if (confirmed != true || !context.mounted) return;
    // TODO: POST /api/customer/delete-account
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Account deletion request sent.',
            style: GoogleFonts.karla(fontSize: 13)),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }
}

class _TermsAndConditionsScreen extends StatelessWidget {
  const _TermsAndConditionsScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                color: AppColors.primaryDark,
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  MediaQuery.of(context).padding.top + AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.gold),
                      tooltip: 'Back',
                    ),
                    Expanded(
                      child: Text(
                        'Terms & Conditions',
                        style: GoogleFonts.playfairDisplaySc(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textOnDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.xxl + MediaQuery.of(context).viewPadding.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Using the Bingnondo Cafe app',
                          style: AppTextStyles.headline(context)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'These terms describe the basic rules for using the app to browse the menu, place orders, manage your account, and contact the cafe. By using the app, you agree to follow them.',
                        style: AppTextStyles.bodyMedium(context),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const _TermsSection(
                        title: 'Orders and availability',
                        body:
                            'Review your items, quantities, prices, delivery details, and fees before placing an order. Orders depend on item availability and confirmation in the app. Menu items or prices may change.',
                      ),
                      const _TermsSection(
                        title: 'Payments and order updates',
                        body:
                            'Choose from the payment methods shown at checkout and follow the instructions there. Payment receipts may be checked by cafe staff. Use the order screen for status updates and contact staff through the support options if you need help.',
                      ),
                      const _TermsSection(
                        title: 'Your account',
                        body:
                            'Keep your sign-in details private and provide accurate contact and delivery information. You are responsible for activity carried out through your account.',
                      ),
                      const _TermsSection(
                        title: 'Using the app responsibly',
                        body:
                            'Use the app only for lawful purposes. Do not misuse the ordering or support features, interfere with the app, or attempt to access another person’s account.',
                      ),
                      const _TermsSection(
                        title: 'Changes and questions',
                        body:
                            'App features and these terms may be updated over time. For questions about an order or these terms, contact Bingnondo Cafe through the support options provided in the app.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _TermsSection extends StatelessWidget {
  final String title;
  final String body;

  const _TermsSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Container(
          width: double.infinity,
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
              Text(title,
                  style: GoogleFonts.karla(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  )),
              const SizedBox(height: AppSpacing.xs),
              Text(body, style: AppTextStyles.bodyMedium(context)),
            ],
          ),
        ),
      );
}

class _DeleteAccountConfirmationDialog extends StatefulWidget {
  const _DeleteAccountConfirmationDialog();

  @override
  State<_DeleteAccountConfirmationDialog> createState() =>
      _DeleteAccountConfirmationDialogState();
}

class _DeleteAccountConfirmationDialogState
    extends State<_DeleteAccountConfirmationDialog> {
  final _confirmationController = TextEditingController();

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Delete account?', style: AppTextStyles.headline(context)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This is permanent and cannot be undone. All your data will be erased.',
              style: AppTextStyles.bodyMedium(context),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Type DELETE to confirm.',
                style: GoogleFonts.karla(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                )),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _confirmationController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'DELETE',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTextStyles.bodyMedium(context)),
          ),
          TextButton(
            onPressed: _confirmationController.text == 'DELETE'
                ? () => Navigator.pop(context, true)
                : null,
            child: Text('Delete',
                style: GoogleFonts.karla(
                    color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      );
}

// ─── Section Header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CustomPaint(size: const Size(10, 10), painter: _DiamondPainter()),
        const SizedBox(width: 7),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.karla(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
      ],
    );
  }
}

// ─── Settings Tile ─────────────────────────────────────────────────────────────
class _VisitUsCard extends StatelessWidget {
  const _VisitUsCard();

  static final _instagramUri = Uri.parse(
    'https://www.instagram.com/bingnondocafe?utm_source=ig_web_button_share_sheet&exln=ZDNlZDc0MzIxNw==',
  );
  static final _facebookUri = Uri.parse(
    'https://www.facebook.com/profile.php?id=100054493478096',
  );

  Future<void> _open(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the social media page.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
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
            Text('Follow Bingnondo Cafe',
                style: GoogleFonts.karla(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                )),
            const SizedBox(height: 4),
            Text('Visit us on social media for updates and offers.',
                style: GoogleFonts.karla(
                  fontSize: 13,
                  color: AppColors.textMuted,
                )),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _SocialLinkButton(
                  label: 'Instagram',
                  icon: Icons.camera_alt_outlined,
                  color: const Color(0xFFE1306C),
                  onTap: () => _open(context, _instagramUri),
                ),
                const SizedBox(width: AppSpacing.sm),
                _SocialLinkButton(
                  label: 'Facebook',
                  icon: Icons.facebook,
                  color: const Color(0xFF1877F2),
                  onTap: () => _open(context, _facebookUri),
                ),
              ],
            ),
          ],
        ),
      );
}

class _SocialLinkButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SocialLinkButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, color: color, size: 20),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      );
}

class _SettingsTile extends StatelessWidget {
  final CustomPainter icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? labelColor;
  final bool hasAlert;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.onTap,
    this.labelColor,
    this.hasAlert = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: hasAlert
                ? AppColors.warning.withOpacity(0.4)
                : AppColors.border,
            width: hasAlert ? 1.5 : 1,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: hasAlert
                    ? AppColors.warning.withOpacity(0.1)
                    : AppColors.gold.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CustomPaint(size: const Size(18, 18), painter: icon),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.karla(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: labelColor ?? AppColors.textPrimary,
                        ),
                      ),
                      if (hasAlert) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.15),
                            borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            'Incomplete',
                            style: GoogleFonts.karla(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall(context),
                    maxLines: isWide ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Trailing
            if (trailing != null)
              trailing!
            else if (onTap != null)
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Profile Badge ─────────────────────────────────────────────────────────────
class _ProfileBadge extends StatelessWidget {
  final bool completed;
  const _ProfileBadge({required this.completed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: completed
            ? AppColors.success.withOpacity(0.1)
            : AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: completed
              ? AppColors.success.withOpacity(0.35)
              : AppColors.warning.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5, height: 5,
            decoration: BoxDecoration(
              color: completed ? AppColors.success : AppColors.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            completed ? 'Profile complete' : 'Profile incomplete',
            style: GoogleFonts.karla(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: completed ? AppColors.success : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Edit Profile Sheet ────────────────────────────────────────────────────────
class _EditProfileSheet extends StatefulWidget {
  final AccountProfile profile;
  const _EditProfileSheet({required this.profile});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _mobileCtrl;
  PickedAddress? _pickedAddress;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl =
        TextEditingController(text: widget.profile.firstName ?? '');
    _lastNameCtrl =
        TextEditingController(text: widget.profile.lastName ?? '');
    _mobileCtrl =
        TextEditingController(text: widget.profile.mobileNumber ?? '');
    _pickedAddress = (widget.profile.address != null &&
        widget.profile.address!.trim().isNotEmpty)
        ? PickedAddress(
      address:   widget.profile.address!,
      latitude:  widget.profile.latitude,
      longitude: widget.profile.longitude,
    )
        : null;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _mobileCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final isWide = MediaQuery.of(context).size.width >= 500;
    final provider = context.watch<AccountSettingsProvider>();
    final isSaving = provider.saveState == SettingsSaveState.saving;
    final isSaved = provider.saveState == SettingsSaveState.saved;

    return Container(
      height: screenH * 0.90,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill)),
            ),
          ),
          // Sheet header
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text('Edit Profile',
                      style: AppTextStyles.display2(context)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textMuted, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg +
                    MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (provider.saveError != null) ...[
                      StatusBanner(
                          message: provider.saveError!, isError: true),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (isSaved) ...[
                      StatusBanner(
                          message: 'Profile updated successfully!',
                          isError: false),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    // Name row
                    isWide
                        ? Row(
                      children: [
                        Expanded(child: _nameField(_firstNameCtrl, 'First Name')),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: _nameField(_lastNameCtrl, 'Last Name')),
                      ],
                    )
                        : Column(
                      children: [
                        _nameField(_firstNameCtrl, 'First Name'),
                        const SizedBox(height: AppSpacing.md),
                        _nameField(_lastNameCtrl, 'Last Name'),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    AppTextField(
                      label: 'Mobile Number',
                      hint: '+63 917 123 4567',
                      controller: _mobileCtrl,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(Icons.phone_outlined,
                          size: 20, color: AppColors.gold),
                      validator: (v) {
                        if (v != null && v.isNotEmpty) {
                          final ph = v.trim().replaceAll(' ', '');
                          if (!RegExp(r'^(\+63|0)[0-9]{10}$')
                              .hasMatch(ph)) {
                            return 'Enter a valid PH mobile number.';
                          }
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Address — pin-drop picker
                    AddressPickerField(
                      label:         'Delivery Address',
                      hint:          'Tap to pin your delivery location on the map',
                      initialValue:  _pickedAddress,
                      onChanged:     (p) => _pickedAddress = p,
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    PrimaryButton(
                      label: isSaved ? 'SAVED!' : 'SAVE CHANGES',
                      onPressed: isSaving || isSaved
                          ? null
                          : () async {
                        if (!_formKey.currentState!.validate())
                          return;
                        FocusScope.of(context).unfocus();
                        final req = UpdateProfileRequest(
                          firstName:
                          _firstNameCtrl.text.trim(),
                          lastName: _lastNameCtrl.text.trim(),
                          mobileNumber: _mobileCtrl.text
                              .trim()
                              .isEmpty
                              ? null
                              : _mobileCtrl.text.trim(),
                          address: (_pickedAddress == null ||
                              _pickedAddress!.isEmpty)
                              ? null
                              : _pickedAddress!.address,
                          latitude:  _pickedAddress?.latitude,
                          longitude: _pickedAddress?.longitude,
                        );
                        final ok = await context
                            .read<AccountSettingsProvider>()
                            .updateProfile(req);
                        if (ok && context.mounted) {
                          await Future.delayed(
                              const Duration(seconds: 1));
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        }
                      },
                      isLoading: isSaving,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nameField(TextEditingController ctrl, String label) {
    return AppTextField(
      label: label,
      controller: ctrl,
      keyboardType: TextInputType.name,
      textInputAction: TextInputAction.next,
      prefixIcon: const Icon(Icons.person_outline_rounded,
          size: 20, color: AppColors.gold),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return '$label is required.';
        return null;
      },
    );
  }
}

// ─── Change Password Sheet ─────────────────────────────────────────────────────
class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  double _strength(String pw) {
    if (pw.isEmpty) return 0;
    double s = 0;
    if (pw.length >= 8) s += 0.25;
    if (pw.length >= 12) s += 0.15;
    if (RegExp(r'[A-Z]').hasMatch(pw)) s += 0.2;
    if (RegExp(r'[0-9]').hasMatch(pw)) s += 0.2;
    if (RegExp(r'[!@#\$&*~%^]').hasMatch(pw)) s += 0.2;
    return s.clamp(0, 1);
  }

  Color _strengthColor(double s) {
    if (s < 0.35) return AppColors.error;
    if (s < 0.65) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AccountSettingsProvider>();
    final isSaving = provider.pwSaveState == SettingsSaveState.saving;
    final isSaved = provider.pwSaveState == SettingsSaveState.saved;

    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.pill)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                    child: Text('Change Password',
                        style: AppTextStyles.display2(context))),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textMuted, size: 20),
                  onPressed: () {
                    context
                        .read<AccountSettingsProvider>()
                        .resetSaveStates();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg +
                    MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (provider.pwError != null) ...[
                      StatusBanner(message: provider.pwError!, isError: true),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (isSaved) ...[
                      StatusBanner(
                          message: 'Password changed successfully!',
                          isError: false),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    AppTextField(
                      label: 'Current Password',
                      controller: _currentCtrl,
                      isPassword: true,
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(Icons.lock_outline_rounded,
                          size: 20, color: AppColors.gold),
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Current password is required.';
                        return null;
                      },
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // New password + strength bar
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _newCtrl,
                      builder: (_, val, __) {
                        final s = _strength(val.text);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppTextField(
                              label: 'New Password',
                              controller: _newCtrl,
                              isPassword: true,
                              textInputAction: TextInputAction.next,
                              prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 20,
                                  color: AppColors.gold),
                              validator: validatePassword,
                              autovalidateMode: AutovalidateMode.disabled,
                            ),
                            PasswordChecklist(password: val.text),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: AppSpacing.md),

                    AppTextField(
                      label: 'Confirm New Password',
                      controller: _confirmCtrl,
                      isPassword: true,
                      textInputAction: TextInputAction.done,
                      prefixIcon: const Icon(Icons.lock_outline_rounded,
                          size: 20, color: AppColors.gold),
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Please confirm your password.';
                        if (v != _newCtrl.text)
                          return 'Passwords do not match.';
                        return null;
                      },
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    PrimaryButton(
                      label: isSaved
                          ? 'PASSWORD CHANGED!'
                          : 'CHANGE PASSWORD',
                      onPressed: isSaving || isSaved
                          ? null
                          : () async {
                        if (!_formKey.currentState!.validate())
                          return;
                        FocusScope.of(context).unfocus();
                        final ok = await context
                            .read<AccountSettingsProvider>()
                            .changePassword(ChangePasswordRequest(
                          currentPassword: _currentCtrl.text,
                          newPassword: _newCtrl.text,
                        ));
                        if (ok && context.mounted) {
                          await Future.delayed(
                              const Duration(seconds: 1));
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                      isLoading: isSaving,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Skeleton box ──────────────────────────────────────────────────────────────
class _SkeletonBox extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;
  const _SkeletonBox(
      {required this.height, this.width, required this.radius});

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
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
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: Color.lerp(const Color(0xFFEFEBE4),
              const Color(0xFFDDD8CF), _a.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

// ─── Painters ──────────────────────────────────────────────────────────────────
class _DiamondPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
        Path()
          ..moveTo(size.width / 2, 0)
          ..lineTo(size.width, size.height / 2)
          ..lineTo(size.width / 2, size.height)
          ..lineTo(0, size.height / 2)
          ..close(),
        Paint()..color = AppColors.gold..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _PersonIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(
        Rect.fromLTWH(size.width * 0.25, 0, size.width * 0.5, size.height * 0.45), p);
    canvas.drawPath(
        Path()
          ..moveTo(0, size.height)
          ..quadraticBezierTo(
              0, size.height * 0.6, size.width / 2, size.height * 0.6)
          ..quadraticBezierTo(
              size.width, size.height * 0.6, size.width, size.height),
        p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _MapPinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..addOval(Rect.fromLTWH(size.width * 0.1, 0, size.width * 0.8, size.height * 0.65))
      ..moveTo(size.width / 2, size.height * 0.65)
      ..lineTo(size.width / 2, size.height);
    canvas.drawPath(path, p);
    canvas.drawOval(
        Rect.fromLTWH(size.width * 0.32, size.height * 0.17,
            size.width * 0.36, size.height * 0.32),
        p..color = AppColors.gold.withOpacity(0.5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _LockIconPainter extends CustomPainter {
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
            Rect.fromLTWH(size.width * 0.1, size.height * 0.45,
                size.width * 0.8, size.height * 0.55),
            const Radius.circular(4)),
        p);
    canvas.drawPath(
        Path()
          ..moveTo(size.width * 0.3, size.height * 0.45)
          ..lineTo(size.width * 0.3, size.height * 0.25)
          ..quadraticBezierTo(size.width * 0.3, 0, size.width * 0.5, 0)
          ..quadraticBezierTo(size.width * 0.7, 0, size.width * 0.7, size.height * 0.25)
          ..lineTo(size.width * 0.7, size.height * 0.45),
        p);
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.72), 2.5,
        p..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _LegalIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final page = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.18, size.height * 0.05,
          size.width * 0.64, size.height * 0.9),
      const Radius.circular(2),
    );
    canvas.drawRRect(page, paint);
    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.38 + i * 0.2);
      canvas.drawLine(Offset(size.width * 0.32, y),
          Offset(size.width * 0.68, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _EmailIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.textMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, size.height * 0.15, size.width, size.height * 0.7),
            const Radius.circular(3)),
        p);
    canvas.drawPath(
        Path()
          ..moveTo(0, size.height * 0.15)
          ..lineTo(size.width / 2, size.height * 0.55)
          ..lineTo(size.width, size.height * 0.15),
        p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _SignOutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Door with arrow
    canvas.drawPath(
        Path()
          ..moveTo(size.width * 0.5, size.height * 0.1)
          ..lineTo(size.width * 0.1, size.height * 0.1)
          ..lineTo(size.width * 0.1, size.height * 0.9)
          ..lineTo(size.width * 0.5, size.height * 0.9),
        p);
    canvas.drawPath(
        Path()
          ..moveTo(size.width * 0.55, size.height * 0.38)
          ..lineTo(size.width * 0.95, size.height * 0.5)
          ..lineTo(size.width * 0.55, size.height * 0.62),
        p);
    canvas.drawLine(Offset(size.width * 0.55, size.height * 0.5),
        Offset(size.width * 0.95, size.height * 0.5), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _WarningPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = AppColors.error.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = AppColors.error
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
        Path()
          ..moveTo(size.width / 2, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close(),
        fill);
    canvas.drawPath(
        Path()
          ..moveTo(size.width / 2, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close(),
        stroke);
    canvas.drawLine(Offset(size.width / 2, size.height * 0.35),
        Offset(size.width / 2, size.height * 0.65), stroke);
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.8), 1.2,
        stroke..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
