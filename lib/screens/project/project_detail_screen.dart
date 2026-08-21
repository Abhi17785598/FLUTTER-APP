// screens/project/project_detail_screen.dart
//
// One builder project. The display half of the portal's `ProjectDetails.tsx`.
//
// WHAT IS PORTED, AND WHAT IS NOT
// ------------------------------
// Ported: the project read, the builder-profile read with its auth-aware column
// list, the flattened media gallery (`getAllMedia`, :637-644), every field the
// page shows, and like/save (`user_likes.project_id` / `saved_projects`, via
// `ProjectsProvider` — the gallery header's heart/bookmark actions).
//
// Not ported, each because it is a different table and a later phase:
//   * comments — `comments` plus a realtime subscription
//   * "Book a visit" — `project_visit_bookings`, phase B7
//   * admin approve — an `approval_status` write, admin-only
// A correct read-only page now beats a half-wired social one.
//
// OWNER VS VISITOR
// ----------------
// The owner gets Edit and Delete, and is the only one shown the pending-
// verification badge. A visitor sees the project as a buyer would. Note the
// public read policy is `USING (status = 'active')` **alone**, so an unapproved
// project is publicly visible the moment it is created — telling a visitor it is
// unreviewed would advertise exactly that, so the badge stays owner-only.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/empty_state_view.dart';
import '../../models/project_model.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/projects_provider.dart';
import '../../services/project_service.dart';
import '../../services/user_profile_service.dart';
import '../dashboard/widgets/my_projects_section.dart'
    show ProjectStatusPill, projectPriceRangeLabel;

