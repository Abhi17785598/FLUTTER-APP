// services/builder_sections_service.dart
//
// Read/write access for the builder dashboard's four management sections:
// Inventory, Marketed Offers, Team and Site Visits.
//
// WHY ONE FILE, FOUR SERVICES
// ---------------------------
// Each is a small, independent surface over one or two tables, and all four ship
// together. Splitting them across four files would add imports without adding a
// boundary; they share no state and no helpers beyond the coercion already in
// `builder_section_models.dart`.
//
// WHAT IS NOT DUPLICATED
// ----------------------
// `ProjectService` stays the only writer of `builder_projects`. The inventory
// section lists projects through `ProjectService.listMine` and changes their
// status through `ProjectService.setStatus`, both of which already existed and
// neither of which is touched. `InventoryService` below only supplies the
// `project_inventory` tallies that `ProjectService` has no business knowing about.
//
// Likewise `ProjectShareService` remains the reference for how this app writes a
// `notifications` row; `SiteVisitService._notifyVisitor` follows its shape rather
// than inventing a second one.
//
// NO BACKEND CHANGE
// -----------------
// Every call here is a SELECT, an UPDATE the existing RLS already permits, a
// `notifications` INSERT of a type the enum already carries
// (`visit_booking_update`, added by 20260315190000), or an invocation of the
// already-deployed `invite-team-member` Edge Function.
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/builder_section_options.dart';
import '../models/builder_section_models.dart';

/// Raised when a write is refused before it is attempted.
class BuilderSectionException implements Exception {
  const BuilderSectionException(this.message);

  final String message;

  @override
  String toString() => message;
}

// ── Inventory ───────────────────────────────────────────────────────────────

/// `project_inventory` tallies and unit rows.
///
/// Deliberately read-only. `BuilderInventoryManager.tsx` never writes a unit —
/// its only mutations are to `builder_projects` (status and delete), which
/// `ProjectService` already owns. Adding unit CRUD here would be inventing a
/// feature neither platform has.
class ProjectInventoryService {
  ProjectInventoryService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const String table = 'project_inventory';

  /// Unit tallies for [projectIds], keyed by project id.
  ///
  /// One query for every project, exactly as `BuilderInventoryManager.tsx:148-152`
  /// does — the fold is client-side because the counts are per-status and
  /// PostgREST cannot group without an RPC.
  ///
  /// Returns an empty map for an empty id list rather than issuing
  /// `inFilter('project_id', [])`, which PostgREST answers with every row the
  /// caller can see.
  Future<Map<String, InventoryCounts>> countsByProject(
    List<String> projectIds,
  ) async {
    if (projectIds.isEmpty) return const {};

    final rows = await _supabase
        .from(table)
        .select('project_id, status')
        .inFilter('project_id', projectIds);

    final tallies = <String, ({int total, int sold, int available})>{};
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final id = row['project_id']?.toString();
      if (id == null) continue;
      final current = tallies[id] ?? (total: 0, sold: 0, available: 0);
      tallies[id] = (
        total: current.total + 1,
        // Only these two statuses are counted, so `booked` and `blocked` fall
        // into neither — the portal's behaviour, carried deliberately.
        sold: current.sold + (row['status'] == 'sold' ? 1 : 0),
        available: current.available + (row['status'] == 'available' ? 1 : 0),
      );
    }

