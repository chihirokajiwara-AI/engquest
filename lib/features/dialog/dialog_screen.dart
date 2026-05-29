import 'package:flutter/material.dart';
import 'package:engquest/core/config/app_config.dart';
import 'package:engquest/core/dialog/claude_client.dart';
import 'package:engquest/core/dialog/dialog_service.dart';

// ---------------------------------------------------------------------------
// DialogScenariosScreen — pick a scenario to start chatting
// ---------------------------------------------------------------------------

/// Entry point for the Dialog module. Shows the three NPC scenarios.
class DialogScenariosScreen extends StatelessWidget {
  const DialogScenariosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '💬 NPC Conversations',
          style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
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
              style: TextStyle(color: Colors.white70, fontSize: 16),
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
    DialogScenario.greetNpc: Color(0xFF2D6A4F),
    DialogScenario.shopDialog: Color(0xFF6A4C2D),
    DialogScenario.battleIntro: Color(0xFF6A2D2D),
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
            MaterialPageRoute(
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
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
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
/// canned responses when [kClaudeApiKey] is 'REPLACE_WITH_KEY'.
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
  final List<ChatMessage> _history = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _service = DialogService(
      client: ClaudeClient(apiKey: kClaudeApiKey),
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
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _OfflineBanner(isOffline: ClaudeClient(apiKey: kClaudeApiKey).isOfflineMode),
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
      backgroundColor: const Color(0xFF16213E),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Text(widget.scenario.npcEmoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Text(
            widget.scenario.npcName,
            style: const TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              fontSize: 18,
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

  Widget _buildQuickReplies() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: const Color(0xFF16213E),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: widget.scenario.quickReplies.map((reply) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(
                  reply,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                backgroundColor: const Color(0xFF2E4057),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Colors.amber, width: 0.5),
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
      color: const Color(0xFF16213E),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '英語で話しかけよう...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF2A2A40),
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
              onTap: _isLoading
                  ? null
                  : () => _sendMessage(_textController.text),
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

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final String npcEmoji;

  const _ChatBubble({required this.message, required this.npcEmoji});

  bool get _isNpc => message.role == 'assistant';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            _isNpc ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isNpc) ...[
            Text(npcEmoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _isNpc
                    ? const Color(0xFF2D3561)
                    : const Color(0xFF2E7D32),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(_isNpc ? 4 : 18),
                  bottomRight: Radius.circular(_isNpc ? 18 : 4),
                ),
              ),
              child: Text(
                message.content,
                style: const TextStyle(color: Colors.white, fontSize: 15),
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
              color: const Color(0xFF2D3561),
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
          color: Colors.white70,
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
      color: const Color(0xFF5D4037),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: const Text(
        '📴 今はオフラインです。接続を確認してください。',
        style: TextStyle(color: Colors.orange, fontSize: 11),
        textAlign: TextAlign.center,
      ),
    );
  }
}