/// Height of the media header.
const double _kGalleryHeight = 260;

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    this.service,
    this.profileService,
  });

  final String projectId;

  /// Injected by tests.
  @visibleForTesting
  final ProjectService? service;

  /// Injected by tests.
  @visibleForTesting
  final UserProfileService? profileService;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late final ProjectService _projects = widget.service ?? ProjectService();
  late final UserProfileService _profiles =
      widget.profileService ?? UserProfileService();

  ProjectModel? _project;
  UserProfile? _builder;
  bool _loading = true;
  bool _failed = false;

  /// True when the row simply is not there — or is not visible, which for a
  /// non-owner means its status is not `active`. Both read as "not available"
  /// rather than as an error the user could retry away.
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
      _notFound = false;
    });

    try {
      final project = await _projects.fetchById(widget.projectId);
      if (!mounted) return;

      if (project == null) {
        setState(() {
          _loading = false;
          _notFound = true;
        });
        return;
      }

      setState(() {
        _project = project;
        _loading = false;
      });

      // Second round-trip, deliberately after the project is painted: the page
      // is complete without the builder's name, and blocking on it would delay
      // everything for a byline.
      await _loadBuilder(project.builderId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  /// The builder's name and avatar.
  ///
  /// Failure is swallowed — the page keeps working without a byline, which is
  /// what the portal does too (it only logs).
  Future<void> _loadBuilder(String builderId) async {
    if (builderId.isEmpty) return;
    try {
      final signedIn = context.read<AuthProvider>().isLoggedIn;
      final profile = await _profiles.fetchPublic(
        builderId,
        viewerSignedIn: signedIn,
      );
      if (!mounted) return;
      setState(() => _builder = profile);
    } catch (_) {
      // Intentionally silent.
    }
  }

  bool get _isOwner {
    final project = _project;
    if (project == null) return false;
    final viewerId = context.read<AuthProvider>().userId;
    return viewerId != null && viewerId == project.builderId;
  }

  Future<void> _openLink(String url, String failureMessage) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failureMessage),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _edit() async {
    final project = _project;
    if (project == null) return;
    final saved = await Navigator.pushNamed(
      context,
      AppConstants.addProjectScreen,
      arguments: {'project': project},
    );
    if (saved == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_notFound) {
      return _Shell(
        child: Center(
          child: EmptyStateView(
            icon: Icons.apartment_outlined,
            title: 'Project not available',
            message: 'This project may have been removed or is not published.',
            actionLabel: 'Go back',
            onAction: () => Navigator.of(context).maybePop(),
          ),
        ),
      );
    }

    if (_failed || _project == null) {
      return _Shell(
        child: Center(
          child: EmptyStateView(
            icon: Icons.cloud_off_rounded,
            title: "Couldn't load this project",
            message: 'Check your connection and try again.',
            actionLabel: 'Retry',
            onAction: _load,
          ),
        ),
      );
    }

    final project = _project!;
    final projectsProvider = context.watch<ProjectsProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _GalleryHeader(
            images: project.galleryImages,
            onBack: () => Navigator.of(context).maybePop(),
            isLiked: projectsProvider.isLiked(project.id),
            isSaved: projectsProvider.isSaved(project.id),
            onToggleLike: () =>
                projectsProvider.toggleLike(project.id, project: project),
            onToggleSave: () =>
                projectsProvider.toggleSave(project.id, project: project),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(project: project, isOwner: _isOwner),
                  const SizedBox(height: AppConstants.spacingL),
                  _KeyFacts(project: project),
                  if (project.description.isNotEmpty) ...[
                    const SizedBox(height: AppConstants.spacingXL),
                    const _SectionTitle('About this project'),
                    const SizedBox(height: 8),
                    Text(
                      project.description,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13.5,
                        height: 1.6,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (project.amenities.isNotEmpty) ...[
                    const SizedBox(height: AppConstants.spacingXL),
                    const _SectionTitle('Amenities'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final amenity in project.amenities)
                          _AmenityChip(label: amenity),
                      ],
                    ),
                  ],
                  if (project.mapImages.isNotEmpty) ...[
                    const SizedBox(height: AppConstants.spacingXL),
                    const _SectionTitle('Master plan'),
                    const SizedBox(height: 10),
                    _LayoutStrip(images: project.mapImages),
                  ],
                  if (project.videosUrls.isNotEmpty) ...[
                    const SizedBox(height: AppConstants.spacingXL),
                    const _SectionTitle('Videos'),
                    const SizedBox(height: 10),
                    _VideoLinks(
                      urls: project.videosUrls,
                      onOpen: (url) =>
                          _openLink(url, 'Could not open that video.'),
                    ),
                  ],
                  const SizedBox(height: AppConstants.spacingXL),
                  _ContactCard(
                    project: project,
                    builder: _builder,
                    onOpenWebsite: () => _openLink(
                      project.websiteUrl,
                      'Could not open that website.',
                    ),
                    onOpenBrochure: () => _openLink(
                      project.brochureUrl,
                      'Could not open the brochure.',
                    ),
                    onOpenBuilder: _builder == null
                        ? null
                        : () => Navigator.pushNamed(
                              context,
                              AppConstants.publicProfileScreen,
                              arguments: {'userId': project.builderId},
                            ),
                  ),
                  // Owner-only. Delete lives on the dashboard card, not here:
                  // deleting the row you are looking at would leave this screen
                  // showing a project that no longer exists.
                  if (_isOwner) ...[
                    const SizedBox(height: AppConstants.spacingXL),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _edit,
                        icon: const Icon(Icons.edit_outlined, size: 17),
                        label: const Text('Edit Project'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppConstants.buttonRadius,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Plain scaffold with a back affordance, for the two terminal states.
class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: child,
      );
}

class _GalleryHeader extends StatefulWidget {
  const _GalleryHeader({
    required this.images,
    required this.onBack,
    required this.isLiked,
    required this.isSaved,
    required this.onToggleLike,
    required this.onToggleSave,
  });

  final List<String> images;
  final VoidCallback onBack;

  /// Like — backed by `user_likes.project_id`, a separate action from Save
  /// below, mirroring the property detail screen's Like/Save split
  /// (`property_detail_screen.dart`'s `_buildTopActions`: Heart = Like,
  /// Bookmark = Save, never two hearts).
  final bool isLiked;

  /// Save/Shortlist — backed by `saved_projects`.
  final bool isSaved;

  final VoidCallback onToggleLike;
  final VoidCallback onToggleSave;

  @override
  State<_GalleryHeader> createState() => _GalleryHeaderState();
}

class _GalleryHeaderState extends State<_GalleryHeader> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;

    return SliverAppBar(
      expandedHeight: _kGalleryHeight,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: widget.onBack,
      ),
      actions: [
        IconButton(
          icon: Icon(
            widget.isLiked ? Icons.favorite : Icons.favorite_border,
            color: widget.isLiked ? Colors.red : Colors.white,
          ),
          onPressed: widget.onToggleLike,
        ),
        IconButton(
          icon: Icon(
            widget.isSaved ? Icons.bookmark : Icons.bookmark_border,
            color: Colors.white,
          ),
          onPressed: widget.onToggleSave,
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (images.isEmpty)
              const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.heroGradient),
                child: Center(
                  child: Icon(
                    Icons.apartment_rounded,
                    size: 54,
                    color: Colors.white54,
                  ),
                ),
              )
            else
              PageView.builder(
                controller: _controller,
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => CachedNetworkImage(
                  imageUrl: images[i],
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const ColoredBox(
                    color: AppColors.primaryLight,
                  ),
                  errorWidget: (_, _, _) => const DecoratedBox(
                    decoration: BoxDecoration(gradient: AppColors.heroGradient),
                  ),
                ),
              ),
            // Keeps the back button and the counter legible over any photo.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x66000000), Color(0x00000000)],
                  stops: [0, 0.4],
                ),
              ),
            ),
            if (images.length > 1)
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius:
                        BorderRadius.circular(AppConstants.pillRadius),
                  ),
                  child: Text(
                    '${_page + 1} / ${images.length}',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.project, required this.isOwner});

  final ProjectModel project;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          project.title,
          style: AppTextStyles.heading1.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 14,
                color: AppColors.textHint),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                project.location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _TypePill(label: project.typeLabel),
            ProjectStatusPill(status: project.status),
            // See the file header: owner-only, on purpose.
            if (isOwner && project.isPendingApproval)
              const _WarnPill(label: 'Pending verification'),
          ],
        ),
        if (project.hasPriceRange) ...[
          const SizedBox(height: 12),
          Text(
            projectPriceRangeLabel(project),
            style: AppTextStyles.heading2.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Units, sizes, dates and RERA, in one card.
class _KeyFacts extends StatelessWidget {
  const _KeyFacts({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    String? dateLabel(DateTime? value) {
      if (value == null) return null;
      return '${value.day.toString().padLeft(2, '0')}/'
          '${value.month.toString().padLeft(2, '0')}/${value.year}';
    }

    final facts = <(String, String)>[
      if (project.totalUnits > 0)
        ('Units', '${project.availableUnits} of ${project.totalUnits} available'),
      if (project.hasAreaRange)
        (
          'Unit sizes',
          project.areaSqftMin == project.areaSqftMax
              ? '${project.areaSqftMax.toStringAsFixed(0)} sq ft'
              : '${project.areaSqftMin.toStringAsFixed(0)} – '
                  '${project.areaSqftMax.toStringAsFixed(0)} sq ft'
        ),
      if (dateLabel(project.completionDate) != null)
        ('Completion', dateLabel(project.completionDate)!),
      if (dateLabel(project.possessionDate) != null)
        ('Possession', dateLabel(project.possessionDate)!),
      if (project.reraNumber.isNotEmpty) ('RERA', project.reraNumber),
    ];

    if (facts.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        boxShadow: AppColors.surfaceCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < facts.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    facts[i].$1,
                    style: AppTextStyles.caption.copyWith(fontSize: 11.5),
                  ),
                ),
                Expanded(
                  child: Text(
                    facts[i].$2,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.project,
    required this.builder,
    required this.onOpenWebsite,
    required this.onOpenBrochure,
    required this.onOpenBuilder,
  });

  final ProjectModel project;
  final UserProfile? builder;
  final VoidCallback onOpenWebsite;
  final VoidCallback onOpenBrochure;
  final VoidCallback? onOpenBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        boxShadow: AppColors.surfaceCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Builder & contact'),
          const SizedBox(height: 12),
          if (builder != null)
            GestureDetector(
              onTap: onOpenBuilder,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: builder!.avatarUrl == null ||
                              builder!.avatarUrl!.isEmpty
                          ? Center(
                              child: Text(
                                builder!.initials,
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: builder!.avatarUrl!,
                              fit: BoxFit.cover,
                              width: 42,
                              height: 42,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      builder!.displayTitle ?? 'Builder',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppColors.textHint),
                ],
              ),
            ),
          if (project.contactNumber.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.phone_outlined,
              value: project.contactNumber,
            ),
          ],
          if (project.websiteUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            _LinkRow(
              icon: Icons.language_rounded,
              label: 'Visit website',
              onTap: onOpenWebsite,
            ),
          ],
          if (project.brochureUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            _LinkRow(
              icon: Icons.picture_as_pdf_outlined,
              label: 'Download brochure',
              onTap: onOpenBrochure,
            ),
          ],
        ],
      ),
    );
  }
}