    return {
      for (final entry in tallies.entries)
        entry.key: InventoryCounts(
          total: entry.value.total,
          sold: entry.value.sold,
          available: entry.value.available,
        ),
    };
  }

  /// Every unit of one project, cheapest first.
  ///
  /// Has no portal counterpart — the portal shows tallies only. Ordering by price
  /// rather than by `unit_number`, which is nullable and free-text, so it cannot
  /// be sorted meaningfully.
  Future<List<InventoryUnit>> unitsForProject(String projectId) async {
    final rows = await _supabase
        .from(table)
        .select(InventoryUnit.columns)
        .eq('project_id', projectId)
        .order('price', ascending: true);

    return List<Map<String, dynamic>>.from(rows)
        .map(InventoryUnit.fromSupabase)
        .toList();
  }

  /// Adds one unit to [projectId].
  ///
  /// `unit_type`, `area_sqft` and `price` are the table's own NOT NULL columns
  /// beyond `id`/`project_id`/the timestamps (`20250905144708:92-106`); `status`
  /// defaults to `'available'` there too, so [payload] need not set it for the
  /// common case. `ProjectInventoryManager.tsx` additionally edits `amenities`,
  /// `features`, `facing_direction` and `floor_plan_url` — deliberately out of
  /// scope here, matching [InventoryUnit] itself, which never modelled them
  /// either; [payload] can still carry them since this passes it through
  /// unfiltered, but no UI in this app sets them yet.
  Future<InventoryUnit> createUnit({
    required String projectId,
    required Map<String, dynamic> payload,
  }) async {
    final row = await _supabase
        .from(table)
        .insert(<String, dynamic>{'project_id': projectId, ...payload})
        .select(InventoryUnit.columns)
        .single();

    return InventoryUnit.fromSupabase(Map<String, dynamic>.from(row));
  }

  /// Updates one unit's editable fields.
  Future<void> updateUnit({
    required String unitId,
    required Map<String, dynamic> payload,
  }) async {
    await _supabase.from(table).update(<String, dynamic>{
      ...payload,
      // No touch trigger on this table (`20250905144708:92-106`), so without
      // this the column would keep the insert time — the same reasoning
      // `BuilderOfferService.update` already documents for the same gap.
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', unitId);
  }

  /// Removes one unit.
  ///
  /// A hard delete: `ProjectInventoryManager.tsx`'s own delete is (no soft-
  /// delete column exists on this table either).
  Future<void> deleteUnit(String unitId) async {
    await _supabase.from(table).delete().eq('id', unitId);
  }
}

// ── Marketed Offers ─────────────────────────────────────────────────────────

/// `builder_project_offers` for one builder.
class BuilderOfferService {
  BuilderOfferService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const String table = 'builder_project_offers';

  /// This builder's active offers, newest first.
  ///
  /// `FilteredOffersList.tsx:28-59` with `role === 'builder'`: filter
  /// `status = 'active'`, filter `builder_id = userId`, order by `created_at`
  /// descending. The broker branch of that component — which resolves
  /// `builder_networks` first — has no counterpart here, because this section is
  /// the builder's own.
  Future<List<BuilderOffer>> listMine(String builderId) async {
    final rows = await _supabase
        .from(table)
        .select(BuilderOffer.columns)
        .eq('status', 'active')
        .eq('builder_id', builderId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows)
        .map(BuilderOffer.fromSupabase)
        .toList();
  }

  /// Creates an offer for [projectId].
  ///
  /// `MarketToBrokersModal.tsx:166-175`. `builder_id` is set from [builderId] —
  /// the RLS INSERT policy is `WITH CHECK (auth.uid() = builder_id)`, so this is
  /// also the only value that would be accepted.
  ///
  /// Added with Spec I, which resolved that Market-to-Brokers writes this table
  /// rather than a network one. Additive: `listMine` and `delete` are unchanged.
  Future<String> create({
    required String builderId,
    required String projectId,
    required Map<String, dynamic> payload,
  }) async {
    final result = await _supabase
        .from(table)
        .insert(<String, dynamic>{
          'project_id': projectId,
          'builder_id': builderId,
          ...payload,
        })
        .select('id')
        .single();

    return result['id'].toString();
  }

  /// Updates an offer's title, copy and media.
  ///
  /// `:152-160`. Deliberately does not carry `status`: the update path on the
  /// portal never sends it either, so editing an offer cannot reactivate one that
  /// was deactivated.
  Future<void> update({
    required String offerId,
    required Map<String, dynamic> payload,
  }) async {
    await _supabase.from(table).update({
      ...payload,
      // The table has no touch trigger, so without this `updated_at` keeps the
      // insert time — `:158` sends it for the same reason.
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', offerId);
  }

  /// Hard-deletes an offer.
  ///
  /// `FilteredOffersList.tsx:71-88`. A hard delete, matching the portal: unlike
  /// `properties` and `influencer_videos`, `builder_project_offers` has no
  /// `deleted_at` column and is not one of `soft_delete_content`'s three
  /// whitelisted tables, so soft-delete is not available here even in principle.
  ///
  /// RLS scopes the DELETE to `auth.uid() = builder_id`, so a non-owner's call
  /// matches no row and completes silently.
  Future<void> delete(String offerId) async {
    await _supabase.from(table).delete().eq('id', offerId);
  }
}

// ── Team ────────────────────────────────────────────────────────────────────

/// One builder's team: members, outstanding invitations, and the invite call.
class BuilderTeamService {
  BuilderTeamService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const String membersTable = 'builder_team_members';
  static const String invitationsTable = 'builder_team_invitations';

  /// The Edge Function the portal invokes to send an invite.
  ///
  /// Already deployed (`supabase/functions/invite-team-member`). Invoking it is
  /// not a backend change; reimplementing what it does — creating the invitation
  /// row, minting a token, sending the email — would be.
  static const String inviteFunction = 'invite-team-member';

  /// The Edge Function the portal invokes to accept an invite.
  ///
  /// Already deployed (`supabase/functions/accept-team-invite`). Same
  /// reasoning as [inviteFunction] — the validation, the
  /// `builder_team_members` upsert and the `profiles.user_type` bootstrap for
  /// brand-new invitees all happen server-side; calling it is not a backend
  /// change.
  static const String acceptFunction = 'accept-team-invite';

  /// Members, newest first.
  Future<List<BuilderTeamMember>> listMembers(String builderId) async {
    final rows = await _supabase
        .from(membersTable)
        .select(BuilderTeamMember.columns)
        .eq('builder_id', builderId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows)
        .map(BuilderTeamMember.fromSupabase)
        .toList();
  }

  /// Invitations, newest first.
  Future<List<BuilderTeamInvitation>> listInvitations(String builderId) async {
    final rows = await _supabase
        .from(invitationsTable)
        .select(BuilderTeamInvitation.columns)
        .eq('builder_id', builderId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows)
        .map(BuilderTeamInvitation.fromSupabase)
        .toList();
  }

  /// This person's own pending invitations, across every builder that has
  /// invited them, newest first.
  ///
  /// Queried by email, never `builder_id` — the invitee doesn't know who
  /// invited them until this returns. Mirrors the fallback lookup in
  /// `AcceptInvite.tsx:57-69` and the redirect check in `TeamInviteGate.tsx`,
  /// which query the same table the same way.
  Future<List<BuilderTeamInvitation>> myPendingInvitations(
    String email,
  ) async {
    final rows = await _supabase
        .from(invitationsTable)
        .select(BuilderTeamInvitation.columns)
        .ilike('email', email)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows)
        .map(BuilderTeamInvitation.fromSupabase)
        .toList();
  }

  /// This person's own active memberships, across every builder they've
  /// joined, newest first.
  ///
  /// Queried by `member_user_id`, never `builder_id`, for the same reason as
  /// [myPendingInvitations]. Mirrors `TeamMemberDashboard.tsx:56-64`.
  Future<List<BuilderTeamMember>> myActiveMemberships(String userId) async {
    final rows = await _supabase
        .from(membersTable)
        .select(BuilderTeamMember.columns)
        .eq('member_user_id', userId)
        .eq('status', 'active')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows)
        .map(BuilderTeamMember.fromSupabase)
        .toList();
  }

  /// Sends an invite through the Edge Function.
  ///
  /// Mirrors `BuilderTeamManager.tsx:188-196`: the same function name and the
  /// same four body keys. `projectIds` is **null for "all projects"**, never an
  /// empty list — the column documents `NULL => all of the builder's projects`, so
  /// `[]` would grant access to nothing while reading like a mistake.
  ///
  /// `redirectOrigin` is what the portal passes its own `window.location.origin`.
  /// There is no origin on a phone, so the caller supplies the web origin the
  /// invite link should point at; the invited person opens it in a browser either
  /// way.
  ///
  /// Returns the function's decoded response so the caller can tell the two
  /// outcomes apart: `delivered == 'notification'` means the invitee already has
  /// an account and no email was sent, in which case `actionLink` must be shared
  /// manually.
  Future<BuilderTeamInviteResult> invite({
    required String email,
    required List<String> modules,
    required List<String>? projectIds,
    required String redirectOrigin,
  }) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      throw const BuilderSectionException(
        "Enter the person's email address.",
      );
    }
    if (modules.isEmpty) {
      // Also a database rule: builder_team_invitations CHECKs
      // array_length(modules,1) >= 1.
      throw const BuilderSectionException('Grant at least one module.');
    }
    if (!areValidTeamModules(modules)) {
      throw const BuilderSectionException('That is not a grantable module.');
    }
    if (projectIds != null && projectIds.isEmpty) {
      throw const BuilderSectionException(
        'Choose at least one project, or grant all.',
      );
    }

    Map<String, dynamic> map;
    try {
      final response = await _supabase.functions.invoke(
        inviteFunction,
        body: <String, dynamic>{
          'email': trimmed,
          'modules': modules,
          'projectIds': projectIds,
          'redirectOrigin': redirectOrigin,
        },
      );
      final data = response.data;
      map = data is Map<String, dynamic> ? data : const {};
    } on FunctionException catch (e) {
      // A 401 here always means the same thing: `invite-team-member` only ever
      // returns it when `callerClient.auth.getUser()` rejects the bearer token
      // it was sent (index.ts:40-42) — never a business refusal. In practice
      // that happens when the local session was silently dropped by a failed
      // background token refresh (a known `supabase` package issue: an
      // unretryable refresh error nulls the in-memory session, so the next
      // request falls back to sending the anon key instead of a user JWT,
      // which the function correctly rejects). Retrying without signing back
      // in cannot succeed, so say so instead of implying another attempt might
      // work.
      if (e.status == 401) {
        throw const BuilderSectionException(
          'Your session has expired. Please sign out and back in, then try '
          'again.',
        );
      }

      // Unlike the JS client the portal uses (which discards the response
      // body on a non-2xx status), this package's client decodes it into
      // `details` regardless of status — every other refusal
      // `invite-team-member` makes (bad domain, cap reached, duplicate
      // invite, ...) returns a non-2xx JSON body of the same `{error: "..."}`
      // shape checked below, so that reason must be read from here, not from
      // a successful response.
      final details = e.details;
      final message = details is Map && details['error'] != null
          ? details['error'].toString()
          : 'Could not send that invite. Please try again.';
      throw BuilderSectionException(message);
    }

    final error = map['error'];
    if (error != null) {
      throw BuilderSectionException(error.toString());
    }

    return BuilderTeamInviteResult(
      delivered: map['delivered']?.toString(),
      actionLink: map['actionLink']?.toString(),
    );
  }

  /// Accepts a pending invitation through the Edge Function.
  ///
  /// Mirrors `AcceptInvite.tsx:88-97`: same function name, same two body
  /// keys. `token` is optional — it comes from the invite link's `?token=`
  /// param, which is absent on the JWT-metadata / email-fallback detection
  /// paths (`AcceptInvite.tsx:52-69`); `accept-team-invite` only checks it
  /// when supplied (`index.ts:58-60`).
  Future<BuilderTeamAcceptResult> acceptInvite({
    required String invitationId,
    String? token,
  }) async {
    if (invitationId.trim().isEmpty) {
      throw const BuilderSectionException('Missing invitation id.');
    }

    Map<String, dynamic> map;
    try {
      final response = await _supabase.functions.invoke(
        acceptFunction,
        body: <String, dynamic>{
          'invitationId': invitationId,
          'token': ?token,
        },
      );
      final data = response.data;
      map = data is Map<String, dynamic> ? data : const {};
    } on FunctionException catch (e) {
      // Same reasoning as `invite()` above: a 401 from `accept-team-invite`
      // only ever means the bearer token this request carried wasn't a
      // valid user JWT (`index.ts:27-38`), never a business refusal.
      if (e.status == 401) {
        throw const BuilderSectionException(
          'Your session has expired. Please sign out and back in, then try '
          'again.',
        );
      }

      final details = e.details;
      final message = details is Map && details['error'] != null
          ? details['error'].toString()
          : 'Could not accept that invitation. Please try again.';
      throw BuilderSectionException(message);
    }

    final error = map['error'];
    if (error != null) {
      throw BuilderSectionException(error.toString());
    }

    final builder = map['builder'];
    final builderMap = builder is Map ? builder : const {};
    final modules = map['modules'];

    return BuilderTeamAcceptResult(
      builderId: map['builderId']?.toString(),
      modules: modules is List
          ? modules.map((m) => m.toString()).toList(growable: false)
          : const [],
      builderDisplayName: builderMap['display_name']?.toString(),
      builderCompanyName: builderMap['company_name']?.toString(),
      builderAvatarUrl: builderMap['avatar_url']?.toString(),
      // `index.ts:68-76` — an already-accepted invitation is success, not an
      // error; `AcceptInvite.tsx` doesn't distinguish it in its own UI, but a
      // caller that wants to (e.g. "you're already on this team") can.
      alreadyAccepted: map['alreadyAccepted'] == true,
    );
  }

  /// Revokes an active member.
  ///
  /// `BuilderTeamManager.tsx:230-236` — an UPDATE to `status = 'revoked'`, never a
  /// delete, so the row remains as a record of the grant.
  Future<void> revokeMember(String memberId) async {
    await _supabase
        .from(membersTable)
        .update({'status': 'revoked'})
        .eq('id', memberId);
  }

  /// Revokes an outstanding invitation (`:246-250`).
  Future<void> revokeInvitation(String invitationId) async {
    await _supabase
        .from(invitationsTable)
        .update({'status': 'revoked'})
        .eq('id', invitationId);
  }
}

