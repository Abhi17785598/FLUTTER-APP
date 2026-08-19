import 'dart:async';
import 'package:flutter/material.dart' hide Intent;
import '../../app_navigator.dart';
import '../../providers/auth_provider.dart';
import '../config/ai_config.dart';
import '../models/agent_response.dart';
import '../models/conversation_turn.dart';
import '../models/intent.dart';
import '../models/tool_context.dart';
import '../models/workflow_state.dart';
import '../prompt/system_prompt.dart';
import '../services/conversation_manager.dart';
import '../services/intent_stash.dart';
import '../services/speech_service.dart';
import '../services/voice_agent_service.dart';
import '../tools/registry.dart';

enum VoiceAgentStateEnum { idle, listening, processing, speaking, error }

class _VoiceAgentState {
  final VoiceAgentStateEnum agentState;
  final bool isOpen;
  final List<ConversationTurn> conversation;
  final String liveTranscript;
  final AgentResponse? lastResponse;
  final WorkflowState workflowState;
  final bool isTtsEnabled;

  const _VoiceAgentState({
    required this.agentState,
    required this.isOpen,
    required this.conversation,
    required this.liveTranscript,
    required this.lastResponse,
    required this.workflowState,
    required this.isTtsEnabled,
  });

  factory _VoiceAgentState.initial() => const _VoiceAgentState(
    agentState: VoiceAgentStateEnum.idle,
    isOpen: false,
    conversation: [],
    liveTranscript: '',
    lastResponse: null,
    workflowState: initialWorkflowState,
    isTtsEnabled: false,
  );

  _VoiceAgentState copyWith({
    VoiceAgentStateEnum? agentState,
    bool? isOpen,
    List<ConversationTurn>? conversation,
    String? liveTranscript,
    AgentResponse? lastResponse,
    WorkflowState? workflowState,
    bool clearLastResponse = false,
    bool? isTtsEnabled,
  }) {
    return _VoiceAgentState(
      agentState: agentState ?? this.agentState,
      isOpen: isOpen ?? this.isOpen,
      conversation: conversation ?? this.conversation,
      liveTranscript: liveTranscript ?? this.liveTranscript,
      lastResponse: clearLastResponse
          ? null
          : (lastResponse ?? this.lastResponse),
      workflowState: workflowState ?? this.workflowState,
      isTtsEnabled: isTtsEnabled ?? this.isTtsEnabled,
    );
  }
}

class VoiceAgentProvider extends ChangeNotifier {
  AuthProvider _auth;

  _VoiceAgentState _state = _VoiceAgentState.initial();

  VoiceAgentProvider(this._auth) {
    _auth.addListener(_onAuthChanged);
  }

  /// Called by ChangeNotifierProxyProvider when AuthProvider updates.
  void updateAuth(AuthProvider auth) {
    _auth = auth;
    // Auth listener is already attached; no need to re-add.
  }

  // ─── Public state getters ──────────────────────────────────────────────────

  VoiceAgentStateEnum get agentState => _state.agentState;
  bool get isOpen => _state.isOpen;
  List<ConversationTurn> get conversation => _state.conversation;
  String get liveTranscript => _state.liveTranscript;
  AgentResponse? get lastResponse => _state.lastResponse;
  WorkflowState get workflowState => _state.workflowState;
  bool get isProcessing => _state.agentState == VoiceAgentStateEnum.processing;
  bool get isListening => _state.agentState == VoiceAgentStateEnum.listening;
  bool get isSpeaking => _state.agentState == VoiceAgentStateEnum.speaking;
  bool get isTtsEnabled => _state.isTtsEnabled;

  void toggleTts() {
    final newValue = !_state.isTtsEnabled;
    speechService.setTtsEnabled(newValue);
    _state = _state.copyWith(isTtsEnabled: newValue);
    notifyListeners();
  }

  // Phase 3: canPersistHistory gates DB persistence.
  bool get canPersistHistory => _auth.isLoggedIn;

  // ─── Panel control ─────────────────────────────────────────────────────────

  void togglePanel() {
    _state = _state.copyWith(isOpen: !_state.isOpen);
    notifyListeners();
  }

  void openPanel() {
    if (!_state.isOpen) {
      _state = _state.copyWith(isOpen: true);
      notifyListeners();
    }
  }

  void closePanel() {
    if (_state.isOpen) {
      _state = _state.copyWith(isOpen: false);
      notifyListeners();
    }
  }

  // ─── processText pipeline ──────────────────────────────────────────────────

