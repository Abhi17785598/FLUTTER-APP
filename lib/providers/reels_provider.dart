import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reel_model.dart';
import '../services/reels_service.dart';

class ReelsProvider with ChangeNotifier {
  bool _hasCompletedOnboarding = false;

  String? _selectedCity;
  String? _selectedBudget;
  String? _selectedPropertyType;

  final ReelsService _reelsService = ReelsService();

  List<ReelModel> _reels = [];
  bool _isLoading = false;
  bool _hasError = false;

  // Per-reel interaction state keyed by reel id. Kept in the provider (rather
  // than in the screen's setState) so swiping pages never rebuilds the video
  // layer and so state survives page recycling in the PageView.
  final Set<String> _likedIds = {};
  final Set<String> _savedIds = {};
  final Set<String> _followedIds = {};

  List<ReelModel> get reels => _reels;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;

  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  String? get selectedCity => _selectedCity;
  String? get selectedBudget => _selectedBudget;
  String? get selectedPropertyType => _selectedPropertyType;

  bool isLiked(String id) => _likedIds.contains(id);
  bool isSaved(String id) => _savedIds.contains(id);
  bool isFollowed(String id) => _followedIds.contains(id);

  /// Displayed like count = base likes + 1 when the user has liked locally.
  int likeCount(ReelModel reel) =>
      reel.likes + (_likedIds.contains(reel.id) ? 1 : 0);

  ReelsProvider() {
    _loadPreferences();
    loadReels();
  }

  Future<void> loadReels() async {
    try {
      _isLoading = true;
      _hasError = false;
      notifyListeners();

      final data = await _reelsService.getReels();
      _reels = data.map((e) => ReelModel.fromSupabase(e)).toList();

      debugPrint('Loaded reels: ${_reels.length}');

      // TEMPORARY cover-image trace. Debug builds only; remove once the blank
      // rail is explained. Prints the raw column exactly as Postgrest returned
      // it, so a NULL thumbnail is distinguishable from a populated URL that
      // fails to load — the two render identically.
      if (kDebugMode) {
        for (var i = 0; i < data.length && i < 5; i++) {
          final row = data[i];
          final property = row['_property'] as Map<String, dynamic>?;
          debugPrint(
            '[reel-cover] #$i "${row['title']}"\n'
            '    thumbnail_url = ${row['thumbnail_url'] == null ? 'NULL' : '"${row['thumbnail_url']}"'}\n'
            '    property_id   = ${row['property_id'] ?? 'NULL'}'
            '  joined=${property != null}'
            '  media_urls=${property?['media_urls'] ?? '-'}\n'
            '    → previewImageUrl = "${_reels[i].previewImageUrl}"',
          );
        }
      }
    } catch (e) {
      _hasError = true;
      debugPrint('Reels error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggleLike(String id) {
    _likedIds.contains(id) ? _likedIds.remove(id) : _likedIds.add(id);
    notifyListeners();
  }

  void toggleSave(String id) {
    _savedIds.contains(id) ? _savedIds.remove(id) : _savedIds.add(id);
    notifyListeners();
  }

  void toggleFollow(String id) {
    _followedIds.contains(id)
        ? _followedIds.remove(id)
        : _followedIds.add(id);
    notifyListeners();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    _hasCompletedOnboarding =
        prefs.getBool('hasCompletedReelsOnboarding') ?? false;

    _selectedCity = prefs.getString('reelsCity');
    _selectedBudget = prefs.getString('reelsBudget');
    _selectedPropertyType = prefs.getString('reelsPropertyType');

    notifyListeners();
  }

  Future<void> completeOnboarding({
    required String city,
    required String budget,
    required String propertyType,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('hasCompletedReelsOnboarding', true);
    await prefs.setString('reelsCity', city);
    await prefs.setString('reelsBudget', budget);
    await prefs.setString('reelsPropertyType', propertyType);

    _hasCompletedOnboarding = true;
    _selectedCity = city;
    _selectedBudget = budget;
    _selectedPropertyType = propertyType;

    notifyListeners();
  }
}
