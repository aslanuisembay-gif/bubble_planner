import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../convex_env.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController(text: 'demo');
  final _pass = TextEditingController(text: 'demo');
  String? _localError;
  bool _busy = false;
  bool _signUp = false;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  String? _combinedError(AppState state, bool useConvex) {
    if (_localError != null) return _localError;
    if (!useConvex) return null;
    final c = state.convexError;
    if (c == null || c.isEmpty) return null;
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final convexBusy = state.convexLoading;
    final useConvex = ConvexEnv.isConfigured && ConvexEnv.backendReady;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0A14),
              Color(0xFF1A1028),
              Color(0xFF0D0612),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9D00FF).withValues(alpha: 0.25),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Color(0xFFB026FF), Color(0xFF5C0D9E)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF9D00FF).withValues(alpha: 0.55),
                              blurRadius: 28,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'BP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        useConvex ? 'Bubble Planner' : 'Welcome Back',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        useConvex
                            ? (_signUp ? 'Создать аккаунт' : 'Вход')
                            : 'Unlock your bubbles',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      _Field(
                        icon: Icons.person_outline_rounded,
                        controller: _user,
                        hint: 'Логин',
                        obscure: false,
                        keyboard: TextInputType.text,
                      ),
                      const SizedBox(height: 14),
                      _Field(
                        icon: Icons.lock_outline_rounded,
                        controller: _pass,
                        hint: 'Пароль',
                        obscure: true,
                        keyboard: TextInputType.visiblePassword,
                      ),
                      if (useConvex) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => setState(() {
                            _signUp = !_signUp;
                            _localError = null;
                          }),
                          child: Text(
                            _signUp
                                ? 'Уже есть аккаунт? Войти'
                                : 'Нет аккаунта? Зарегистрироваться',
                            style: const TextStyle(color: Color(0xFFD8B4FE)),
                          ),
                        ),
                      ],
                      if (_combinedError(state, useConvex) != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _combinedError(state, useConvex)!,
                          style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13),
                        ),
                      ],
                      if (convexBusy || _busy) ...[
                        const SizedBox(height: 16),
                        const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: (convexBusy || _busy)
                              ? null
                              : () async {
                                  setState(() {
                                    _localError = null;
                                    _busy = true;
                                  });
                                  if (useConvex) {
                                    final u = _user.text.trim();
                                    final p = _pass.text.trim();
                                    final demoLocal = u == 'demo' && p == 'demo';
                                    if (u.isEmpty) {
                                      setState(() {
                                        _localError = 'Введите логин';
                                        _busy = false;
                                      });
                                      return;
                                    }
                                    if (!demoLocal && p.length < 8) {
                                      setState(() {
                                        _localError =
                                            'Пароль: минимум 8 символов (сейчас ${p.length}).';
                                        _busy = false;
                                      });
                                      return;
                                    }
                                  }
                                  final ok = await context.read<AppState>().tryLogin(
                                        _user.text,
                                        _pass.text,
                                        signUp: _signUp,
                                      );
                                  if (!context.mounted) return;
                                  setState(() {
                                    _busy = false;
                                    if (!ok && useConvex) {
                                      _localError = null;
                                    }
                                    if (!ok && !useConvex) {
                                      _localError = 'Используйте demo / demo (офлайн)';
                                    }
                                  });
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF9D00FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: Icon(
                            _signUp ? Icons.person_add_rounded : Icons.login_rounded,
                            size: 22,
                          ),
                          label: Text(
                            useConvex
                                ? (_signUp ? 'Создать аккаунт' : 'Войти')
                                : 'Sign In',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        useConvex
                            ? 'Локальный демо: demo / demo. Облако: пароль ≥ 8 символов; логин без @ → …@bubble.local.'
                            : 'Use demo / demo to sign in (offline)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white54,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.icon,
    required this.controller,
    required this.hint,
    required this.obscure,
    this.keyboard,
  });

  final IconData icon;
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboard;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
          prefixIcon: Icon(icon, color: Colors.white54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        ),
      ),
    );
  }
}