  Future<void> processText(String userText, BuildContext context) async {
    if (userText.trim().isEmpty) return;

    _state = _state.copyWith(
      agentState: VoiceAgentStateEnum.processing,
      liveTranscript: '',
    );
    notifyListeners();

    // 1. Add user turn.
    conversationManager.addTurn(role: 'user', text: userText);
    // Phase 3: saveTurn(_auth.userId, userTurn) here — store return value then.
    _state = _state.copyWith(
      conversation: List.of(conversationManager.getHistory()),
    );
    notifyListeners();

    AgentResponse response;
    try {
      // 2. Build tiered system prompt.
      final prompt = buildSystemPrompt(
        PromptContext(
          isAuthenticated: _auth.isLoggedIn,
          role: _auth.userRole,
          userType: _auth.userType,
          displayName: _auth.userName.isNotEmpty ? _auth.userName : null,
          profileCity: _auth.profileCity, // added in Step 17
        ),
      );

      // 3. Phase 3: knowledgeContext = await retrieveContext(userText) — no-op now.
      const knowledgeContext = '';

      // 4. Call OpenAI via openai-proxy.
      final history = conversationManager.getContextHistory();
      response = await processVoiceCommand(
        userText: userText,
        history: history,
        systemPrompt: prompt,
        knowledgeContext: knowledgeContext,
      );
    } catch (e) {
      conversationManager.addTurn(
        role: 'assistant',
        text: '⚠️ ${e.toString()}',
        intent: Intent.unknown,
      );
      _state = _state.copyWith(
        conversation: List.of(conversationManager.getHistory()),
        agentState: VoiceAgentStateEnum.error,
      );
      notifyListeners();
      // Auto-clear error state after 3 seconds.
      Future.delayed(const Duration(seconds: 3), () {
        if (_state.agentState == VoiceAgentStateEnum.error) {
          _state = _state.copyWith(agentState: VoiceAgentStateEnum.idle);
          notifyListeners();
        }
      });
      return;
    }

    // 5. Autonomous mode override.
    if (AiConfig.isAutonomous &&
        response.intent != Intent.confirm &&
        response.intent != Intent.create_listing) {
      response = response.copyWith(
        needsConfirmation: AiConfig.alwaysConfirmIntents.contains(
          response.intent,
        ),
        missingFields: [],
        complete: true,
      );
    }

    _state = _state.copyWith(lastResponse: response);

    // 6. Confirmation resolution.
    var resolvedIntent = response.intent;
    var resolvedParams = response.parameters;
    final ws = _state.workflowState;

    if (response.intent == Intent.confirm) {
      final confirmResponse =
          (response.parameters['response'] as String?) ?? '';
      if (confirmResponse == 'yes' &&
          ws.pendingConfirmation &&
          ws.confirmationPayload != null) {
        resolvedIntent = ws.confirmationPayload!.intent;
        resolvedParams = ws.confirmationPayload!.parameters;
      } else if (confirmResponse == 'no') {
        _state = _state.copyWith(workflowState: initialWorkflowState);
      }
    }

    // 7. Execute tool if conditions are met.
    String spokenText = response.response;
    bool toolFailed = false;
    final shouldExec = _shouldExecuteTool(response, ws);

    if (shouldExec) {
      final ctx = ToolContext(
        navigate: (route) {
          // Use the global navigator key — reliable even after the panel closes.
          appNavigatorKey.currentState?.pushNamed(route);
        },
        userId: _auth.userId,
        userRole: _auth.userRole,
        userType: _auth.userType,
        displayName: _auth.userName.isNotEmpty ? _auth.userName : null,
        profileCity: _auth.profileCity,
        isAdmin: false, // Phase 2: wire to RBAC.
        isSuperAdmin: false, // Phase 2: wire to RBAC.
        // The canonical sign-out — `_auth` is the live AuthProvider (kept in
        // sync by `updateAuth` on every rebuild), so `logout`/`delete_account`
        // in profile_tools.dart clear cached identity the same way the logout
        // dialog does, instead of signing out through Supabase directly.
        signOut: _auth.logout,
      );
      final result = await toolRegistry.execute(
        resolvedIntent.name,
        resolvedParams,
        ctx,
      );
      if (!result.success && result.userMessage != null) {
        spokenText = result.userMessage!;
        toolFailed = true;
      } else if (result.success && result.userMessage != null) {
        spokenText = result.userMessage!;
      }
    }

    // 8. Update workflow state.
    _updateWorkflow(response, ws);

    // 9. Add assistant turn with raw JSON for multi-turn context.
    conversationManager.addTurn(
      role: 'assistant',
      text: spokenText,
      rawJsonText: response.toJson(),
      intent: response.intent,
      toolExecuted: shouldExec ? resolvedIntent.name : null,
      toolSuccess: shouldExec ? !toolFailed : null,
    );
    // Phase 3: saveTurn(_auth.userId, assistantTurn) here — store return value then.
    _state = _state.copyWith(
      conversation: List.of(conversationManager.getHistory()),
      agentState: _state.isTtsEnabled
          ? VoiceAgentStateEnum.speaking
          : VoiceAgentStateEnum.idle,
    );
    notifyListeners();

    if (_state.isTtsEnabled) {
      await speechService.speak(spokenText);
      _state = _state.copyWith(agentState: VoiceAgentStateEnum.idle);
      notifyListeners();
    }
  }

