// Route index — Phase 1 end-user routes only.
// Phase 3: knowledge_service.dart, memory_service.dart,
//          conversation_history_service.dart go in this same rag/ directory.

class RouteEntry {
  final String path;
  final String title;
  final String tier; // 'public' | 'authenticated' | 'admin' | 'super_admin'
  final String section;
  final String description;
  final List<String> concepts;
  final List<String> keywords;

  const RouteEntry({
    required this.path,
    required this.title,
    required this.tier,
    required this.section,
    required this.description,
    required this.concepts,
    required this.keywords,
  });
}

// ─── Phase 1 route catalogue ──────────────────────────────────────────────────

const List<RouteEntry> _routes = [
  // Public routes
  RouteEntry(
    path: '/',
    title: 'Home',
    tier: 'public',
    section: 'main',
    description: 'Home screen with featured properties and categories',
    concepts: ['home', 'homepage', 'main', 'start'],
    keywords: ['home', 'main', 'start', 'ghar'],
  ),
  RouteEntry(
    path: '/search',
    title: 'Search',
    tier: 'public',
    section: 'discovery',
    description: 'Search and discover properties',
    concepts: ['search', 'find property', 'properties', 'property search'],
    keywords: ['search', 'find', 'property', 'properties', 'dhundho', 'khojo'],
  ),
  RouteEntry(
    path: '/shortlist',
    title: 'Shortlist',
    tier: 'public',
    section: 'discovery',
    description: 'Saved and bookmarked properties',
    concepts: ['shortlist', 'saved', 'bookmarks', 'liked', 'favourites', 'favorites'],
    keywords: ['shortlist', 'saved', 'bookmark', 'liked', 'wishlist', 'pasand'],
  ),
  RouteEntry(
    path: '/reels',
    title: 'Property Reels',
    tier: 'public',
    section: 'discovery',
    description: 'Short property video reels',
    concepts: ['reels', 'videos', 'property videos', 'property reels', 'influencer'],
    keywords: ['reels', 'video', 'shorts', 'reel'],
  ),
  RouteEntry(
    path: '/emi-calculator',
    title: 'EMI Calculator',
    tier: 'public',
    section: 'tools',
    description: 'Calculate home loan EMI',
    concepts: ['emi calculator', 'loan calculator', 'emi', 'home loan', 'mortgage'],
    keywords: ['emi', 'loan', 'calculator', 'mortgage', 'interest'],
  ),
  RouteEntry(
    path: '/compare-properties',
    title: 'Compare Properties',
    tier: 'public',
    section: 'tools',
    description: 'Compare multiple properties side by side',
    concepts: ['compare', 'comparison', 'compare properties', 'tulna'],
    keywords: ['compare', 'comparison', 'versus', 'vs', 'tulna'],
  ),
  RouteEntry(
    path: '/auth',
    title: 'Sign In / Sign Up',
    tier: 'public',
    section: 'auth',
    description: 'Authentication — sign in or create an account',
    concepts: ['sign in', 'login', 'sign up', 'register', 'auth', 'account'],
    keywords: ['login', 'signin', 'signup', 'register', 'auth', 'account'],
  ),

  // Authenticated routes
  RouteEntry(
    path: '/profile',
    title: 'Profile',
    tier: 'authenticated',
    section: 'account',
    description: 'User profile and dashboard',
    concepts: ['profile', 'my profile', 'account', 'dashboard', 'my dashboard'],
    keywords: ['profile', 'account', 'dashboard', 'mera', 'my'],
  ),
  RouteEntry(
    path: '/post-property',
    title: 'Post Property',
    tier: 'authenticated',
    section: 'listings',
    description: 'Create a new property listing',
    concepts: ['post property', 'create listing', 'add property', 'new listing', 'list property'],
    keywords: ['post', 'create', 'add', 'new', 'listing', 'property', 'sell', 'rent'],
  ),
  RouteEntry(
    path: '/notifications',
    title: 'Notifications',
    tier: 'authenticated',
    section: 'account',
    description: 'Notifications and alerts',
    concepts: ['notifications', 'alerts', 'messages', 'updates'],
    keywords: ['notification', 'alert', 'message', 'update', 'suchna'],
  ),
  RouteEntry(
    path: '/visits',
    title: 'My Visits',
    tier: 'authenticated',
    section: 'bookings',
    description: 'Property visit bookings',
    concepts: ['visits', 'my visits', 'visit bookings', 'appointments', 'schedule'],
    keywords: ['visit', 'booking', 'appointment', 'schedule', 'site visit'],
  ),
  RouteEntry(
    path: '/search-results',
    title: 'Search Results',
    tier: 'public',
    section: 'discovery',
    description: 'Property search results',
    concepts: ['search results', 'results', 'listings', 'properties list'],
    keywords: ['results', 'listings', 'properties'],
  ),
  RouteEntry(
    path: '/filters',
    title: 'Filters',
    tier: 'public',
    section: 'discovery',
    description: 'Search filters',
    concepts: ['filters', 'filter', 'search filters', 'refine'],
    keywords: ['filter', 'refine', 'narrow', 'sort'],
  ),

  // Dashboard routes
  RouteEntry(
    path: '/dashboard/broker',
    title: 'Broker Dashboard',
    tier: 'authenticated',
    section: 'dashboard',
    description: 'Broker management dashboard',
    concepts: ['broker dashboard', 'manage broker', 'broker panel'],
    keywords: ['broker', 'dashboard', 'manage', 'leads'],
  ),
  RouteEntry(
    path: '/dashboard/builder',
    title: 'Builder Dashboard',
    tier: 'authenticated',
    section: 'dashboard',
    description: 'Builder management dashboard',
    concepts: ['builder dashboard', 'manage builder', 'builder panel', 'projects'],
    keywords: ['builder', 'dashboard', 'manage', 'projects'],
  ),
  RouteEntry(
    path: '/dashboard/influencer',
    title: 'Influencer Dashboard',
    tier: 'authenticated',
    section: 'dashboard',
    description: 'Influencer management dashboard',
    concepts: ['influencer dashboard', 'manage influencer', 'content dashboard'],
    keywords: ['influencer', 'dashboard', 'content', 'reel', 'video'],
  ),
];

