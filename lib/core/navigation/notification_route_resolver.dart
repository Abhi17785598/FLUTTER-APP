// core/navigation/notification_route_resolver.dart
//
// Where tapping a notification goes — G-4.
//
// A transcription of `NotificationList.tsx:53-115`'s switch, which is the portal's
// only routing contract for notifications. Kept as a pure function returning a
// destination rather than as `Navigator` calls inside the list, so the whole table is
// testable without pumping a widget.
//
// THE IMPORTANT CONSTRAINT: MOST PAYLOADS CARRY NO ID
// ---------------------------------------------------
// `utils/notificationHelpers.ts` writes display strings, not identifiers. Its
// payloads are:
//
//   new_follower              { follower_name }                      ← no id
//   channel_addition          { channel_name, added_by }             ← no id
//   builder_network_addition  { sender_name, member_type }           ← no id
//   property_approved         { property_title }                     ← no id
//   property_inquiry          { property_title, inquirer_name }      ← no id
//   message_received          { sender_name, message_preview }       ← no id
//   channel_message           { channel_id, … }                      ← has one
//
// The portal handles this by routing to a *list* where an id is missing
// (`/chat`, `/networks/members`, `/manage-properties`) and to a detail page only when
// `data.follower_id` / `data.property_id` / `data.projectId` happens to be present —
// which, for rows its own helpers wrote, it never is. Those branches are effectively
// dead on the portal.
//
// This app's five writers are better in two cases and no worse anywhere:
//
//   project_shared            { projectId, projectTitle, builderName }   ← routable
//   builder_network_addition  { sender_id, sender_name[, member_type] }  ← routable
//   visit_booking_update      { title, status, date, time }              ← no id
//
// So the id-bearing branches are honoured when the key is there and fall back to the
// portal's list destination when it is not. Nothing here invents an id or guesses a
// destination from a display string.
import '../constants/app_constants.dart';

/// A resolved destination: a named route plus its arguments.
class NotificationDestination {
  const NotificationDestination(this.route, [this.arguments]);

  final String route;
  final Map<String, dynamic>? arguments;
}

/// Where [type] with [data] should open, or null for "nowhere".
///
/// Null is a first-class answer, not a failure. The portal's `default` branch is
/// `// For unknown types, just mark as read`, and several of its cases fall through
/// without navigating when the id is absent. A tap on one of those should still mark
/// the row read — which the caller does regardless — and simply not move the user.
///
/// `visit_booking_update` is the clearest example: both writers of it emit
/// `{title, status, date, time}` with no booking or property id, and there is no
/// portal case for it at all. Sending the user to a dashboard they did not ask for
/// would be worse than staying put.
NotificationDestination? resolveNotificationDestination({
  required String type,
  required Map<String, dynamic> data,
}) {
  String? id(String key) {
    final value = data[key];
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  switch (type) {
    // ── Detail when an id is present, list when it is not ──────────────────
    case 'new_follower':
      // `/user/${follower_id}` (`:63`). The portal's own helper does not write
      // `follower_id`, so this resolves only for rows written elsewhere.
      final followerId = id('follower_id') ?? id('sender_id');
      return followerId == null
          ? null
          : NotificationDestination(AppConstants.publicProfileScreen, {
              'userId': followerId,
            });

    case 'builder_network_addition':
      // The portal goes to `/networks/members` unconditionally (`:73`). This app's
      // `sendRequest` and `sendBuilderInvite` both write `sender_id`, so the person
      // can be opened directly — strictly more useful, and the list is the fallback.
      final senderId = id('sender_id');
      if (senderId != null) {
        return NotificationDestination(AppConstants.publicProfileScreen, {
          'userId': senderId,
        });
      }
      // `NetworkCommunicationService.sendBulkMessage` reuses this same enum
      // value for a broadcast announcement — the one writer of it with no
      // `sender_id` at all (see its own `data` shape:
      // `{message_type, priority}`). Routing a bulk announcement to "the
      // sender's connection list" would misleadingly read as if it were a
      // connection request; the Communication screen it was actually sent
      // from is the honest destination.
      if (id('message_type') != null) {
        return const NotificationDestination(
          AppConstants.networkCommunicationScreen,
        );
      }
      return const NotificationDestination(AppConstants.myNetworksScreen);

    case 'property_approved':
    case 'property_like':
      // `/property/${property_id}` (`:79`). `property_like` has no portal case;
      // grouped here because it is the same subject and the same payload shape.
      final propertyId = id('property_id') ?? id('propertyId');
      return propertyId == null
          ? null
          : NotificationDestination(AppConstants.propertyDetailScreen, {
              'propertyId': propertyId,
            });

    case 'project_shared':
      // `/project/${projectId}` (`:96`). `ProjectShareService` does write
      // `projectId`, so this is the one detail route that resolves in practice.
      final projectId = id('projectId') ?? id('project_id');
      return projectId == null
          ? null
          : NotificationDestination(AppConstants.projectDetailScreen, {
              'projectId': projectId,
            });

    case 'profile_view':
      // `/user/${viewer_id}` else `/profile-views` (`:101-107`). Only reachable if
      // the unapplied `migration2` enum value lands.
      final viewerId = id('viewer_id');
      return viewerId != null
          ? NotificationDestination(AppConstants.publicProfileScreen, {
              'userId': viewerId,
            })
          : const NotificationDestination(AppConstants.profileViewsScreen);

    // ── List destinations ──────────────────────────────────────────────────
    case 'channel_addition':
    case 'channel_message':
    case 'message_received':
      // All three go to `/chat` on the portal (`:68`, `:87`). Flutter's equivalent
      // is the messages list. `channel_message` does carry `channel_id`, but this
      // app's channel thread route expects a channel summary object rather than an
      // id, so the list is the honest destination rather than a route that would
      // fail to build.
      return const NotificationDestination(AppConstants.messagesScreen);

    case 'lead_assigned':
    case 'lead_status_update':
    case 'network_lead_new':
      // `/networks/leads` (`:93`). `network_lead_new` has no portal case; it is the
      // same subject.
      return const NotificationDestination(AppConstants.myLeadsScreen);

    case 'property_inquiry':
      // The portal goes to `/manage-properties`, which this app does not have —
      // listings are managed on the role dashboard, as
      // `ManageListSection`'s own comment records. The dispatcher resolves the
      // right dashboard for the role.
      return const NotificationDestination(AppConstants.manageDashboardScreen);

    // ── Deliberately nowhere ───────────────────────────────────────────────
    //
    // `visit_booking_update` carries no booking or property id from either writer,
    // and the portal has no case for it. The social_* types report background
    // publishing outcomes and have no screen in this app at all. Tapping marks
    // them read, which is the whole interaction.
    default:
      return null;
  }
}
