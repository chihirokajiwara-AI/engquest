import 'package:flutter/material.dart';
import 'package:engquest/core/firebase/parent_auth_service.dart';
import 'parent_dashboard_screen.dart';

/// Parent login / signup screen.
///
/// Two tabs: ログイン (login) and 新規登録 (sign up).
/// After auth, prompts for a link code to connect to a child's account.
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
        builder: (_) => const ParentDashboardScreen(),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF263238)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '保護者ログイン',
          style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _authenticated ? _buildLinkCodePhase() : _buildAuthPhase(),
      ),
    );
  }

  // ── Auth Phase: Login / Sign Up tabs ──────────────────────────────────

  Widget _buildAuthPhase() {
    return Column(
      children: [
        const SizedBox(height: 8),
        // Tab bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFE8EEF3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: TabBar(
            controller: _tabCtrl,
            indicator: BoxDecoration(
              color: const Color(0xFFFFD700),
              borderRadius: BorderRadius.circular(12),
            ),
            labelColor: Colors.black,
            unselectedLabelColor: const Color(0xFF607D8B),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            dividerHeight: 0,
            tabs: const [
              Tab(text: 'ログイン'),
              Tab(text: '新規登録'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Tab content
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'お子様の学習状況を確認するために\n保護者アカウントでログインしてください',
            style: TextStyle(color: Color(0xFF607D8B), fontSize: 14, height: 1.5),
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
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          _buildPrimaryButton(
            label: 'ログイン',
            onPressed: _handleLogin,
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '保護者アカウントを作成して\nお子様の進捗を見守りましょう',
            style: TextStyle(color: Color(0xFF607D8B), fontSize: 14, height: 1.5),
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
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          _buildPrimaryButton(
            label: 'アカウント作成',
            onPressed: _handleSignUp,
          ),
        ],
      ),
    );
  }

  // ── Link Code Phase ───────────────────────────────────────────────────

  Widget _buildLinkCodePhase() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD700).withAlpha(100)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4FC3F7).withAlpha(20),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Column(
              children: [
                Icon(Icons.link, color: Color(0xFFFFD700), size: 48),
                SizedBox(height: 16),
                Text(
                  'お子様のアカウントをリンク',
                  style: TextStyle(
                    color: Color(0xFF263238),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'お子様のアプリで表示される6桁のリンクコードを\n入力してください。\n\n'
                  'コードの取得方法：\n'
                  'お子様のアプリ → Scholar\'s Tower → 設定タブ → リンクコード生成',
                  style: TextStyle(
                    color: Color(0xFF607D8B),
                    fontSize: 13,
                    height: 1.5,
                  ),
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          _buildPrimaryButton(
            label: 'リンクする',
            onPressed: _handleLinkCode,
          ),
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
            child: const Text(
              'ログアウト',
              style: TextStyle(color: Color(0xFF90A4AE), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────

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
      style: style ?? const TextStyle(color: Color(0xFF263238), fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF90A4AE)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFD700)),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: _loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFFD700),
        foregroundColor: Colors.black,
        disabledBackgroundColor: Colors.white12,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.black54,
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }
}
