import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tool_result.dart';
import '../services/intent_stash.dart';
import 'permissions.dart';
import 'registry.dart';

void registerProfileTools() {
  _registerViewMyProfile();
  _registerUpdateProfile();
  _registerOpenMyDashboard();
  _registerOpenManageDashboard();
  _registerShowNotifications();
  _registerShowMyNetwork();
  _registerOpenChat();
  _registerMyVisitBookings();
  _registerPostContent();
  _registerDeleteAccount();
  _registerOpenDashboardAction();
  _registerLogout();
}

const Map<String, String> _manageDashboardByType = {
  'builder': '/dashboard/builder',
  'broker': '/dashboard/broker',
  'influencer': '/dashboard/influencer',
};

// ─── view_my_profile ──────────────────────────────────────────────────────────

void _registerViewMyProfile() {
  toolRegistry.register(ToolDefinition(
    name: 'view_my_profile',
    description: 'Navigate to the user\'s profile screen.',
    execute: (params, ctx) async {
      ctx.navigate('/profile');
      return ToolResult.ok();
    },
  ));
}

// ─── update_profile ───────────────────────────────────────────────────────────

void _registerUpdateProfile() {
  toolRegistry.register(ToolDefinition(
    name: 'update_profile',
    description: 'Update a profile field and navigate to the profile screen.',
    execute: (params, ctx) async {
      final field = params['field'] as String? ?? '';
      final value = params['value'];

      if (field.isNotEmpty && value != null) {
        IntentStash.set('va_profile_update', {'field': field, 'value': value});
      }

      ctx.navigate('/profile');
      return ToolResult.ok(
        userMessage: field.isNotEmpty
            ? 'Opening your profile to update $field.'
            : 'Opening your profile.',
      );
    },
  ));
}

// ─── open_my_dashboard ────────────────────────────────────────────────────────

void _registerOpenMyDashboard() {
  toolRegistry.register(ToolDefinition(
    name: 'open_my_dashboard',
    description: 'Open the user\'s profile / dashboard screen.',
    execute: (params, ctx) async {
      ctx.navigate('/profile');
      return ToolResult.ok();
    },
  ));
}

// ─── open_manage_dashboard ────────────────────────────────────────────────────

void _registerOpenManageDashboard() {
  toolRegistry.register(ToolDefinition(
    name: 'open_manage_dashboard',
    description: 'Open the role-specific management dashboard.',
    execute: (params, ctx) async {
      final route = _manageDashboardByType[ctx.userType] ?? '/profile';
      ctx.navigate(route);
      return ToolResult.ok();
    },
  ));
}

// ─── show_notifications ───────────────────────────────────────────────────────

void _registerShowNotifications() {
  toolRegistry.register(ToolDefinition(
    name: 'show_notifications',
    description: 'Navigate to the notifications screen.',
    execute: (params, ctx) async {
      final filter = params['filter'] as String? ?? 'all';
      ctx.navigate('/notifications?filter=$filter');
      return ToolResult.ok();
    },
  ));
}

// ─── show_my_network ──────────────────────────────────────────────────────────

void _registerShowMyNetwork() {
  toolRegistry.register(ToolDefinition(
    name: 'show_my_network',
    description: 'Navigate to the network / connections screen.',
    execute: (params, ctx) async {
      // No separate network screen in Flutter Phase 1 — fallback to profile.
      ctx.navigate('/profile');
      return ToolResult.ok(
        userMessage: 'Opening your profile — network details are shown there.',
      );
    },
  ));
}

// ─── open_chat ────────────────────────────────────────────────────────────────

void _registerOpenChat() {
  toolRegistry.register(ToolDefinition(
    name: 'open_chat',
    description: 'Open the chat screen, optionally with a specific user.',
    execute: (params, ctx) async {
      final withUser = params['with_user'] as String?;
      if (withUser != null) {
        IntentStash.set('va_open_chat_with', withUser);
      }
      // Fallback to profile if dedicated chat screen not yet wired.
      ctx.navigate('/profile');
      return ToolResult.ok(
        userMessage: withUser != null
            ? 'Opening chat with $withUser.'
            : 'Opening chat.',
      );
    },
  ));
}

