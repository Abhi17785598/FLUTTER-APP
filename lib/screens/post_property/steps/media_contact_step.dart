import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/wizard_kit.dart';
import '../../../providers/post_property_provider.dart';

/// Step 8: local media selection (no upload — files stay on-device until a
/// backend integration phase), contact details and hashtags. Mirrors the
/// React MediaAndFinalStep's fields, minus the actual upload/submission.
class MediaContactStep extends StatefulWidget {
  const MediaContactStep({super.key});

  @override
  State<MediaContactStep> createState() => _MediaContactStepState();
}

class _MediaContactStepState extends State<MediaContactStep> {
  static const _categories = [
    ('interior', 'Interior'),
    ('exterior', 'Exterior'),
    ('amenities', 'Amenities'),
    ('floor_plan', 'Floor Plan'),
    ('other', 'Other'),
  ];

  final ImagePicker _picker = ImagePicker();
  String _selectedCategory = 'interior';

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

  Future<void> _pickFromGallery() async {
    final images = await _picker.pickMultiImage();
    if (!mounted || images.isEmpty) return;
    final provider = context.read<PostPropertyProvider>();
    for (final image in images) {
      provider.addMediaItem(image, _selectedCategory);
    }
  }

  Future<void> _pickFromCamera() async {
    final image = await _picker.pickImage(source: ImageSource.camera);
    if (!mounted || image == null) return;
    context.read<PostPropertyProvider>().addMediaItem(image, _selectedCategory);
  }

  String _categoryLabel(String id) {
    return _categories.firstWhere((c) => c.$1 == id, orElse: () => (id, id)).$2;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostPropertyProvider>();
    final isPg = provider.category == PropertyCategory.pg;

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
                  options: _categories.map((c) => c.$2).toList(),
                  selected: _categoryLabel(_selectedCategory),
                  onSelected: (label) {
                    setState(() {
                      _selectedCategory = _categories.firstWhere((c) => c.$2 == label).$1;
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
                ],
              ),
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
                                child: Image.file(
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
                          _categoryLabel(item.category),
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
