import 'package:flutter/material.dart';
import 'package:engquest/core/firebase/parent_auth_service.dart';
import '../quest/ui/dq_ui.dart';
import 'parent_dashboard_screen.dart';

/// Parent login / signup screen.
///
/// Two tabs: ログイン (login) and 新規登録 (sign up).
/// After auth, prompts for a link code to connect to a child's account.
///
/// Styled to match the dark-navy/gold DQ canon (#947) so parents flow
/// seamlessly from the app into this screen without a jarring palette shift.
class ParentLoginScreen extends StatefulWidget {
  const ParentLoginScreen({super.key});

  @override
  State<ParentLoginScreen> createState() => _ParentLoginScreenState();
}

class _ParentLoginScreenState extends State<ParentLoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _parentAuth = ParentAuthService();

  // Form controllers
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _linkCodeCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  // After auth, switch to link code phase
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);

    // Check if already logged in as parent
    try {
      if (_parentAuth.isParentUser) {
        _authenticated = true;
        _loadLinkedChildren();
      }
    } catch (_) {
      // Firebase not initialized (e.g. in tests)
    }
  }

  Future<void> _loadLinkedChildren() async {
    try {
      final children = await _parentAuth.getLinkedChildren();
      if (mounted && children.isNotEmpty) {
        _navigateToDashboard(children.first);
      }
    } catch (_) {
      // Ignore — will show link code entry
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _linkCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_loading) return;
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'メールアドレスとパスワードを入力してください');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _parentAuth.signIn(email, password);
      if (!mounted) return;
      setState(() => _authenticated = true);
      await _loadLinkedChildren();
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _firebaseErrorMessage(e);
        });
      }
    }
  }

  Future<void> _handleSignUp() async {
    if (_loading) return;
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'メールアドレスとパスワードを入力してください');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'パスワードは6文字以上にしてください');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'パスワードが一致しません');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _parentAuth.signUp(email, password);
      if (!mounted) return;
      setState(() {
        _authenticated = true;
        _loading = false;
      });
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _firebaseErrorMessage(e);
        });
      }
    }
  }

  Future<void> _handleLinkCode() async {
    if (_loading) return;
    final code = _linkCodeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'リンクコードを入力してください');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final childUid = await _parentAuth.redeemLinkCode(code);
      if (!mounted) return;
      _navigateToDashboard(childUid);
    } on LinkCodeException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _firebaseErrorMessage(e);
        });
      }
    }
  }

  void _navigateToDashboard(String childUid) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        // Pass the redeemed childUid so the dashboard reads the LINKED CHILD's
        // progress, not this parent device's own (empty) data. Before this the
        // childUid was fetched then dropped → every metric showed zero.
        builder: (_) => ParentDashboardScreen(childUid: childUid),
      ),
    );
  }

  String _firebaseErrorMessage(Exception e) {
    final msg = e.toString();
    if (msg.contains('user-not-found') || msg.contains('wrong-password')) {
      return 'メールアドレスまたはパスワードが間違っています';
    }
    if (msg.contains('email-already-in-use')) {
      return 'このメールアドレスは既に登録されています';
    }
    if (msg.contains('invalid-email')) {
      return 'メールアドレスの形式が正しくありません';
    }
    if (msg.contains('weak-password')) {
      return 'パスワードが弱すぎます。6文字以上にしてください';
    }
    if (msg.contains('network-request-failed')) {
      return 'ネットワークに接続できません';
    }
    return 'エラーが発生しました。もう一度お試しください';
  }

  @override
  Widget build(BuildContext context) {
    return DqScene(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _authenticated ? _buildLinkCodePhase() : _buildAuthPhase(),
          ),
        ],
      ),
    );
  }

  // ── DQ-style header (back arrow + gold bilingual title) ───────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'もどる / Back',
            icon: const Icon(Icons.arrow_back, color: dqInk),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: dqBilingual(
              '保護者ログイン',
              'Parent Login',
              jpSize: 20,
              stacked: true,
            ),
          ),
        ],
      ),
    );
  }

  // ── Auth Phase: Login / Sign Up tabs ──────────────────────────────────────

  Widget _buildAuthPhase() {
    return Column(
      children: [
        const SizedBox(height: 8),
        // Tab bar — dark navy fill, gold selected indicator
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: dqBox,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: dqBorder, width: 1.5),
          ),
          child: TabBar(
            controller: _tabCtrl,
            indicator: BoxDecoration(
              gradient: const LinearGradient(colors: [dqGold, dqGoldDeep]),
              borderRadius: BorderRadius.circular(12),
            ),
            labelColor: const Color(0xFF2A1C00),
            unselectedLabelColor: dqInk,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            dividerHeight: 0,
            tabs: const [
              Tab(text: 'ログイン'),
              Tab(text: '新規登録'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Tab content — centred so the form does not leave the lower half empty
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildLoginForm(),
              _buildSignUpForm(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'お子様の学習状況を確認するために\n保護者アカウントでログインしてください',
              style: dqText(size: 14, color: dqInk),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _emailCtrl,
              label: 'メールアドレス',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _passwordCtrl,
              label: 'パスワード',
              obscure: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: dqText(size: 13, color: const Color(0xFFE89090)),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            DqButton(
              label: 'ログイン',
              onTap: _loading ? null : _handleLogin,
            ),
            if (_loading) ...[
              const SizedBox(height: 16),
              const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: dqGold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '保護者アカウントを作成して\nお子様の進捗を見守りましょう',
              style: dqText(size: 14, color: dqInk),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _emailCtrl,
              label: 'メールアドレス',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _passwordCtrl,
              label: 'パスワード（6文字以上）',
              obscure: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _confirmCtrl,
              label: 'パスワード（確認）',
              obscure: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: dqText(size: 13, color: const Color(0xFFE89090)),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            DqButton(
              label: 'アカウント作成',
              onTap: _loading ? null : _handleSignUp,
            ),
            if (_loading) ...[
              const SizedBox(height: 16),
              const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: dqGold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Link Code Phase ────────────────────────────────────────────────────────

  Widget _buildLinkCodePhase() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DqPanel(
              title: 'リンク / Link',
              child: Column(
                children: [
                  const Icon(Icons.link, color: dqGold, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'お子様のアカウントをリンク',
                    style: dqText(size: 20, w: FontWeight.bold, color: dqGold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'お子様のアプリで表示される6桁のリンクコードを\n入力してください。\n\n'
                    'コードの取得方法：\n'
                    'お子様のアプリ → Scholar\'s Tower → 設定タブ → リンクコード生成',
                    style: dqText(size: 13, color: dqInk),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _linkCodeCtrl,
              label: 'リンクコード（6桁）',
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: dqText(
                size: 28,
                w: FontWeight.bold,
                color: dqInk,
                spacing: 8,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: dqText(size: 13, color: const Color(0xFFE89090)),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            DqButton(
              label: 'リンクする',
              onTap: _loading ? null : _handleLinkCode,
            ),
            if (_loading) ...[
              const SizedBox(height: 16),
              const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: dqGold,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                await _parentAuth.signOut();
                if (mounted) {
                  setState(() {
                    _authenticated = false;
                    _error = null;
                    _loading = false;
                  });
                }
              },
              child: Text(
                'ログアウト',
                style: dqText(size: 14, color: dqGoldDeep),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    TextInputType? keyboardType,
    TextAlign textAlign = TextAlign.start,
    TextStyle? style,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textAlign: textAlign,
      style: style ?? dqText(size: 16, color: dqInk),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: dqText(size: 14, color: dqGoldDeep),
        filled: true,
        fillColor: dqBox,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: dqBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: dqBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: dqGold, width: 2),
        ),
      ),
    );
  }
}