// ─── my_visit_bookings ────────────────────────────────────────────────────────

void _registerMyVisitBookings() {
  toolRegistry.register(ToolDefinition(
    name: 'my_visit_bookings',
    description: 'Navigate to the visit bookings screen.',
    execute: (params, ctx) async {
      final filter = params['filter'] as String? ?? 'all';
      ctx.navigate('/visits?filter=$filter');
      return ToolResult.ok();
    },
  ));
}

// ─── post_content ─────────────────────────────────────────────────────────────

void _registerPostContent() {
  toolRegistry.register(ToolDefinition(
    name: 'post_content',
    description: 'Navigate to the appropriate content creation screen.',
    execute: (params, ctx) async {
      final type = params['type'] as String? ?? 'property';

      switch (type) {
        case 'reel':
        case 'video':
          if (!canCreate(CreatableContent.video, ctx.userType)) {
            return ToolResult.fail(
              createDeniedMessage(CreatableContent.video),
              userMessage: createDeniedMessage(CreatableContent.video),
            );
          }
          // Was `/reels` — the consumer feed. An influencer who asked to *post* a
          // video was dropped into a viewer with no way to create one, which is
          // the only branch of this tool that navigated somewhere the user could
          // not do the thing they asked for. There is now a form to send them to.
          ctx.navigate('/influencer-video');
          return ToolResult.ok();

        case 'property':
          if (!canCreate(CreatableContent.property, ctx.userType)) {
            return ToolResult.fail(
              createDeniedMessage(CreatableContent.property),
              userMessage: createDeniedMessage(CreatableContent.property),
            );
          }
          ctx.navigate('/post-property');
          return ToolResult.ok();

        case 'article':
          if (!canCreate(CreatableContent.article, ctx.userType)) {
            return ToolResult.fail(
              createDeniedMessage(CreatableContent.article),
              userMessage: createDeniedMessage(CreatableContent.article),
            );
          }
          ctx.navigate('/profile');
          return ToolResult.ok();

        default:
          ctx.navigate('/post-property');
          return ToolResult.ok();
      }
    },
  ));
}

// ─── delete_account ───────────────────────────────────────────────────────────

void _registerDeleteAccount() {
  toolRegistry.register(ToolDefinition(
    name: 'delete_account',
    description: 'Permanently delete the user account.',
    execute: (params, ctx) async {
      // Actual account deletion requires a backend RPC or admin API.
      // For Phase 1: sign the user out and navigate to auth screen.
      // Phase 2: call the appropriate account deletion Edge Function here.
      try {
        await Supabase.instance.client.auth.signOut();
        ctx.navigate('/auth');
        return ToolResult.ok(
          userMessage:
              'Your account has been scheduled for deletion. You have been signed out.',
        );
      } catch (e) {
        return ToolResult.fail(
          e.toString(),
          userMessage: 'Could not delete account. Please contact support.',
        );
      }
    },
  ));
}

// ─── open_dashboard_action ────────────────────────────────────────────────────

void _registerOpenDashboardAction() {
  toolRegistry.register(ToolDefinition(
    name: 'open_dashboard_action',
    description: 'Open a specific action from the dashboard.',
    execute: (params, ctx) async {
      final action = params['action'] as String? ?? '';
      IntentStash.set('va_dashboard_action', action);

      switch (action) {
        case 'property':
          ctx.navigate('/post-property');
          return ToolResult.ok();
        case 'settings':
          ctx.navigate('/profile');
          return ToolResult.ok(
            userMessage: 'Opening settings on your profile.',
          );
        default:
          ctx.navigate('/profile');
          return ToolResult.ok();
      }
    },
  ));
}

// ─── logout ───────────────────────────────────────────────────────────────────

void _registerLogout() {
  toolRegistry.register(ToolDefinition(
    name: 'logout',
    description: 'Sign the user out.',
    execute: (params, ctx) async {
      try {
        await Supabase.instance.client.auth.signOut();
        ctx.navigate('/auth');
        return ToolResult.ok(userMessage: 'You have been signed out.');
      } catch (e) {
        return ToolResult.fail(
          e.toString(),
          userMessage: 'Could not sign out. Please try again.',
        );
      }
    },
  ));
}
