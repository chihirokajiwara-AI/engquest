import 'package:flutter/material.dart';
import 'package:engquest/core/dialog/claude_client.dart';
import 'package:engquest/core/dialog/dialog_service.dart';
import 'package:engquest/core/dialog/suggestion_engine.dart';
import 'package:engquest/core/ui/page_transitions.dart';

// ---------------------------------------------------------------------------
// DialogScenariosScreen — pick a scenario to start chatting
// ---------------------------------------------------------------------------

/// Entry point for the Dialog module. Shows the three NPC scenarios.
class DialogScenariosScreen extends StatelessWidget {
  const DialogScenariosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4FC3F7), Color(0xFF29B6F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '💬 NPC Conversations',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '誰と話す？',
              style: TextStyle(color: Color(0xFF607D8B), fontSize: 16),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: DialogScenario.values
                    .map((s) => _ScenarioCard(scenario: s))
                    .toList(),
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

  static const Map<DialogScenario, Color> _cardColors = {
    DialogScenario.greetNpc: Color(0xFF4FC3F7),
    DialogScenario.shopDialog: Color(0xFFFFB74D),
    DialogScenario.battleIntro: Color(0xFFEF5350),
  };

  static const Map<DialogScenario, String> _descriptions = {
    DialogScenario.greetNpc: '👋 あいさつ・自己紹介を練習しよう',
    DialogScenario.shopDialog: '🛍️ かずとものの名前を練習しよう',
    DialogScenario.battleIntro: '⚔️ アクションことばを練習しよう',
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _cardColors[scenario],
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            FadeSlideRoute(
              builder: (_) => DialogScreen(scenario: scenario),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Text(scenario.npcEmoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scenario.npcName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _descriptions[scenario]!,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
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

  const DialogScreen({
    super.key,
    this.scenario = DialogScenario.greetNpc,
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
    // Initial NPC greeting
    _addNpcGreeting();
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _OfflineBanner(isOffline: ClaudeClient().isOfflineMode),
          Expanded(child: _buildMessageList()),
          if (_isLoading) const _TypingIndicator(),
          _buildQuickReplies(),
          _buildInputRow(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4FC3F7), Color(0xFF29B6F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Text(widget.scenario.npcEmoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.scenario.npcName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const Text(
                  'AI搭載 (Anthropic Claude)',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: const Color(0xFFFFFFFF),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: suggestions.map((reply) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(
                  reply,
                  style:
                      const TextStyle(color: Color(0xFF263238), fontSize: 12),
                ),
                backgroundColor: const Color(0xFFE3F2FD),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFF4FC3F7), width: 0.5),
                ),
                onPressed: _isLoading ? null : () => _sendMessage(reply),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInputRow() {
    return Container(
      color: const Color(0xFFFFFFFF),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: Color(0xFF263238)),
              decoration: InputDecoration(
                hintText: '英語で話しかけよう...',
                hintStyle: const TextStyle(color: Color(0xFF90A4AE)),
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: _isLoading ? null : _sendMessage,
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.amber,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap:
                  _isLoading ? null : () => _sendMessage(_textController.text),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.send, color: Colors.black, size: 20),
              ),
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
                Text(widget.npcEmoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isNpc
                        ? const Color(0xFFE3F2FD)
                        : const Color(0xFF4FC3F7),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(_isNpc ? 4 : 18),
                      bottomRight: Radius.circular(_isNpc ? 18 : 4),
                    ),
                  ),
                  child: Text(
                    widget.message.content,
                    style: TextStyle(
                      color: _isNpc ? const Color(0xFF263238) : Colors.white,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              if (!_isNpc) ...[
                const SizedBox(width: 8),
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0xFF4CAF50),
                  child: Text('🧑', style: TextStyle(fontSize: 14)),
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(18),
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
          color: Color(0xFF4FC3F7),
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
      color: const Color(0xFFFFF3E0),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: const Text(
        '📴 今はオフラインです。接続を確認してください。',
        style: TextStyle(color: Color(0xFFE65100), fontSize: 11),
        textAlign: TextAlign.center,
      ),
    );
  }
}
