import 'package:flutter/material.dart';
import 'package:engquest/core/dialog/claude_client.dart';
import 'package:engquest/core/dialog/dialog_service.dart';
import 'package:engquest/core/dialog/suggestion_engine.dart';
import 'package:engquest/core/ui/page_transitions.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';

// ---------------------------------------------------------------------------
// DialogScenariosScreen — pick a scenario to start chatting
// ---------------------------------------------------------------------------

/// Entry point for the Dialog module. Shows the three NPC scenarios.
class DialogScenariosScreen extends StatelessWidget {
  const DialogScenariosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The scenario list is short (3 cards) — a plain ListView left ~45% empty
    // navy void below the last card (#CEO quality crisis). Use a centred
    // scrollable column so the cards fill the frame vertically when the content
    // is shorter than the screen, while still scrolling on tiny screens.
    final cards =
        DialogScenario.values.map((s) => _ScenarioCard(scenario: s)).toList();
    return DqScene(
      contentMaxWidth: 600, // #144: centre on tablet, full-width on phone
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DqHeader(
              jp: '会話',
              en: 'Talk',
              onBack: () => Navigator.pop(context),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 14),
              child: dqBilingual('誰と話す？', 'Who will you talk to?',
                  jpSize: 14, jpColor: dqInk),
            ),
            // Centre the small card list so it reads as intentionally placed,
            // not top-anchored in an empty frame.
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: cards,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final DialogScenario scenario;
  const _ScenarioCard({required this.scenario});

  /// Bilingual objective shown beneath the NPC name (JP / EN).
  static const Map<DialogScenario, (String, String)> _objectives = {
    DialogScenario.greetNpc: ('あいさつ・自己紹介', 'Greetings & introductions'),
    DialogScenario.shopDialog: ('かず・ものの名前', 'Numbers & item names'),
    DialogScenario.battleIntro: ('アクションことば', 'Action words'),
  };

