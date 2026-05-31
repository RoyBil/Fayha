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

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AuthService.signIn(_email.text.trim(), _password.text);
      final member = await AuthService.loadCurrentMember();
      if (!mounted) return;

      if (member == null) {
        setState(() => _busy = false);
        _showMessage('Account not found. Please register first.');
        return;
      }
      switch (member.state) {
        case AccountState.pending:
          await AuthService.signOut();
          if (!mounted) return;
          setState(() => _busy = false);
          _showMessage(
              'Your account is still awaiting admin approval. You will be able to sign in once approved.');
          return;
        case AccountState.deactivated:
        case AccountState.deleted:
          await AuthService.signOut();
          if (!mounted) return;
          setState(() => _busy = false);
          _showMessage(
              'This account is not active. Please contact the choir administration.');
          return;
        case AccountState.active:
          AppState.instance.signIn(member);
          // Resume live-location pushes if the user already opted in
          // on a previous session.
          LiveLocationService.instance.resumeIfEnabled();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MemberShell()),
          );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage(_friendlyError(e));
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('Invalid login credentials')) {
      return 'Wrong email or password.';
    }
    if (s.contains('Email not confirmed')) {
      return 'Email not confirmed yet. Check your inbox, or ask the admin to disable email confirmation.';
    }
    return 'Could not sign in: $s';
  }

  void _showMessage(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      _showMessage('Enter your email above first, then tap "Forgot password".');
      return;
    }
    try {
      await AuthService.resetPassword(email);
      if (!mounted) return;
      _showMessage('Password reset link sent to $email.');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Could not send reset link: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Member Sign In')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.music_note, color: AppColors.accentLight, size: 28),
                    const SizedBox(height: 10),
                    Text('Choir Members Portal',
                        style: theme.textTheme.titleLarge?.copyWith(color: AppColors.cream)),
                    const SizedBox(height: 6),
                    Text(
                      'Access rehearsals, recordings, attendance, messaging and your member profile.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.cream.withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _forgotPassword,
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _signIn,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _busy
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.cream),
                        )
                      : const Text('Sign In'),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MemberSignUpScreen()),
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
