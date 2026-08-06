import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'providers/navigation_provider.dart';
import 'providers/property_provider.dart';
import 'providers/filter_provider.dart';
import 'providers/shortlist_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/reels_provider.dart';
import 'providers/available_locations_provider.dart';
import 'providers/recent_searches_provider.dart';
import 'voice_agent/providers/voice_agent_provider.dart';
import 'voice_agent/tools/navigation_tool.dart';
import 'voice_agent/tools/search_tools.dart';
import 'voice_agent/tools/property_tools.dart';
import 'voice_agent/tools/profile_tools.dart';
import 'voice_agent/tools/favorites_tool.dart';
import 'voice_agent/tools/utility_tools.dart';


void _registerVoiceAgentTools() {
  registerNavigationTool();
  registerSearchTools();
  registerPropertyTools();
  registerProfileTools();
  registerFavoritesTool();
  registerUtilityTools();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  _registerVoiceAgentTools();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => PropertyProvider()),
        ChangeNotifierProvider(create: (_) => FilterProvider()),
        ChangeNotifierProvider(create: (_) => ShortlistProvider()),
        ChangeNotifierProvider(create: (_) => ReelsProvider()),
        ChangeNotifierProvider(create: (_) => AvailableLocationsProvider()),
        // Proxied on AuthProvider because recent searches live in
        // `ai_user_memory` for a signed-in user and in shared_preferences for
        // an anonymous one — the list has to reload when that identity changes.
        ChangeNotifierProxyProvider<AuthProvider, RecentSearchesProvider>(
          create: (ctx) => RecentSearchesProvider(ctx.read<AuthProvider>()),
          update: (ctx, auth, prev) => prev!..updateAuth(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, VoiceAgentProvider>(
          create: (ctx) => VoiceAgentProvider(ctx.read<AuthProvider>()),
          update: (ctx, auth, prev) => prev!..updateAuth(auth),
        ),
      ],
      child: const PropertyApp(),
    ),
  );
}
