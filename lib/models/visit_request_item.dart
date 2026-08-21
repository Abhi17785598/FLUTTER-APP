// models/visit_request_item.dart
//
// One row in "My Visits" — a merge of the three tables the portal's own
// `MyVisitRequests.tsx` reads: `property_visit_bookings`,
// `project_visit_bookings`, and `profile_visit_requests`. There is no
// Upcoming/Completed split in the reference — every status (`pending`,
// `confirmed`, `completed`, `cancelled`, `rescheduled`) shows in one list,
// distinguished only by a status badge (MyVisitRequests.tsx:28-34).

enum VisitRequestSource { property, project, profile }

class VisitRequestItem {
  final VisitRequestSource source;

  /// The id to navigate to on tap: a property id, a project id, or a user
  /// id, depending on [source] — mirrors the portal's `target_id`
  /// (MyVisitRequests.tsx:102,115,130).
  final String targetId;

  final String title;
  final String? imageUrl;
  final String location;
  final String? preferredDate;
  final String? preferredTime;
  final String status;
  final DateTime? createdAt;

  const VisitRequestItem({
    required this.source,
    required this.targetId,
    required this.title,
    required this.location,
    required this.status,
    this.imageUrl,
    this.preferredDate,
    this.preferredTime,
    this.createdAt,
  });
}
