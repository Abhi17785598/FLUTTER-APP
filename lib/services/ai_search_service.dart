// services/ai_search_service.dart
//
// Smart Search — calls the website's EXISTING `openai-proxy` Supabase Edge
// Function (verified live against the production project: POST
// {SUPABASE_URL}/functions/v1/openai-proxy/chat/completions, standard
// OpenAI chat-completions request/response shape, server picks the model)
// to parse a natural-language query into structured filters. No backend
// changes — this reuses the exact endpoint the website's own Smart Search
// already calls, the same way `global_search`/`track_property_view` are
// reused elsewhere in this app.
//
// The extracted filters are applied through the app's EXISTING filter/
// search pipeline (FilterProvider -> PropertyProvider.runSearch) rather
// than having the AI fetch/rank properties itself, so Smart Search can
// never bypass or duplicate the (already-fixed) search logic.
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/smart_query_result.dart';

class AiSearchService {
  static const Set<String> _validCategories = {
    'residential', 'commercial', 'land', 'pg_coliving', 'others',
  };
  static const Set<String> _validListingTypes = {'sell', 'rent', 'lease'};

  static const String _systemPrompt =
      'You are a real-estate search query parser. Extract filters from the '
      'user query and reply with ONLY compact JSON, no prose, no markdown '
      'fences: {"city": string|null, "bhk": integer|null (use 5 for "5+" or '
      '"5 or more"), "category": "residential"|"commercial"|"land"|'
      '"pg_coliving"|"others"|null, "listingType": "sell"|"rent"|"lease"|'
      'null (use "sell" for words like buy/purchase/sale), "budgetMin": '
      'number|null, "budgetMax": number|null (both in rupees — convert '
      'lakhs/crores: 1 lakh = 100000, 1 crore = 10000000), "keywords": '
      'string (remaining descriptive terms not already captured above, can '
      'be an empty string)}.';

  /// Parses [query] via the AI proxy. Never throws — on any failure (network
  /// error, non-200, malformed JSON), falls back to a result that just
  /// carries the original text as `keywords`, so the caller can always fall
  /// back to a plain-text search rather than being blocked.
  Future<SmartQueryResult> parseQuery(String query) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'openai-proxy/chat/completions',
        body: {
          'messages': [
            {'role': 'system', 'content': _systemPrompt},
            {'role': 'user', 'content': query},
          ],
        },
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return SmartQueryResult(keywords: query);
      }
      final choices = data['choices'];
      if (choices is! List || choices.isEmpty) {
        return SmartQueryResult(keywords: query);
      }
      final message = choices.first['message'];
      final content = message is Map ? message['content'] as String? : null;
      if (content == null || content.trim().isEmpty) {
        return SmartQueryResult(keywords: query);
      }

      String cleaned = content.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceFirst(RegExp(r'^```(json)?'), '').trim();
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3).trim();
      }

      final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
      final result = SmartQueryResult.fromJson(parsed);

      return SmartQueryResult(
        city: result.city,
        bhk: result.bhk,
        category:
            _validCategories.contains(result.category) ? result.category : null,
        listingType: _validListingTypes.contains(result.listingType)
            ? result.listingType
            : null,
        budgetMin: result.budgetMin,
        budgetMax: result.budgetMax,
        keywords: result.keywords,
      );
    } catch (e) {
      // Model returned invalid JSON, the function call failed, etc. — fall
      // back to plain text rather than blocking the search.
      return SmartQueryResult(keywords: query);
    }
  }
}
