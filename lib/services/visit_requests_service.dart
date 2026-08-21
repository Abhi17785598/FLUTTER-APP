// services/visit_requests_service.dart
//
// Backs "My Visits" — ports the portal's `MyVisitRequests.tsx` exactly:
// three tables (`property_visit_bookings`, `project_visit_bookings`,
// `profile_visit_requests`), each filtered to the signed-in user and merged
// client-side, sorted by `created_at` descending
// (MyVisitRequests.tsx:76-92,141-145). There is deliberately no
// Upcoming/Completed split — the reference doesn't have one either, only a
// `status` badge.
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/property_model.dart';
import '../models/visit_request_item.dart';

class VisitRequestsService {
  SupabaseClient get _supabase => Supabase.instance.client;

  Future<List<VisitRequestItem>> fetchMine(String userId) async {
    try {
      final results = await Future.wait([
        _supabase
            .from('property_visit_bookings')
            .select('*, properties(id, title, location, media_urls)')
            .eq('user_id', userId)
            .order('created_at', ascending: false),
        _supabase
            .from('project_visit_bookings')
            .select(
              '*, builder_projects(id, title, location, logo_url, master_layout_url)',
            )
            .eq('user_id', userId)
            .order('created_at', ascending: false),
        _supabase
            .from('profile_visit_requests')
            .select('*')
            .eq('requester_user_id', userId)
            .order('created_at', ascending: false),
      ]);

      final propertyRows = List<Map<String, dynamic>>.from(results[0] as List);
      final projectRows = List<Map<String, dynamic>>.from(results[1] as List);
      final profileRows = List<Map<String, dynamic>>.from(results[2] as List);

      // Second round-trip for target display info, same as
      // MyVisitRequests.tsx:96.
      final targetUserIds = profileRows
          .map((r) => r['target_user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      final profilesById = <String, Map<String, dynamic>>{};
      if (targetUserIds.isNotEmpty) {
        final profiles = await _supabase
            .from('profiles')
            .select('user_id, display_name, avatar_url')
            .inFilter('user_id', targetUserIds);
        for (final row in List<Map<String, dynamic>>.from(profiles)) {
          final id = row['user_id']?.toString();
          if (id != null) profilesById[id] = row;
        }
      }

      final items = <VisitRequestItem>[
        for (final row in propertyRows) _fromProperty(row),
        for (final row in projectRows) _fromProject(row),
        for (final row in profileRows) _fromProfile(row, profilesById),
      ];

      // MyVisitRequests.tsx:141-145 — sort the merged list by created_at
      // descending (most recently requested first), not by preferred_date.
      items.sort((a, b) {
        final aTime = a.createdAt;
        final bTime = b.createdAt;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      return items;
    } catch (e) {
      debugPrint('VisitRequestsService.fetchMine failed: $e');
      rethrow;
    }
  }

  VisitRequestItem _fromProperty(Map<String, dynamic> row) {
    final property = row['properties'] as Map<String, dynamic>?;
    final images = PropertyModel.parseMediaUrls(property?['media_urls']);
    return VisitRequestItem(
      source: VisitRequestSource.property,
      targetId: row['property_id']?.toString() ?? '',
      title: _str(property?['title']) ?? 'Property',
      imageUrl: images.isNotEmpty ? images.first : null,
      location: _str(property?['location']) ?? '',
      preferredDate: row['preferred_date']?.toString(),
      preferredTime: row['preferred_time']?.toString(),
      status: row['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
    );
  }

  VisitRequestItem _fromProject(Map<String, dynamic> row) {
    final project = row['builder_projects'] as Map<String, dynamic>?;
    final image = _str(project?['logo_url']) ?? _str(project?['master_layout_url']);
    return VisitRequestItem(
      source: VisitRequestSource.project,
      targetId: row['project_id']?.toString() ?? '',
      title: _str(project?['title']) ?? 'Project',
      imageUrl: image,
      location: _str(project?['location']) ?? '',
      preferredDate: row['preferred_date']?.toString(),
      preferredTime: row['preferred_time']?.toString(),
      status: row['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
    );
  }

  VisitRequestItem _fromProfile(
    Map<String, dynamic> row,
    Map<String, Map<String, dynamic>> profilesById,
  ) {
    final targetId = row['target_user_id']?.toString() ?? '';
    final profile = profilesById[targetId];
    return VisitRequestItem(
      source: VisitRequestSource.profile,
      targetId: targetId,
      title: _str(profile?['display_name']) ?? 'General visit request',
      imageUrl: _str(profile?['avatar_url']),
      location: '',
      preferredDate: row['preferred_date']?.toString(),
      preferredTime: row['preferred_time']?.toString(),
      status: row['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
    );
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Inserts a new property visit request — mirrors the portal's
  /// `BookVisitModal.tsx` insert into `property_visit_bookings`
  /// (`:156-178`): a fresh request always starts `status: 'pending'`: the
  /// owner is the only one who ever changes it (`PropertyVisitBookingsManager.tsx`).
  /// Only the property branch is reproduced — no Flutter screen currently
  /// offers a project- or profile-visit booking entry point to fix.
  Future<void> createPropertyVisit({
    required String userId,
    required String propertyId,
    required String visitorName,
    required String visitorPhone,
    required DateTime preferredDate,
    required String preferredTime,
    String message = '',
  }) async {
    final dateStr = '${preferredDate.year.toString().padLeft(4, '0')}-'
        '${preferredDate.month.toString().padLeft(2, '0')}-'
        '${preferredDate.day.toString().padLeft(2, '0')}';
    try {
      await _supabase.from('property_visit_bookings').insert({
        'user_id': userId,
        'property_id': propertyId,
        'visitor_name': visitorName,
        'visitor_phone': visitorPhone,
        'preferred_date': dateStr,
        'preferred_time': preferredTime,
        'message': message,
        'status': 'pending',
      });
    } catch (e) {
      debugPrint('VisitRequestsService.createPropertyVisit failed: $e');
      rethrow;
    }
  }
}