class _LayoutStrip extends StatelessWidget {
  const _LayoutStrip({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
          child: CachedNetworkImage(
            imageUrl: images[i],
            width: 190,
            height: 130,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(
              width: 190,
              color: AppColors.primaryLight,
            ),
            errorWidget: (_, _, _) => Container(
              width: 190,
              color: AppColors.primaryLight,
              alignment: Alignment.center,
              child: const Icon(Icons.map_outlined,
                  color: AppColors.primary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Videos open externally.
///
/// The project gallery already carries the images; embedding a player per video
/// here would mean several controllers on one scrolling page. `url_launcher`
/// hands each to the device's own player.
class _VideoLinks extends StatelessWidget {
  const _VideoLinks({required this.urls, required this.onOpen});

  final List<String> urls;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < urls.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _LinkRow(
            icon: Icons.play_circle_outline_rounded,
            label: 'Play video ${i + 1}',
            onTap: () => onOpen(urls[i]),
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTextStyles.heading3.copyWith(fontSize: 15),
      );
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(AppConstants.pillRadius),
        ),
        child: Text(
          label,
          style: AppTextStyles.chip.copyWith(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      );
}

class _WarnPill extends StatelessWidget {
  const _WarnPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppConstants.pillRadius),
        ),
        child: Text(
          label,
          style: AppTextStyles.chip.copyWith(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.warning,
          ),
        ),
      );
}

class _AmenityChip extends StatelessWidget {
  const _AmenityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.pillRadius),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 15, color: AppColors.textHint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(fontSize: 13),
            ),
          ),
        ],
      );
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Icon(icon, size: 15, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            const Icon(Icons.open_in_new_rounded,
                size: 13, color: AppColors.primary),
          ],
        ),
      );
}
