import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/live_location_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'member_signup_screen.dart';
import 'member/member_shell.dart';

class MemberSignInScreen extends StatefulWidget {
  const MemberSignInScreen({super.key});

  @override
  State<MemberSignInScreen> createState() => _MemberSignInScreenState();
}

class _MemberSignInScreenState extends State<MemberSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _authError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _authError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AuthService.signIn(_email.text.trim(), _password.text);
      final member = await AuthService.loadCurrentMember();
      if (!mounted) return;

      if (member == null) {
        setState(() {
          _busy = false;
          _authError = 'Account not found. Please register first.';
        });
        return;
      }
      switch (member.state) {
        case AccountState.pending:
          await AuthService.signOut();
          if (!mounted) return;
          setState(() {
            _busy = false;
            _authError =
                'Your account is awaiting admin approval. You will be notified once approved.';
          });
          return;
        case AccountState.deactivated:
        case AccountState.deleted:
          await AuthService.signOut();
          if (!mounted) return;
          setState(() {
            _busy = false;
            _authError =
                'This account is not active. Please contact the choir administration.';
          });
          return;
        case AccountState.active:
          AppState.instance.signIn(member);
          LiveLocationService.instance.resumeIfEnabled();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MemberShell()),
          );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _authError = _friendlyError(e);
      });
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('Invalid login credentials')) {
      return 'Wrong email or password. Please try again.';
    }
    if (s.contains('Email not confirmed')) {
      return 'Email not confirmed yet. Check your inbox.';
    }
    return 'Could not sign in. Please try again.';
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _authError = 'Enter your email above first.');
      return;
    }
    try {
      await AuthService.resetPassword(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to $email.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _authError = 'Could not send reset link. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: AbsorbPointer(
        absorbing: _busy,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              56,
              AppSpacing.page,
              AppSpacing.xxxl,
            ),
            children: [
              // ── Logo mark ────────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        color: AppColors.cream,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Fayha National Choir',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Member Portal',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.gray,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ── Email ─────────────────────────────────────────────────────
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                onChanged: (_) {
                  if (_authError != null) setState(() => _authError = null);
                },
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // ── Password ──────────────────────────────────────────────────
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onChanged: (_) {
                  if (_authError != null) setState(() => _authError = null);
                },
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),

              // ── Inline auth error ─────────────────────────────────────────
              if (_authError != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB23A48).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: const Color(0xFFB23A48).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 16,
                        color: Color(0xFFB23A48),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _authError!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFB23A48),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Forgot password ───────────────────────────────────────────
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _forgotPassword,
                  child: const Text('Forgot password?'),
                ),
              ),

              // ── Submit ────────────────────────────────────────────────────
              FilledButton(
                onPressed: _busy ? null : _signIn,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.cream,
                          ),
                        )
                      : const Text('Sign In'),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // ── Register link ─────────────────────────────────────────────
              Center(
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MemberSignUpScreen(),
                    ),
                  ),
                  child: const Text('New member? Register here'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