  // ─── Voice input ───────────────────────────────────────────────────────────

  void startListening(BuildContext context) {
    if (_state.agentState != VoiceAgentStateEnum.idle) return;

    _state = _state.copyWith(
      agentState: VoiceAgentStateEnum.listening,
      liveTranscript: '',
    );
    notifyListeners();

    unawaited(
      speechService.startRecording(
        onResult: (text) {
          // Transcription arrived from Whisper — show it briefly then process.
          _state = _state.copyWith(liveTranscript: text);
          notifyListeners();
          processText(text, context);
        },
        onError: (error) {
          _state = _state.copyWith(
            agentState: VoiceAgentStateEnum.error,
            liveTranscript: '',
          );
          notifyListeners();
          Future.delayed(const Duration(seconds: 3), () {
            if (_state.agentState == VoiceAgentStateEnum.error) {
              _state = _state.copyWith(agentState: VoiceAgentStateEnum.idle);
              notifyListeners();
            }
          });
        },
      ),
    );
  }

  void stopListening() {
    // Stop and transcribe — the user tapped the stop button to submit their speech.
    // stopRecording() → _transcribe() → onResult() → processText()
    unawaited(speechService.stopRecording());
    _state = _state.copyWith(
      agentState: VoiceAgentStateEnum.processing,
      liveTranscript: '',
    );
    notifyListeners();
  }

  // ─── Workflow control ──────────────────────────────────────────────────────

  void cancelWorkflow() {
    _state = _state.copyWith(workflowState: initialWorkflowState);
    notifyListeners();
  }

  void clearConversation() {
    conversationManager.clear();
    IntentStash.clear();
    _state = _state.copyWith(
      conversation: [],
      workflowState: initialWorkflowState,
    );
    notifyListeners();
  }

  // ─── Auth change handler ───────────────────────────────────────────────────

  void _onAuthChanged() {
    // Clear conversation and stash on any auth state change (sign in / sign out).
    conversationManager.clear();
    IntentStash.clear();
    _state = _state.copyWith(
      conversation: [],
      workflowState: initialWorkflowState,
    );
    notifyListeners();
  }

  // ─── Private helpers ───────────────────────────────────────────────────────

  bool _shouldExecuteTool(AgentResponse r, WorkflowState ws) {
    if (r.intent == Intent.unknown) return false;
    if (r.intent == Intent.ask_platform) return false;
    if (r.intent == Intent.ask_about_platform) return false;
    if (r.intent == Intent.ask_property_info) return false;

    if (r.intent == Intent.confirm) {
      return (r.parameters['response'] as String?) == 'yes' &&
          ws.pendingConfirmation;
    }

    if (r.intent == Intent.auth_required || r.intent == Intent.suggest_signup) {
      // Provider will navigate to /auth if user says yes on next turn.
      return false;
    }

    if (!r.complete) return false;
    if (r.needsConfirmation) return false;
    return true;
  }

  void _updateWorkflow(AgentResponse r, WorkflowState prevWs) {
    WorkflowState next;

    if (r.needsConfirmation && r.complete) {
      // Gate: store payload, wait for confirm intent.
      next = WorkflowState(
        activeIntent: r.intent,
        collectedParams: r.parameters,
        missingFields: r.missingFields,
        pendingConfirmation: true,
        confirmationPayload: r,
      );
    } else if (!r.complete) {
      // Mid slot-fill: track active intent and collected fields.
      next = WorkflowState(
        activeIntent: r.intent,
        collectedParams: r.parameters,
        missingFields: r.missingFields,
        pendingConfirmation: false,
        confirmationPayload: null,
      );
    } else {
      // Complete with no confirmation needed: reset workflow.
      next = initialWorkflowState;
    }

    _state = _state.copyWith(workflowState: next);
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
