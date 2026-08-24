// screens/profile/edit_profile_screen.dart
//
// The single Edit Profile experience (approved decision: Option A — this replaces
// the registration-wizard route for every role; there is no second editor).
//
// Section order, headings and field order follow features/profile/EditProfile.tsx.
// Presentation is this app's: `DashboardCard` surfaces, `DashboardSectionLabel`
// headings, `AppActionButton`, `AppConstants` spacing, ordinary `InputDecoration`
// so `AppTheme.inputDecorationTheme` applies unchanged.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/profile_options.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/empty_state_view.dart';
import '../../core/widgets/scale_tap.dart';
import '../../providers/auth_provider.dart';
import '../../providers/edit_profile_provider.dart';
// `ProfileDocumentKind` is declared alongside the uploader that consumes it.
import '../../services/profile_media_service.dart';
import '../../widgets/shared/app_action_button.dart';
import '../../widgets/shared/app_surface_card.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EditProfileProvider(),
      child: const _EditProfileView(),
    );
  }
}

class _EditProfileView extends StatefulWidget {
  const _EditProfileView();

  @override
  State<_EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<_EditProfileView> {
  String? _loadedFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadIfNeeded());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadIfNeeded();
  }

  void _loadIfNeeded() {
    if (!mounted) return;
    final userId = context.read<AuthProvider>().userId;
    if (userId == null || userId == _loadedFor) return;
    _loadedFor = userId;

    final provider = context.read<EditProfileProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      provider.load(userId);
    });
  }

  Future<void> _save() async {
    final provider = context.read<EditProfileProvider>();
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final error = await provider.save();
    if (!mounted) return;

    if (error != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    // Re-read so every screen holding AuthProvider's cached row sees the change.
    await auth.refreshProfile();
    if (!mounted) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Profile updated')));
    navigator.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EditProfileProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Edit Profile',
          style: AppTextStyles.heading3.copyWith(fontSize: 16),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: ColoredBox(
            color: AppColors.hairline,
            child: SizedBox(height: 1),
          ),
        ),
      ),
      body: _buildBody(provider),
      bottomNavigationBar: provider.loading || provider.loadFailed
          ? null
          : _SaveBar(saving: provider.saving, onSave: _save),
    );
  }

  Widget _buildBody(EditProfileProvider p) {
    if (p.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (p.loadFailed) {
      return Center(
        child: EmptyStateView(
          icon: Icons.cloud_off_rounded,
          title: "Couldn't load your profile",
          message: 'Check your connection and try again.',
          actionLabel: 'Retry',
          onAction: () {
            final userId = context.read<AuthProvider>().userId;
            if (userId != null) p.load(userId);
          },
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingL,
        AppConstants.spacingL,
        AppConstants.spacingL,
        AppConstants.spacingXXL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _mediaSection(p),
          const SizedBox(height: AppConstants.spacingL),
          _basicSection(p),
          if (p.isBuilder) ...[
            const SizedBox(height: AppConstants.spacingL),
            _builderCompanySection(p),
            const SizedBox(height: AppConstants.spacingL),
            _addressSection(p, title: 'Office address & contacts'),
            const SizedBox(height: AppConstants.spacingL),
            _builderDetailsSection(p),
            const SizedBox(height: AppConstants.spacingL),
            _socialSection(p),
          ],
          if (p.isBroker) ...[
            const SizedBox(height: AppConstants.spacingL),
            _brokerProfessionalSection(p),
            const SizedBox(height: AppConstants.spacingL),
            _addressSection(p, title: 'Office address & contacts'),
            const SizedBox(height: AppConstants.spacingL),
            _brokerDealsSection(p),
            const SizedBox(height: AppConstants.spacingL),
            _socialSection(p),
          ],
          if (p.isInfluencer) ...[
            const SizedBox(height: AppConstants.spacingL),
            _influencerProfileSection(p),
            const SizedBox(height: AppConstants.spacingL),
            _addressSection(p, title: 'Work address & contacts'),
            const SizedBox(height: AppConstants.spacingL),
            _influencerSocialSection(p),
            const SizedBox(height: AppConstants.spacingL),
            _influencerContentSection(p),
          ],
          // EditProfile.tsx:2205 — "No additional details for individual role".
          if (!p.isBusinessRole) ...[
            const SizedBox(height: AppConstants.spacingL),
            _individualNote(),
          ],
          if (_documentKindsFor(p).isNotEmpty) ...[
            const SizedBox(height: AppConstants.spacingL),
            _documentsSection(p),
          ],
        ],
      ),
    );
  }

  /// Which verification documents this role uploads.
  ///
  /// EditProfile.tsx: builder 912-1013, broker 1532-1599, influencer 2153-2199.
  /// Individuals upload none.
  List<ProfileDocumentKind> _documentKindsFor(EditProfileProvider p) {
    if (p.isBuilder) {
      return const [
        ProfileDocumentKind.rera,
        ProfileDocumentKind.gst,
        ProfileDocumentKind.pan,
        ProfileDocumentKind.registrationProof,
        ProfileDocumentKind.companyLogo,
      ];
    }
    if (p.isBroker) {
      return const [
        ProfileDocumentKind.rera,
        ProfileDocumentKind.pan,
        ProfileDocumentKind.aadhaar,
      ];
    }
    if (p.isInfluencer) {
      return const [ProfileDocumentKind.aadhaar, ProfileDocumentKind.pan];
    }
    return const [];
  }

  static String _documentLabel(ProfileDocumentKind kind) => switch (kind) {
    ProfileDocumentKind.rera => 'RERA certificate',
    ProfileDocumentKind.gst => 'GST certificate',
    ProfileDocumentKind.pan => 'PAN card',
    ProfileDocumentKind.registrationProof => 'Registration proof',
    ProfileDocumentKind.aadhaar => 'Aadhaar card',
    ProfileDocumentKind.companyLogo => 'Company logo',
  };

  Future<void> _runUpload(Future<String?> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await action();
    if (!mounted || error == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error)));
  }

  Widget _mediaSection(EditProfileProvider p) => _Section(
    title: 'Photos',
    children: [
      _AvatarRow(
        url: p.avatarUrl,
        busy: p.uploading == ProfileMediaTarget.avatar,
        onChange: () => _runUpload(p.pickAndUploadAvatar),
      ),
      _MediaRow(
        label: 'Cover photo',
        url: p.backgroundImageUrl,
        busy: p.uploading == ProfileMediaTarget.cover,
        onChange: () => _runUpload(p.pickAndUploadCover),
      ),
    ],
  );

  Widget _documentsSection(EditProfileProvider p) => _Section(
    title: 'Verification documents',
    children: [
      for (final kind in _documentKindsFor(p))
        _MediaRow(
          label: _documentLabel(kind),
          url: kind == ProfileDocumentKind.companyLogo
              ? p.companyLogoUrl
              : p.documentUrl(kind),
          busy: p.uploading == ProfileMediaTarget.document(kind),
          onChange: () => _runUpload(() => p.pickAndUploadDocument(kind)),
        ),
      Text(
        'Images only — PDF upload is not yet supported.',
        style: AppTextStyles.caption.copyWith(
          fontSize: 11.5,
          color: AppColors.textHint,
        ),
      ),
    ],
  );

  // ── Sections ──────────────────────────────────────────────────────────────

  Widget _basicSection(EditProfileProvider p) => _Section(
    title: 'Basic information',
    children: [
      _Field(
        label: 'Full name',
        controller: p.fullName,
        required: true,
        hint: 'Enter your full name',
      ),
      _PhoneField(provider: p),
      _ReadOnlyField(
        label: 'User type',
        value: p.userType?.isNotEmpty == true ? p.userType! : 'Not set',
        note: p.roleLocked ? 'Role cannot be changed once set.' : null,
      ),
      _Field(
        label: 'Username',
        controller: p.username,
        hint: 'Choose username',
      ),
      // EditProfile.tsx:634 hides these two for individuals.
      if (p.isBusinessRole) ...[
        _Dropdown(
          label: 'Gender',
          value: p.gender,
          options: mergeSingle(kGenderOptions, p.gender),
          onChanged: p.setGender,
        ),
        _DateField(label: 'Date of birth', value: p.dob, onChanged: p.setDob),
      ],
    ],
  );

  Widget _builderCompanySection(EditProfileProvider p) => _Section(
    title: 'Company details',
    children: [
      _Field(
        label: 'Company / agency name',
        controller: p.companyName,
        hint: 'e.g. Prestige Builders Ltd.',
      ),
      _Field(
        label: 'RERA / license number',
        controller: p.reraNumber,
        hint: 'e.g. MH12345678',
      ),
      _Dropdown(
        label: 'Company structure',
        value: p.companyType,
        options: mergeSingle(kCompanyTypeOptions, p.companyType),
        legacyOptions: kCompanyTypeOptions,
        onChanged: p.setCompanyType,
      ),
      _Field(label: 'Base city', controller: p.city, hint: 'e.g. Mumbai'),
      _Field(
        label: 'Years of experience',
        controller: p.yearsExperience,
        keyboardType: TextInputType.number,
        hint: 'e.g. 10',
      ),
      _Field(
        label: 'Website URL',
        controller: p.website,
        hint: 'e.g. www.yourcompany.com',
      ),
      _Field(
        label: 'GST number',
        controller: p.gstNumber,
        hint: '15-digit GSTIN',
      ),
      _Field(
        label: 'PAN number',
        controller: p.panNumber,
        hint: '10-digit PAN',
      ),
      _Field(
        label: 'About company',
        controller: p.bio,
        maxLines: 4,
        hint: 'Describe your company, expertise, or property offerings…',
      ),
    ],
  );

  Widget _brokerProfessionalSection(EditProfileProvider p) => _Section(
    title: 'Professional details',
    children: [
      _Field(
        label: 'Company name',
        controller: p.companyName,
        hint: 'e.g. Dream Realty Services',
      ),
      _Dropdown(
        label: 'Broker type',
        value: p.brokerType,
        options: mergeSingle(kBrokerTypeOptions, p.brokerType),
        legacyOptions: kBrokerTypeOptions,
        onChanged: p.setBrokerType,
      ),
      _Field(
        label: 'RERA / license number',
        controller: p.reraNumber,
        hint: 'e.g. MH12345678',
      ),
      _Field(label: 'City', controller: p.city, hint: 'e.g. Mumbai'),
      _Field(
        label: 'Years of experience',
        controller: p.yearsExperience,
        keyboardType: TextInputType.number,
        hint: 'e.g. 5',
      ),
      _Field(
        label: 'Website URL',
        controller: p.website,
        hint: 'e.g. www.youragency.com',
      ),
      _Field(
        label: 'About your agency',
        controller: p.bio,
        maxLines: 4,
        hint: 'Years in the market, specialisations…',
      ),
    ],
  );

  Widget _brokerDealsSection(EditProfileProvider p) => _Section(
    title: 'Deals & expertise',
    children: [
      // Decision 5.2 — previously write-once at registration.
      _ChipGroup(
        label: 'Property types you deal in',
        group: ProfileChipGroup.propertyTypes,
        canonical: kPropertyTypeOptions,
        provider: p,
      ),
      _ChipGroup(
        label: 'Areas of expertise',
        group: ProfileChipGroup.areasOfExpertise,
        canonical: kExpertiseOptions,
        provider: p,
      ),
      _ChipGroup(
        label: 'Languages known',
        group: ProfileChipGroup.languagesKnown,
        canonical: kLanguageOptions,
        provider: p,
      ),
      _Field(
        label: 'Commission details',
        controller: p.commissionDetails,
        maxLines: 2,
        hint: 'e.g. 2% on sale, 1 month rent on rental',
      ),
      _Field(
        label: 'Price range — minimum (₹)',
        controller: p.priceRangeMin,
        keyboardType: TextInputType.number,
      ),
      _Field(
        label: 'Price range — maximum (₹)',
        controller: p.priceRangeMax,
        keyboardType: TextInputType.number,
      ),
    ],
  );

  Widget _builderDetailsSection(EditProfileProvider p) => _Section(
    title: 'Builder details',
    children: [
      _ChipGroup(
        label: 'Areas of expertise',
        group: ProfileChipGroup.areasOfExpertise,
        canonical: kExpertiseOptions,
        provider: p,
      ),
      _ChipGroup(
        label: 'Languages known',
        group: ProfileChipGroup.languagesKnown,
        canonical: kLanguageOptions,
        provider: p,
      ),
    ],
  );

  Widget _influencerProfileSection(EditProfileProvider p) => _Section(
    title: 'Influencer profile',
    children: [
      _Dropdown(
        label: 'Category',
        value: p.category,
        options: mergeSingle(kInfluencerCategoryOptions, p.category),
        legacyOptions: kInfluencerCategoryOptions,
        onChanged: p.setCategory,
      ),
      _Dropdown(
        label: 'Primary platform',
        value: p.primaryPlatform,
        options: mergeSingle(kPrimaryPlatformOptions, p.primaryPlatform),
        legacyOptions: kPrimaryPlatformOptions,
        onChanged: p.setPrimaryPlatform,
      ),
      _Field(
        label: 'Years of experience',
        controller: p.yearsExperience,
        keyboardType: TextInputType.number,
        hint: 'e.g. 3',
      ),
      // Free text on the portal, a dropdown in the wizard. The portal wins.
      _Field(
        label: 'Audience type',
        controller: p.audienceType,
        hint: 'e.g. Luxury Seekers, First-time Buyers',
      ),
      _Field(
        label: 'Website / portfolio',
        controller: p.website,
        hint: 'e.g. www.yourportfolio.com',
      ),
      _ChipGroup(
        label: 'Languages known',
        group: ProfileChipGroup.languagesKnown,
        canonical: kLanguageOptions,
        provider: p,
      ),
      _Field(
        label: 'Bio',
        controller: p.bio,
        maxLines: 4,
        hint: 'Your content niche, platform metrics, collaborating brands…',
      ),
    ],
  );

  Widget _influencerSocialSection(EditProfileProvider p) => _Section(
    title: 'Social media & metrics',
    children: [
      _Field(label: 'Instagram', controller: p.instagram),
      _Field(
        label: 'Instagram followers',
        controller: p.instagramFollowers,
        keyboardType: TextInputType.number,
      ),
      _Field(label: 'YouTube', controller: p.youtube),
      _Field(
        label: 'YouTube subscribers',
        controller: p.youtubeSubscribers,
        keyboardType: TextInputType.number,
      ),
      _Field(label: 'Facebook', controller: p.facebook),
      _Field(label: 'LinkedIn', controller: p.linkedin),
      _Field(label: 'WhatsApp', controller: p.whatsapp),
      _Field(label: 'Telegram', controller: p.telegram),
      _Field(label: 'Twitter / X', controller: p.twitter),
    ],
  );

  Widget _influencerContentSection(EditProfileProvider p) => _Section(
    title: 'Content & promotion',
    children: [
      _ChipGroup(
        label: 'Content types',
        group: ProfileChipGroup.contentTypes,
        canonical: kContentTypeOptions,
        provider: p,
      ),
      _ChipGroup(
        label: 'Preferred promotion types',
        group: ProfileChipGroup.promotionTypes,
        canonical: kPromotionTypeOptions,
        provider: p,
      ),
      // Decision 5.2 — previously write-once at registration.
      _Field(
        label: 'Portfolio links',
        controller: p.portfolioLinks,
        maxLines: 3,
        hint: 'One link per line',
      ),
      _Field(
        label: 'Previous brand collaborations',
        controller: p.previousCollaborations,
        maxLines: 3,
        hint: 'One per line',
      ),
    ],
  );

  Widget _addressSection(EditProfileProvider p, {required String title}) =>
      _Section(
        title: title,
        children: [
          _Field(
            label: 'Address',
            controller: p.officeAddress,
            maxLines: 2,
            hint: 'Enter full address',
          ),
          _Field(
            label: 'Landmark',
            controller: p.landmark,
            hint: 'e.g. Near metro station',
          ),
          _Field(label: 'State', controller: p.state, hint: 'e.g. Maharashtra'),
          _Field(
            label: 'Pincode',
            controller: p.pincode,
            keyboardType: TextInputType.number,
            hint: '6-digit pincode',
          ),
          _Field(
            label: 'Alternate mobile',
            controller: p.alternateMobile,
            keyboardType: TextInputType.phone,
          ),
          _Field(
            label: 'Business email',
            controller: p.email,
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      );

  Widget _socialSection(EditProfileProvider p) => _Section(
    title: 'Social media',
    children: [
      _Field(label: 'Facebook', controller: p.facebook),
      _Field(label: 'Instagram', controller: p.instagram),
      _Field(label: 'LinkedIn', controller: p.linkedin),
      _Field(label: 'YouTube', controller: p.youtube),
      _Field(label: 'WhatsApp', controller: p.whatsapp),
      _Field(label: 'Telegram', controller: p.telegram),
    ],
  );

  Widget _individualNote() => DashboardCard(
    child: Text(
      'Individual profiles need only the basics above.',
      style: AppTextStyles.caption.copyWith(fontSize: 12.5),
    ),
  );
}

/// Avatar preview + change action.
class _AvatarRow extends StatelessWidget {
  final String? url;
  final bool busy;
  final VoidCallback onChange;

  const _AvatarRow({
    required this.url,
    required this.busy,
    required this.onChange,
  });

  /// A row whose stored value is the R1 placeholder is treated as having no photo.
  ///
  /// `ProfileService.saveBuilderProfile` writes the literal string
  /// `'placeholder_profile.jpg'` into `avatar_url` at registration (defect R1,
  /// out of scope). Rendering it would attempt to load a relative path as a URL
  /// and show a broken image; treating it as absent shows the placeholder circle
  /// and invites the user to upload — which also repairs the row.
  bool get _hasPhoto =>
      url != null &&
      url!.isNotEmpty &&
      !url!.endsWith('placeholder_profile.jpg') &&
      !url!.endsWith('placeholder_logo.jpg');

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppColors.primaryLight,
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: _hasPhoto
                ? Image.network(
                    url!,
                    fit: BoxFit.cover,
                    width: 64,
                    height: 64,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.primary,
                  ),
          ),
        ),
        const SizedBox(width: AppConstants.spacingL),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile photo',
                style: AppTextStyles.body.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _hasPhoto ? 'Uploaded' : 'No photo yet',
                style: AppTextStyles.caption.copyWith(fontSize: 11.5),
              ),
            ],
          ),
        ),
        _UploadButton(busy: busy, onTap: onChange),
      ],
    );
  }
}