  @override
  Widget build(BuildContext context) {
    final obj = _objectives[scenario]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            FadeSlideRoute(
              builder: (_) => DialogScreen(scenario: scenario),
            ),
          );
        },
        child: DqPanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              DqPortrait(emoji: scenario.npcEmoji, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(scenario.npcName,
                        style: dqText(size: 17, w: FontWeight.w700)),
                    const SizedBox(height: 5),
                    dqBilingual(obj.$1, obj.$2, jpSize: 12, jpColor: dqInk),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DqHeader — dark header (back arrow + gold serif bilingual title)
// ---------------------------------------------------------------------------

class _DqHeader extends StatelessWidget {
  final String jp;
  final String en;
  final VoidCallback onBack;
  final Widget? trailing;
  const _DqHeader({
    required this.jp,
    required this.en,
    required this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.arrow_back, color: dqGold, size: 26),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: dqBilingual(jp, en, jpSize: 22, jpColor: dqInk)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DialogScreen — the actual chat interface with an NPC
// ---------------------------------------------------------------------------

/// Chat UI for talking with an NPC in [scenario].
/// Uses [DialogService] backed by [ClaudeClient]; falls back to offline
/// canned responses when no backend is configured.
class DialogScreen extends StatefulWidget {
  final DialogScenario scenario;

  /// When false, the screen does NOT fire the initial NPC greeting (which makes
  /// a network call to the Claude backend). Renders the chat shell only.
  /// Defaults to true; set false in widget tests to keep initState R4-clean.
  final bool autoGreet;

  const DialogScreen({
    super.key,
    this.scenario = DialogScenario.greetNpc,
    this.autoGreet = true,
  });

  @override
  State<DialogScreen> createState() => _DialogScreenState();
}

class _DialogScreenState extends State<DialogScreen> {
  late final DialogService _service;
  final SuggestionEngine _suggestionEngine = const SuggestionEngine();
  final List<ChatMessage> _history = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _service = DialogService(
      client: ClaudeClient(),
    );
    // Initial NPC greeting (network call — suppressed in tests via autoGreet).
    if (widget.autoGreet) _addNpcGreeting();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _addNpcGreeting() async {
    await _sendMessage('Hello!', isGreeting: true);
  }

  Future<void> _sendMessage(String text, {bool isGreeting = false}) async {
    if (text.trim().isEmpty) return;

    if (!isGreeting) {
      setState(() {
        _history.add(ChatMessage(role: 'user', content: text));
      });
    }
    _textController.clear();

    setState(() => _isLoading = true);

    try {
      final response = await _service.chat(
        scenario: widget.scenario,
        history: _history
            .where((m) => m.role == 'user' || m.role == 'assistant')
            .toList(),
        userInput: text,
      );

      setState(() {
        _history.add(ChatMessage(role: 'assistant', content: response));
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DqScene(
      contentMaxWidth: 600, // #144: centre on tablet, full-width on phone
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            _buildHeader(),
            _OfflineBanner(isOffline: ClaudeClient().isOfflineMode),
            Expanded(child: _buildMessageList()),
            if (_isLoading) const _TypingIndicator(),
            _buildQuickReplies(),
            _buildInputRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return _DqHeader(
      jp: widget.scenario.npcName,
      en: 'AI / Anthropic Claude',
      onBack: () => Navigator.pop(context),
      trailing: DqPortrait(emoji: widget.scenario.npcEmoji, size: 40),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      itemCount: _history.length,
      itemBuilder: (_, index) {
        final msg = _history[index];
        return _ChatBubble(
          message: msg,
          npcEmoji: widget.scenario.npcEmoji,
        );
      },
    );
  }

  /// The most recent NPC (assistant) message, used to pick contextual chips.
  String? get _lastNpcMessage {
    for (var i = _history.length - 1; i >= 0; i--) {
      if (_history[i].role == 'assistant') return _history[i].content;
    }
    return null;
  }

  Widget _buildQuickReplies() {
    final suggestions = _suggestionEngine.suggestionsFor(
      widget.scenario,
      lastNpcMessage: _lastNpcMessage,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: suggestions.map((reply) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: _isLoading ? null : () => _sendMessage(reply),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: dqBox.withAlpha(220),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: dqGoldDeep, width: 1.5),
                  ),
                  child: Text(reply, style: dqText(size: 13, color: dqInk)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInputRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: dqText(size: 15, color: Colors.white),
              cursorColor: dqGold,
              decoration: InputDecoration(
                hintText: '英語で話しかけよう / Speak in English...',
                hintStyle: dqText(size: 13, color: dqInk).copyWith(
                  shadows: const [],
                ),
                filled: true,
                fillColor: dqBox.withAlpha(220),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: dqBorder, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: dqGold, width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: _isLoading ? null : _sendMessage,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isLoading ? null : () => _sendMessage(_textController.text),
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _isLoading
                    ? const LinearGradient(
                        colors: [Color(0xFF5A5448), Color(0xFF3E3A32)])
                    : const LinearGradient(colors: [dqGold, dqGoldDeep]),
                border: Border.all(color: dqBorder, width: 1.5),
                boxShadow: _isLoading
                    ? null
                    : [
                        BoxShadow(
                            color: dqGoldDeep.withAlpha(120), blurRadius: 10)
                      ],
              ),
              child: const Icon(Icons.send, color: Color(0xFF2A1C00), size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _ChatBubble extends StatefulWidget {
  final ChatMessage message;
  final String npcEmoji;

  const _ChatBubble({required this.message, required this.npcEmoji});

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool get _isNpc => widget.message.role == 'assistant';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    final curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    // NPC slides from left, user slides from right
    _slideAnim = Tween<Offset>(
      begin: Offset(_isNpc ? -0.15 : 0.15, 0.0),
      end: Offset.zero,
    ).animate(curved);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment:
                _isNpc ? MainAxisAlignment.start : MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_isNpc) ...[
                DqPortrait(emoji: widget.npcEmoji, size: 36),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(
                    color:
                        _isNpc ? dqBox.withAlpha(235) : dqNight1.withAlpha(235),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(10),
                      topRight: const Radius.circular(10),
                      bottomLeft: Radius.circular(_isNpc ? 2 : 10),
                      bottomRight: Radius.circular(_isNpc ? 10 : 2),
                    ),
                    border: Border.all(
                      color: _isNpc ? dqBorder : dqGold,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    widget.message.content,
                    style: dqText(
                      size: 15,
                      w: FontWeight.w500,
                      color: _isNpc ? dqInk : Colors.white,
                    ),
                  ),
                ),
              ),
              if (!_isNpc) ...[
                const SizedBox(width: 8),
                const DqPortrait(emoji: '🧑', size: 30),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: dqBox.withAlpha(235),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: dqBorder, width: 1.5),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0),
                SizedBox(width: 4),
                _Dot(delay: 200),
                SizedBox(width: 4),
                _Dot(delay: 400),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: dqGold,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final bool isOffline;
  const _OfflineBanner({required this.isOffline});

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: dqNight1.withAlpha(235),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: dqGoldDeep, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
      child: Text(
        '📴 今はオフラインです / Offline — check your connection.',
        style: dqText(size: 11, color: dqGold),
        textAlign: TextAlign.center,
      ),
    );
  }
}
