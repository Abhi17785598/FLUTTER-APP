import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/wizard_kit.dart';
import '../../../providers/post_property_provider.dart';
import '../listing_constants.dart';

/// Step 8: local media selection (no upload — files stay on-device until a
/// backend integration phase), contact details and hashtags. Mirrors the
/// React MediaAndFinalStep's fields, minus the actual upload/submission.
class MediaContactStep extends StatefulWidget {
  const MediaContactStep({super.key});

  @override
  State<MediaContactStep> createState() => _MediaContactStepState();
}

class _MediaContactStepState extends State<MediaContactStep> {
  /// Photo categories for the current listing, straight from the T0
  /// constants. React swaps the whole set for land — Sajra / Land video /
  /// Land images / Others (MediaAndFinalStep.tsx:32).
  List<ListingOption> _categoriesFor(PropertyCategory? category) =>
      category == PropertyCategory.land
          ? kLandImageCategories
          : kDefaultImageCategories;

  final ImagePicker _picker = ImagePicker();
  String? _selectedCategoryId;

  /// Default category for newly added photos: the first of the active set,
  /// reset automatically when the category swap changes that set.
  String _activeCategory(List<ListingOption> options) {
    final id = _selectedCategoryId;
    if (id != null && options.any((o) => o.id == id)) return id;
    return options.first.id;
  }

  late final TextEditingController _contactNameController;
  late final TextEditingController _contactPhoneController;
  late final TextEditingController _contactEmailController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _bestTimeController;
  late final TextEditingController _hashtagsController;
  late final TextEditingController _ownerManagerNameController;
  late final TextEditingController _alternateNumberController;

  @override
  void initState() {
    super.initState();
    final p = context.read<PostPropertyProvider>();
    _contactNameController = TextEditingController(text: p.contactName);
    _contactPhoneController = TextEditingController(text: p.contactPhone);
    _contactEmailController = TextEditingController(text: p.contactEmail);
    _whatsappController = TextEditingController(text: p.whatsappNumber);
    _bestTimeController = TextEditingController(text: p.bestTimeToCall);
    _hashtagsController = TextEditingController(text: p.hashtags);
    _ownerManagerNameController = TextEditingController(text: p.text('ownerManagerName'));
    _alternateNumberController = TextEditingController(text: p.text('alternateNumber'));
  }

  @override
  void dispose() {
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    _whatsappController.dispose();
    _bestTimeController.dispose();
    _hashtagsController.dispose();
    _ownerManagerNameController.dispose();
    _alternateNumberController.dispose();
    super.dispose();
  }

  // React runs compressMedia() before upload; that implementation is
  // browser-only (canvas re-encoding + WebCodecs) and cannot be ported. The
  // equivalent on mobile is to let image_picker downscale and re-encode at
  // pick time, which keeps uploads to a sane size instead of sending a
  // full-resolution phone photo — Flutter previously applied no compression
  // at all.
  static const int _maxImageDimension = 1920;
  static const int _imageQuality = 82;
  // Portal's own hard ceiling (MediaAndFinalStep.tsx:74-77) — a rejected file
  // just isn't added, same as the portal's alert-and-skip behavior.
  static const int _maxFileBytes = 10 * 1024 * 1024;