/// What the invite Edge Function reported.
class BuilderTeamInviteResult {
  const BuilderTeamInviteResult({this.delivered, this.actionLink});

  /// `'notification'` when the invitee already had an account and must be sent
  /// [actionLink] by hand; anything else means an email went out.
  final String? delivered;

  final String? actionLink;

  /// True when the builder has to pass the link on themselves.
  bool get needsManualShare =>
      delivered == 'notification' && (actionLink?.isNotEmpty ?? false);
}

/// What the accept Edge Function reported (`index.ts:160-165`).
class BuilderTeamAcceptResult {
  const BuilderTeamAcceptResult({
    this.builderId,
    this.modules = const [],
    this.builderDisplayName,
    this.builderCompanyName,
    this.builderAvatarUrl,
    this.alreadyAccepted = false,
  });

  final String? builderId;
  final List<String> modules;
  final String? builderDisplayName;
  final String? builderCompanyName;
  final String? builderAvatarUrl;

  /// True when this invitation had already been accepted before this call —
  /// `index.ts:68-76` treats that as success, not an error.
  final bool alreadyAccepted;
}

// ── Site Visits ─────────────────────────────────────────────────────────────

/// `project_visit_bookings` across one builder's projects.
///
/// The portal mounts `SiteVisitBookingsManager` on the **team member** dashboard
/// only; a builder's own dashboard just counts bookings. The capability is a
/// builder's regardless — 20260304164434:30-49 grants them SELECT and UPDATE on
/// bookings for their own projects — so this is the missing UI over existing
/// permissions, not a new permission.
class SiteVisitService {
  SiteVisitService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const String table = 'project_visit_bookings';

