// services/profile_connection_service.dart
//
// READ-ONLY companion service: what is the connection state between the signed-in
// viewer and the profile they are looking at?
//
// WHY A COMPANION AND NOT A METHOD ON NetworkService
// -------------------------------------------------
// `NetworkService` is consumed by `NetworkHubProvider`, `NetworkSectionProvider`,
// `ProfileProvider` and the four Network leaf screens. Approved decision D4 allows
// appending to an existing client service only when nothing existing changes —
// and Stage 1's approved modification list is `app_constants.dart` and `app.dart`
// only. So the read lives here instead, and `network_service.dart` is untouched.
//
// `NetworkService.getAcceptedCount()` IS reused, by calling it — see
// `PublicProfileProvider`. Calling is not modifying.
//
// WRITES (Phase 6) live here too, for the same reason: `NetworkService` declares
// itself read-only —
//
//   "Every method is a `select`. All the Network writes React owns — accepting or
//    declining an invitation, assigning a lead, creating a referral or a channel,
//    sending a bulk message — stay with the web portal."
//   (network_service.dart:13-15)
//
// — and the Flutter Network module has no write path anywhere: not in
// `NetworkHubProvider`, not in `NetworkSectionProvider`, not in any of its five
// screens. So there was no existing accept/decline flow to reuse or to preserve,
// and adding one to `NetworkService` would have contradicted its stated contract
// and touched a file four providers depend on. The writes are additive here
// instead, and `NetworkService` stays exactly as it is.
//
// Rows written here DO flow into the existing Network screens, because
// `NetworkService.getAcceptedCount` and `listMemberships` read the same
// `builder_networks` table. That is the intended outcome — a new connection should
// appear in the hub — and it is data reaching those screens, not a change to how
// they behave.
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Connection state between two users, mirroring the portal's
/// `networkStatus` union (pages/UserProfile.tsx:200-202).
enum ProfileConnectionStatus {
  /// No row in either table, or the viewer is anonymous / looking at themselves.
  none,

  /// The viewer asked to connect and is waiting.
  pendingSent,

  /// The other user asked, and the viewer can accept.
  pendingReceived,

  /// Accepted — this is what unlocks contact details.
  connected;

  bool get isConnected => this == ProfileConnectionStatus.connected;
}

class ProfileConnectionService {
  ProfileConnectionService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Resolves the state between [viewerId] and [profileUserId].
  ///
  /// A direct port of `fetchNetworkStatus` (pages/UserProfile.tsx:258-309),
  /// including its two-table order: the unified peer table first, then the legacy
  /// invitations table. Skipping the second would make older connections read as
  /// `none`, which would wrongly re-lock contact details for users who are
  /// already connected.
  ///
  /// Returns [ProfileConnectionStatus.none] for an anonymous viewer and for a
  /// self-view, before touching the network — the portal guards the same way, and
  /// RLS would return nothing regardless.
  ///
  /// Never throws. A failed lookup degrades to `none`, which fails *closed*:
  /// contact details stay hidden. Throwing would take down a screen whose other
  /// eleven sections are fine.
  Future<ProfileConnectionStatus> getStatus({
    required String? viewerId,
    required String profileUserId,
  }) async {
    if (viewerId == null || viewerId.isEmpty) {
      return ProfileConnectionStatus.none;
    }
    if (profileUserId.isEmpty || viewerId == profileUserId) {
      return ProfileConnectionStatus.none;
    }

    try {
      // ── 1. Unified peer connections ──────────────────────────────────────
      // Either direction: the sender is always `member_id`, the recipient always
      // `builder_id`, so both orderings have to be checked.
      final connection = await _supabase
          .from('builder_networks')
          .select('status, builder_id, member_id')
          .or(
            'and(builder_id.eq.$viewerId,member_id.eq.$profileUserId),'
            'and(builder_id.eq.$profileUserId,member_id.eq.$viewerId)',
          )
          .maybeSingle();

      if (connection != null) {
        final status = connection['status']?.toString().toLowerCase();
        if (status == 'accepted') return ProfileConnectionStatus.connected;
        if (status == 'pending') {
          // The sender is `member_id`. If that is the viewer, the viewer asked.
          return connection['member_id']?.toString() == viewerId
              ? ProfileConnectionStatus.pendingSent
              : ProfileConnectionStatus.pendingReceived;
        }
        // Any other status (e.g. rejected/removed) reads as no connection, which
        // is what the portal's fall-through does.
        return ProfileConnectionStatus.none;
      }

      // ── 2. Legacy invitations ────────────────────────────────────────────
      final invitation = await _supabase
          .from('builder_network_invitations')
          .select('status, builder_id, invited_user_id')
          .or(
            'and(builder_id.eq.$viewerId,invited_user_id.eq.$profileUserId),'
            'and(builder_id.eq.$profileUserId,invited_user_id.eq.$viewerId)',
          )
          .inFilter('status', ['pending', 'accepted'])
          .maybeSingle();

      if (invitation != null) {
        final status = invitation['status']?.toString().toLowerCase();
        if (status == 'accepted') return ProfileConnectionStatus.connected;
        // On this table the *inviter* is `builder_id`.
        return invitation['builder_id']?.toString() == viewerId
            ? ProfileConnectionStatus.pendingSent
            : ProfileConnectionStatus.pendingReceived;
      }

      return ProfileConnectionStatus.none;
    } catch (e) {
      debugPrint('ProfileConnectionService.getStatus failed: $e');
      return ProfileConnectionStatus.none;
    }
  }

