// core/constants/influencer_video_options.dart
//
// The vocabulary of the influencer video form, taken from the portal's
// `InfluencerVideoModal.tsx`.
//
// `video_type` is the only one of these the database constrains:
//
//   video_type TEXT NOT NULL CHECK (video_type IN
//     ('property_listing', 'property_news', 'property_education'))
//
// — 20250828001551_a8c692e2…sql:14. The modal offers exactly those three
// (InfluencerVideoModal.tsx:47-50), titles and descriptions included, so this is a
// straight transcription rather than a choice.
//
// `status` is CHECK-constrained to ('active','inactive','pending') and defaults to
// 'active'; `approval_status` is a bare text column defaulting to 'pending', added
// later by 20251213104811. Neither is offered as a control anywhere in the portal's
// influencer flow — the modal writes `approval_status: 'pending'` and never touches
// `status` — so this file only supplies their *labels*.

/// One selectable video type, with the copy the portal shows beside it.
class InfluencerVideoType {
  const InfluencerVideoType({
    required this.id,
    required this.title,
    required this.description,
  });

  /// The exact string written to `influencer_videos.video_type`.
  final String id;

  /// The radio row's heading.
  final String title;

  /// The one-line explanation under it.
  final String description;
}

/// The three CHECK values, in the modal's order (InfluencerVideoModal.tsx:47-50).
const List<InfluencerVideoType> kInfluencerVideoTypes = [
  InfluencerVideoType(
    id: 'property_listing',
    title: 'Property Listing Video',
    description: 'Showcase a specific property',
  ),
  InfluencerVideoType(
    id: 'property_news',
    title: 'Property News',
    description: 'Share market updates and news',
  ),
  InfluencerVideoType(
    id: 'property_education',
    title: 'Property Education',
    description: 'Educational content about real estate',
  ),
];

/// Whether [id] is one of the three the CHECK constraint accepts.
///
/// Guards the payload rather than the picker: a value from outside this list is a
/// `23514`, so it is worth refusing before the round trip.
bool isValidInfluencerVideoType(String? id) =>
    kInfluencerVideoTypes.any((t) => t.id == id);

/// Title-cased label for a stored `video_type`.
///
/// Falls back to the raw value with underscores expanded, which is what the portal
/// renders (`video.video_type.replace('_', ' ')` with a `capitalize` class,
/// InfluencerContentManager.tsx:188-190).
String influencerVideoTypeLabel(String? id) {
  for (final type in kInfluencerVideoTypes) {
    if (type.id == id) return type.title;
  }
  final raw = (id ?? '').replaceAll('_', ' ').trim();
  if (raw.isEmpty) return 'Video';
  return raw
      .split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// Label for `approval_status`, matching `getApprovalBadge`
/// (InfluencerContentManager.tsx:118-127). Anything unrecognised — including the
/// NULL that pre-20251213 rows can still hold — reads as pending review.
String influencerApprovalLabel(String? approvalStatus) =>
    switch (approvalStatus) {
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      _ => 'Pending Review',
    };

/// Label for `status`, matching `getStatusBadge`
/// (InfluencerContentManager.tsx:100-113). The portal prints the raw value; these
/// are its title-cased forms, since the app capitalises its badges everywhere else.
String influencerVideoStatusLabel(String? status) => switch (status) {
  'active' => 'Active',
  'inactive' => 'Inactive',
  'pending' => 'Pending',
  _ => 'Draft',
};

/// Splits a comma-separated hashtag field the way the portal does.
///
/// `InfluencerVideoModal.tsx:154-158`, step for step: split on commas, trim,
/// lowercase, strip one leading `#`, drop the empties. Note what it does *not* do —
/// no deduplication, no length cap, no character filtering — so neither does this.
/// A user who types `#Pune, pune` gets two identical tags on both platforms.
List<String> parseInfluencerHashtags(String raw) => raw
    .split(',')
    .map((tag) => tag.trim().toLowerCase())
    .map((tag) => tag.startsWith('#') ? tag.substring(1) : tag)
    .where((tag) => tag.isNotEmpty)
    .toList(growable: false);

/// Renders a stored hashtag list back into the form's single text field.
///
/// The inverse of [parseInfluencerHashtags], and the portal's own edit seed:
/// `editingVideo?.hashtags?.join(', ')` (InfluencerVideoModal.tsx:32).
String joinInfluencerHashtags(List<String> hashtags) => hashtags.join(', ');