/// A labelled upload row with an uploaded/not-yet state.
class _MediaRow extends StatelessWidget {
  final String label;
  final String? url;
  final bool busy;
  final VoidCallback onChange;

  const _MediaRow({
    required this.label,
    required this.url,
    required this.busy,
    required this.onChange,
  });

  bool get _has =>
      url != null &&
      url!.isNotEmpty &&
      !url!.endsWith('placeholder_logo.jpg') &&
      !url!.endsWith('placeholder_profile.jpg');

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _has ? AppColors.primaryLight : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _has ? Icons.check_rounded : Icons.upload_file_outlined,
            size: 18,
            color: _has ? AppColors.primary : AppColors.textHint,
          ),
        ),
        const SizedBox(width: AppConstants.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _has ? 'Uploaded' : 'Not uploaded',
                style: AppTextStyles.caption.copyWith(fontSize: 11.5),
              ),
            ],
          ),
        ),
        _UploadButton(busy: busy, onTap: onChange),
      ],
    );
  }
}

class _UploadButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onTap;

  const _UploadButton({required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        width: 44,
        height: 36,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Upload',
      child: ExcludeSemantics(
        child: ScaleTap(
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
            ),
            child: Center(
              child: Text(
                'Change',
                style: AppTextStyles.chip.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form primitives
// ─────────────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardSectionLabel(title),
          const SizedBox(height: AppConstants.spacingM),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: AppConstants.spacingM),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Ordinary `InputDecoration` so `AppTheme.inputDecorationTheme` applies — this
/// form deliberately does NOT use a custom container, which is what would require
/// the six-slot border override documented in `search_bar_widget.dart`.
class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.required = false,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label, required: required),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: AppTextStyles.body.copyWith(fontSize: 14),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;

  const _FieldLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      required ? '$label *' : label,
      style: AppTextStyles.caption.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final String? note;

  const _ReadOnlyField({required this.label, required this.value, this.note});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
          ),
          child: Text(
            value,
            style: AppTextStyles.body.copyWith(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(
            note!,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              color: AppColors.textHint,
            ),
          ),
        ],
      ],
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;

  /// The canonical set. Anything in [options] outside it is flagged as legacy.
  final List<String>? legacyOptions;
  final ValueChanged<String?> onChanged;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.legacyOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          style: AppTextStyles.body.copyWith(fontSize: 14),
          decoration: const InputDecoration(hintText: 'Select'),
          items: [
            for (final option in options)
              DropdownMenuItem(
                value: option,
                child: Text(
                  legacyOptions != null && isLegacyValue(legacyOptions!, option)
                      ? '$option  (existing)'
                      : option,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final parsed = value == null ? null : DateTime.tryParse(value!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        const SizedBox(height: 6),
        ScaleTap(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: parsed ?? DateTime(now.year - 30),
              firstDate: DateTime(1940),
              lastDate: now,
            );
            if (picked != null) {
              // ISO `yyyy-MM-dd`, matching what the portal's date input stores.
              onChanged(
                '${picked.year.toString().padLeft(4, '0')}-'
                '${picked.month.toString().padLeft(2, '0')}-'
                '${picked.day.toString().padLeft(2, '0')}',
              );
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value == null || value!.isEmpty ? 'Select date' : value!,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 14,
                      color: value == null || value!.isEmpty
                          ? AppColors.textHint
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: AppColors.textHint,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PhoneField extends StatelessWidget {
  final EditProfileProvider provider;

  const _PhoneField({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(label: 'Phone number', required: true),
        const SizedBox(height: 6),
        Row(
          children: [
            SizedBox(
              width: 104,
              child: DropdownButtonFormField<String>(
                initialValue: provider.countryCode,
                isExpanded: true,
                style: AppTextStyles.body.copyWith(fontSize: 14),
                items: [
                  for (final entry in kCountryCodes)
                    DropdownMenuItem(
                      value: entry.code,
                      child: Text(entry.code, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) provider.countryCode = v;
                },
              ),
            ),
            const SizedBox(width: AppConstants.spacingS),
            Expanded(
              child: TextField(
                controller: provider.phone,
                keyboardType: TextInputType.phone,
                style: AppTextStyles.body.copyWith(fontSize: 14),
                decoration: const InputDecoration(hintText: 'Phone number'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A wrap of selectable chips.
///
/// Renders `mergeSelection(canonical, stored)`, so a value written by the
/// registration wizard that is absent from the React vocabulary still appears and
/// stays selected (approved decision 5.1). Legacy chips are marked, and once
/// removed they cannot be re-added — which is the point: the canonical vocabulary
/// is where the profile should end up.
class _ChipGroup extends StatelessWidget {
  final String label;
  final ProfileChipGroup group;
  final List<String> canonical;
  final EditProfileProvider provider;

  const _ChipGroup({
    required this.label,
    required this.group,
    required this.canonical,
    required this.provider,
  });

  List<String> _selectedFor() {
    switch (group) {
      case ProfileChipGroup.areasOfExpertise:
        return provider.areasOfExpertise;
      case ProfileChipGroup.languagesKnown:
        return provider.languagesKnown;
      case ProfileChipGroup.contentTypes:
        return provider.contentTypes;
      case ProfileChipGroup.promotionTypes:
        return provider.promotionTypes;
      case ProfileChipGroup.propertyTypes:
        return provider.propertyTypes;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedFor();
    final chips = mergeSelection(canonical, selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        const SizedBox(height: AppConstants.spacingS),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in chips)
              _SelectableChip(
                label: value,
                isSelected: selected.contains(value),
                isLegacy: isLegacyValue(canonical, value),
                onTap: () => provider.toggleChip(group, value),
              ),
          ],
        ),
      ],
    );
  }
}

class _SelectableChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isLegacy;
  final VoidCallback onTap;

  const _SelectableChip({
    required this.label,
    required this.isSelected,
    required this.isLegacy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isSelected ? AppColors.primary : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: isLegacy ? '$label, existing value' : label,
      child: ExcludeSemantics(
        child: ScaleTap(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryLight
                  : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppConstants.pillRadius),
              border: isLegacy
                  ? Border.all(color: AppColors.warning, width: 1)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  Icon(Icons.check_rounded, size: 14, color: fg),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.chip.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: fg,
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
}

class _SaveBar extends StatelessWidget {
  final bool saving;
  final VoidCallback onSave;

  const _SaveBar({required this.saving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppConstants.spacingL,
        right: AppConstants.spacingL,
        top: 10,
        bottom: 10 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(top: BorderSide(color: AppColors.textHint, width: 0.5)),
      ),
      child: AppActionButton(
        label: saving ? 'Saving…' : 'Update profile',
        variant: AppActionButtonVariant.solid,
        elevated: true,
        height: 46,
        onTap: saving ? null : onSave,
      ),
    );
  }
}