  /// The notification type raised when a booking changes.
  ///
  /// Already a `notification_type` enum value
  /// (20260315190000_fix_missing_notification_types.sql:5), so no schema change
  /// is implied.
  static const String notificationType = 'visit_booking_update';

  /// Bookings for [projectIds], soonest requested date first.
  ///
  /// `SiteVisitBookingsManager.tsx:136-141` selects by `project_id IN (…)` — there
  /// is no builder column on the table, so the project list *is* the scope, and an
  /// empty list must short-circuit rather than become an unfiltered read.
  Future<List<SiteVisitBooking>> listForProjects(
    List<String> projectIds,
  ) async {
    if (projectIds.isEmpty) return const [];

    final rows = await _supabase
        .from(table)
        .select(SiteVisitBooking.columns)
        .inFilter('project_id', projectIds)
        .order('preferred_date', ascending: true);

    return List<Map<String, dynamic>>.from(rows)
        .map(SiteVisitBooking.fromSupabase)
        .toList();
  }

  /// Updates a booking's slot and status, then notifies the visitor if the new
  /// status is one the portal notifies on.
  ///
  /// `SiteVisitBookingsManager.tsx:160-186`, including its explicit
  /// `updated_at` — the table has no touch trigger, so without it the column
  /// would keep the insert time.
  ///
  /// [projectTitle] is passed in rather than looked up: the caller already has the
  /// project list on screen, and the portal resolves it the same way
  /// (`getProjectTitle`). A failed notification does **not** fail the update — the
  /// booking change is the user's intent and is already committed.
  Future<void> updateBooking({
    required SiteVisitBooking booking,
    required DateTime preferredDate,
    required String? preferredTime,
    required String status,
    required String projectTitle,
  }) async {
    if (status.trim().isEmpty) {
      throw const BuilderSectionException('Choose a status.');
    }

    await _supabase.from(table).update({
      // A DATE column: send the day only, never an instant, or the value is
      // truncated in whatever timezone the server is in.
      'preferred_date': _dateOnly(preferredDate),
      'preferred_time': (preferredTime?.isEmpty ?? true) ? null : preferredTime,
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', booking.id);

    if (kNotifyingSiteVisitStatuses.contains(status)) {
      await _notifyVisitor(
        userId: booking.userId,
        projectTitle: projectTitle,
        status: status,
        date: preferredDate,
        time: preferredTime,
      );
    }
  }

  /// Writes the visitor's notification row.
  ///
  /// Copy transcribed from `notifyVisitBookingUpdate`
  /// (utils/notificationHelpers.ts:189-211), including the detail that a
  /// cancellation omits the slot line — telling someone the new time of a visit
  /// that is not happening would be worse than saying nothing.
  ///
  /// Swallows its own failure: the update has already committed, and surfacing a
  /// notification error would read as though the booking change had failed.
  Future<void> _notifyVisitor({
    required String userId,
    required String projectTitle,
    required String status,
    required DateTime date,
    required String? time,
  }) async {
    final action = siteVisitStatusLabel(status);
    final slot = status == 'cancelled'
        ? ''
        : ' New slot: ${_dateOnly(date)}${time != null && time.isNotEmpty ? ' at $time' : ''}';

    try {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'type': notificationType,
        'title': 'Visit $action',
        'message':
            'Your visit for "$projectTitle" has been ${action.toLowerCase()}.$slot',
        'data': {
          'title': projectTitle,
          'status': status,
          'date': _dateOnly(date),
          'time': time,
        },
      });
    } catch (e) {
      debugPrint('SiteVisitService._notifyVisitor failed: $e');
    }
  }

  /// `yyyy-MM-dd`, which is what a Postgres DATE wants.
  static String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