  // ── Writes (Phase 6) ───────────────────────────────────────────────────────
  //
  // RLS, verified — no backend change needed:
  //   builder_networks              FOR ALL USING (builder_id = auth.uid()
  //                                              OR member_id = auth.uid())
  //   builder_network_invitations   symmetric policies
  //   notifications                 FOR INSERT TO authenticated
  //                                 WITH CHECK (auth.uid() IS NOT NULL)
  //
  // For a `FOR ALL` policy Postgres applies USING as the insert check, and the
  // sender is always `member_id`, so the upsert below passes. The cross-user
  // notification insert is permitted outright.

  /// Sends a connection request.
  ///
  /// A direct port of `handleNetworkAction`'s `none` branch
  /// (UserProfile.tsx:612-650). Two details are load-bearing:
  ///
  /// * **UPSERT, not insert**, on `(builder_id, member_id)`. A prior removed or
  ///   rejected row still occupies that unique pair, so an insert would fail with
  ///   23505 and the user could never reconnect after a removal.
  /// * **The recipient is `builder_id`, the sender is `member_id`** — regardless of
  ///   either party's role. Reversing them still satisfies RLS (both sides are
  ///   permitted) but inverts the meaning, and the recipient would see nothing.
  Future<ConnectionWriteError?> sendRequest({
    required String? viewerId,
    required String profileUserId,
  }) async {
    final guard = _writeGuard(viewerId, profileUserId);
    if (guard != null) return guard;

    try {
      final sender = await _senderContext(viewerId!);

      await _supabase.from('builder_networks').upsert(
        {
          'builder_id': profileUserId,
          'member_id': viewerId,
          'member_type': sender.userType ?? 'individual',
          'status': 'pending',
        },
        onConflict: 'builder_id,member_id',
      );

      // Best-effort, exactly as the portal treats it (UserProfile.tsx:642-644):
      // it logs a failed notification and carries on. The connection is the
      // outcome the user asked for; a missing notification must not undo it.
      try {
        await _supabase.from('notifications').insert({
          'user_id': profileUserId,
          'type': 'builder_network_addition',
          'title': 'Network Connection Request',
          'message': '${sender.name} wants to connect with you',
          'data': {'sender_id': viewerId, 'sender_name': sender.name},
        });
      } catch (e) {
        debugPrint('ProfileConnectionService: notification insert failed: $e');
      }

      return null;
    } catch (e) {
      debugPrint('ProfileConnectionService.sendRequest failed: $e');
      return ConnectionWriteError.failed;
    }
  }

  /// Cancels a pending request in either direction.
  ///
  /// UserProfile.tsx:651-675. Deletes from **both** tables: a legacy invitation
  /// left behind would make `getStatus` report `pendingSent` again on the next
  /// load, so the request would appear to un-cancel itself.
  Future<ConnectionWriteError?> cancelRequest({
    required String? viewerId,
    required String profileUserId,
  }) async {
    final guard = _writeGuard(viewerId, profileUserId);
    if (guard != null) return guard;

    try {
      await _supabase
          .from('builder_networks')
          .delete()
          .or(
            'and(builder_id.eq.$viewerId,member_id.eq.$profileUserId),'
            'and(builder_id.eq.$profileUserId,member_id.eq.$viewerId)',
          )
          .eq('status', 'pending');

      await _supabase
          .from('builder_network_invitations')
          .delete()
          .or(
            'and(builder_id.eq.$viewerId,invited_user_id.eq.$profileUserId),'
            'and(builder_id.eq.$profileUserId,invited_user_id.eq.$viewerId)',
          )
          .eq('status', 'pending');

      return null;
    } catch (e) {
      debugPrint('ProfileConnectionService.cancelRequest failed: $e');
      return ConnectionWriteError.failed;
    }
  }