// ─── Tier resolution ──────────────────────────────────────────────────────────

const _adminRoles = {
  'admin', 'crm_manager', 'crm_agent', 'seo_manager',
  'content_editor', 'finance_manager', 'support_agent',
};

String roleToTier(String? role, bool isAuthenticated) {
  if (role == 'super_admin') return 'super_admin';
  if (role != null && _adminRoles.contains(role)) return 'admin';
  return isAuthenticated ? 'authenticated' : 'public';
}

bool _canAccess(String routeTier, String userTier) {
  const order = ['public', 'authenticated', 'admin', 'super_admin'];
  final routeIdx = order.indexOf(routeTier);
  final userIdx = order.indexOf(userTier);
  return userIdx >= routeIdx;
}

// ─── Concept resolver ─────────────────────────────────────────────────────────

/// Fuzzy-match [concept] against the route catalogue.
/// Returns the best-matching [RouteEntry] the user's tier can access, or null.
RouteEntry? resolveConcept(String concept, String userTier) {
  final lower = concept.trim().toLowerCase();
  RouteEntry? best;
  int bestScore = 0;

  for (final route in _routes) {
    if (!_canAccess(route.tier, userTier)) continue;

    int score = 0;

    // Exact concept match
    for (final c in route.concepts) {
      if (c.toLowerCase() == lower) {
        score += 5;
      } else if (c.toLowerCase().contains(lower) ||
          lower.contains(c.toLowerCase())) {
        score += 2;
      }
    }

    // Keyword partial match
    for (final k in route.keywords) {
      final words = lower.split(RegExp(r'\s+'));
      for (final w in words) {
        if (k.toLowerCase().contains(w) && w.length > 2) {
          score += 1;
        }
      }
    }

    if (score > bestScore) {
      bestScore = score;
      best = route;
    }
  }

  return bestScore > 0 ? best : null;
}

/// Exact path lookup.
RouteEntry? findByPath(String path) {
  try {
    return _routes.firstWhere((r) => r.path == path);
  } catch (_) {
    return null;
  }
}