  /// True once any file over the portal's 10MB ceiling was rejected —
  /// surfaced as a snackbar, the mobile equivalent of the portal's `alert()`.
  Future<bool> _tooLarge(XFile file) async {
    if (await file.length() <= _maxFileBytes) return false;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${file.name} is over 10MB and was skipped.')),
      );
    }
    return true;
  }

  Future<void> _pickFromGallery() async {
    final images = await _picker.pickMultiImage(
      maxWidth: _maxImageDimension.toDouble(),
      maxHeight: _maxImageDimension.toDouble(),
      imageQuality: _imageQuality,
    );
    if (!mounted || images.isEmpty) return;
    final provider = context.read<PostPropertyProvider>();
    final category = _activeCategory(_categoriesFor(provider.category));
    for (final image in images) {
      if (await _tooLarge(image)) continue;
      provider.addMediaItem(image, category);
    }
  }

  Future<void> _pickFromCamera() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: _maxImageDimension.toDouble(),
      maxHeight: _maxImageDimension.toDouble(),
      imageQuality: _imageQuality,
    );
    if (!mounted || image == null) return;
    if (await _tooLarge(image)) return;
    final provider = context.read<PostPropertyProvider>();
    provider.addMediaItem(
        image, _activeCategory(_categoriesFor(provider.category)));
  }

  /// The portal accepts `video/*` alongside images on the same picker
  /// (MediaAndFinalStep.tsx:222) — Flutter only ever exposed a "Property
  /// Video"/"Land video" category a user could tag a *photo* with, with no
  /// way to actually attach a video file.
  Future<void> _pickVideo() async {
    final video = await _picker.pickVideo(source: ImageSource.gallery);
    if (!mounted || video == null) return;
    if (await _tooLarge(video)) return;
    final provider = context.read<PostPropertyProvider>();
    final categories = _categoriesFor(provider.category);
    final videoCategory = categories.any((c) => c.id == 'property_video')
        ? 'property_video'
        : categories.any((c) => c.id == 'land_video')
            ? 'land_video'
            : _activeCategory(categories);
    provider.addMediaItem(video, videoCategory);
  }

  bool _isVideoCategory(String category) =>
      category == 'property_video' || category == 'land_video';

  String _categoryLabel(List<ListingOption> options, String id) {
    for (final o in options) {
      if (o.id == id) return o.label;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostPropertyProvider>();
    final isPg = provider.category == PropertyCategory.pg;
    final categories = _categoriesFor(provider.category);
    final activeCategory = _activeCategory(categories);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WizardCard(
          icon: Icons.photo_library_outlined,
          title: 'Property Images *',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add at least one image. No upload happens yet — images stay on this device.',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              WizardField(
                label: 'Category for new photos',
                child: WizardChipGroup(
                  options: categories.map((c) => c.label).toList(),
                  selected: _categoryLabel(categories, activeCategory),
                  onSelected: (label) {
                    setState(() {
                      _selectedCategoryId = categories
                          .firstWhere((c) => c.label == label)
                          .id;
                    });
                  },
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFromCamera,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Camera'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickVideo,
                      icon: const Icon(Icons.videocam_outlined),
                      label: const Text('Video'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Photos already on the listing. Without this, editing a
              // listing showed an empty picker even though it had images, the
              // user could not remove or re-tag any of them, and there was no
              // way to choose which one is the main display image.
              if (provider.existingMedia.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Current photos',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: provider.existingMedia.length,
                  itemBuilder: (context, index) {
                    final media = provider.existingMedia[index];
                    final isMain = provider.mainDisplayMediaUrl == media.url ||
                        (provider.mainDisplayMediaUrl.isEmpty &&
                            index == 0 &&
                            provider.existingMedia.isNotEmpty);
                    return Column(
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  media.url,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.broken_image),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => context
                                      .read<PostPropertyProvider>()
                                      .removeExistingMedia(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close,
                                        color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                left: 4,
                                child: GestureDetector(
                                  onTap: () => context
                                      .read<PostPropertyProvider>()
                                      .setMainDisplayMediaUrl(
                                          isMain ? '' : media.url),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isMain ? Icons.star : Icons.star_border,
                                      color: isMain
                                          ? Colors.amber
                                          : Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => context
                              .read<PostPropertyProvider>()
                              .setExistingMediaCategory(index, activeCategory),
                          child: Text(
                            _categoryLabel(categories, media.category),
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              decoration: TextDecoration.underline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
              if (provider.mediaItems.isNotEmpty) ...[
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: provider.mediaItems.length,
                  itemBuilder: (context, index) {
                    final item = provider.mediaItems[index];
                    return Column(
                      children: [
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _isVideoCategory(item.category)
                                    ? Container(
                                        color: Colors.grey.shade800,
                                        child: const Icon(
                                          Icons.play_circle_outline,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      )
                                    // `Image.file` needs `dart:io` file
                                    // access, unsupported on Flutter Web —
                                    // an `XFile`'s path on web is already a
                                    // `blob:` URL the browser can load
                                    // directly, so it goes through
                                    // `Image.network` there instead.
                                    : kIsWeb
                                        ? Image.network(
                                            item.file.path,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              color: Colors.grey.shade200,
                                              child: const Icon(Icons.broken_image),
                                            ),
                                          )
                                        : Image.file(
                                            File(item.file.path),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              color: Colors.grey.shade200,
                                              child: const Icon(Icons.broken_image),
                                            ),
                                          ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => context
                                      .read<PostPropertyProvider>()
                                      .removeMediaItem(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _categoryLabel(categories, item.category),
                          style: AppTextStyles.caption.copyWith(fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        WizardCard(
          icon: Icons.contact_phone_outlined,
          title: 'Contact Information',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPg) ...[
                WizardField(
                  label: 'PG Owner / Manager Name',
                  child: WizardTextField(
                    controller: _ownerManagerNameController,
                    hint: 'e.g., Rahul Sharma',
                    onChanged: (v) =>
                        context.read<PostPropertyProvider>().setText('ownerManagerName', v),
                  ),
                ),
                const WizardDivider(),
                WizardField(
                  label: 'Alternate Contact Number',
                  child: WizardTextField(
                    controller: _alternateNumberController,
                    hint: '+91 98765 00000',
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    onChanged: (v) =>
                        context.read<PostPropertyProvider>().setText('alternateNumber', v),
                  ),
                ),
                const WizardDivider(),
              ],
              WizardField(
                label: 'Contact Name *',
                child: WizardTextField(
                  controller: _contactNameController,
                  hint: 'Your full name',
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                  ],
                  onChanged: (v) => context.read<PostPropertyProvider>().setContactName(v),
                ),
              ),
              const WizardDivider(),
              Row(
                children: [
                  Expanded(
                    child: WizardField(
                      label: 'Phone Number *',
                      child: WizardTextField(
                        controller: _contactPhoneController,
                        hint: '+91 98765 43210',
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        onChanged: (v) =>
                            context.read<PostPropertyProvider>().setContactPhone(v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: WizardField(
                      label: 'Email Address *',
                      child: WizardTextField(
                        controller: _contactEmailController,
                        hint: 'your.email@example.com',
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (v) =>
                            context.read<PostPropertyProvider>().setContactEmail(v),
                      ),
                    ),
                  ),
                ],
              ),
              const WizardDivider(),
              Row(
                children: [
                  Expanded(
                    child: WizardField(
                      label: 'WhatsApp Number',
                      child: WizardTextField(
                        controller: _whatsappController,
                        hint: '+91 98765 43210',
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        onChanged: (v) =>
                            context.read<PostPropertyProvider>().setWhatsappNumber(v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: WizardField(
                      label: 'Best Time to Call',
                      child: WizardTextField(
                        controller: _bestTimeController,
                        hint: 'e.g., 10 AM - 6 PM',
                        onChanged: (v) =>
                            context.read<PostPropertyProvider>().setBestTimeToCall(v),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        WizardCard(
          icon: Icons.tag_outlined,
          title: 'Hashtags',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WizardTextField(
                controller: _hashtagsController,
                hint: '#modern #furnished #parking',
                onChanged: (v) => context.read<PostPropertyProvider>().setHashtags(v),
              ),
              const SizedBox(height: 8),
              Text(
                'Use hashtags to help property seekers find your property.',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