  /// Accepts an incoming request.
  ///
  /// UserProfile.tsx:676-725. Two paths, in this order:
  ///
  /// 1. A unified peer row in `builder_networks` where the viewer is the
  ///    recipient — flip it to `accepted`.
  /// 2. Otherwise a legacy `builder_network_invitations` row — mark it accepted
  ///    **and** upsert the corresponding `builder_networks` row, because that is
  ///    the table every count and list reads. Marking only the invitation would
  ///    leave the connection invisible everywhere.
  Future<ConnectionWriteError?> acceptRequest({
    required String? viewerId,
    required String profileUserId,
  }) async {
    final guard = _writeGuard(viewerId, profileUserId);
    if (guard != null) return guard;

    try {
      final existing = await _supabase
          .from('builder_networks')
          .select('id')
          .eq('builder_id', viewerId!)
          .eq('member_id', profileUserId)
          .eq('status', 'pending')
          .maybeSingle();

      if (existing != null) {
        await _supabase
            .from('builder_networks')
            .update({'status': 'accepted'})
            .eq('id', existing['id']);
        return null;
      }

      final invitation = await _supabase
          .from('builder_network_invitations')
          .select('id, member_type')
          .eq('builder_id', profileUserId)
          .eq('invited_user_id', viewerId)
          .eq('status', 'pending')
          .maybeSingle();

      if (invitation == null) {
        // Nothing to accept — the request was withdrawn, or the status was stale.
        return ConnectionWriteError.nothingToAccept;
      }

      await _supabase
          .from('builder_network_invitations')
          .update({'status': 'accepted'})
          .eq('id', invitation['id']);

      await _supabase.from('builder_networks').upsert(
        {
          'builder_id': profileUserId,
          'member_id': viewerId,
          'member_type': invitation['member_type'] ?? 'individual',
          'status': 'accepted',
        },
        onConflict: 'builder_id,member_id',
      );

      return null;
    } catch (e) {
      debugPrint('ProfileConnectionService.acceptRequest failed: $e');
      return ConnectionWriteError.failed;
    }
  }

  /// Shared pre-flight for every write.
  @visibleForTesting
  static ConnectionWriteError? writeGuardFor({
    required String? viewerId,
    required String profileUserId,
  }) =>
      _writeGuard(viewerId, profileUserId);

  static ConnectionWriteError? _writeGuard(
    String? viewerId,
    String profileUserId,
  ) {
    if (viewerId == null || viewerId.isEmpty) {
      return ConnectionWriteError.notAllowed;
    }
    if (profileUserId.isEmpty || viewerId == profileUserId) {
      return ConnectionWriteError.notAllowed;
    }
    return null;
  }

  /// The sender's display name and role, for the notification body and
  /// `member_type`.
  ///
  /// The portal reads `company_name, display_name` and falls back
  /// `company_name || display_name || 'Someone'` (UserProfile.tsx:603-610).
  /// `UserProfileService.fetchProfilesByIds` is not reused here because its
  /// projection omits `company_name`, which would silently degrade a company's
  /// notification to a personal name.
  Future<({String name, String? userType})> _senderContext(
    String viewerId,
  ) async {
    try {
      final row = await _supabase
          .from('profiles')
          .select('display_name, company_name, user_type')
          .eq('user_id', viewerId)
          .maybeSingle();

      final company = (row?['company_name'] as String?)?.trim();
      final display = (row?['display_name'] as String?)?.trim();
      final name = (company != null && company.isNotEmpty)
          ? company
          : (display != null && display.isNotEmpty ? display : 'Someone');

      return (name: name, userType: row?['user_type'] as String?);
    } catch (e) {
      debugPrint('ProfileConnectionService._senderContext failed: $e');
      // The request still goes out; only the notification wording is generic.
      return (name: 'Someone', userType: null);
    }
  }
}

/// Why a connection write failed.
enum ConnectionWriteError {
  /// Anonymous viewer, or a self-connection. Blocked before the round-trip.
  notAllowed,

  /// Accept found no pending row — withdrawn, or the local status was stale.
  nothingToAccept,

  /// Anything else.
  failed,
}
