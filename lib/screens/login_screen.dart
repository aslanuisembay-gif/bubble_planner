import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../app_theme.dart';
import '../convex_auth_session.dart';
import '../convex_env.dart';
import '../translations.dart' show tr, trFill;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _passConfirm = TextEditingController();
  String? _localError;
  bool _busy = false;
  bool _signUp = false;
  static final RegExp _emailRx = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void initState() {
    super.initState();
    final cloud = ConvexEnv.isConfigured && ConvexEnv.backendReady;
    if (!cloud) {
      _user.text = 'demo';
      _pass.text = 'demo';
    }
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _passConfirm.dispose();
    super.dispose();
  }

  String? _combinedError(AppState state, bool useConvex) {
    if (_localError != null) return _localError;
    if (!useConvex) return null;
    final c = state.convexError;
    if (c == null || c.isEmpty) return null;
    return c;
  }

  bool _identifierLooksValid(String input) {
    final v = input.trim();
    if (v.isEmpty) return false;
    if (v.contains('@')) return _emailRx.hasMatch(v);
    if (v.contains(' ')) return false;
    return v.length >= 3;
  }

  Future<void> _openForgotPasswordSheet(AppState state) async {
    final lang = state.languageCode;
    final bp = context.bp;
    final idCtrl = TextEditingController(text: _user.text.trim());
    final codeCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? localError;
    bool sent = false;
    bool busy = false;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 14,
                right: 14,
                top: 14,
                bottom: MediaQuery.of(ctx).viewInsets.bottom +
                    MediaQuery.paddingOf(ctx).bottom +
                    14,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                decoration: BoxDecoration(
                  color: bp.modalSurface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: bp.modalBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr('loginResetTitle', lang: lang),
                            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                  color: bp.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(Icons.close_rounded, color: bp.textSecondary),
                        ),
                      ],
                    ),
                    Text(
                      tr('loginResetHint', lang: lang),
                      style: TextStyle(color: bp.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    _AuthTextField(
                      icon: Icons.alternate_email_rounded,
                      controller: idCtrl,
                      hint: tr('loginFieldIdentifier', lang: lang),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                    ),
                    if (sent) ...[
                      const SizedBox(height: 10),
                      _AuthTextField(
                        icon: Icons.confirmation_number_outlined,
                        controller: codeCtrl,
                        hint: tr('loginResetCodeHint', lang: lang),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 10),
                      _AuthPasswordField(
                        controller: newPassCtrl,
                        hint: tr('loginResetNewPassword', lang: lang),
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                      ),
                      const SizedBox(height: 10),
                      _AuthPasswordField(
                        controller: confirmCtrl,
                        hint: tr('loginFieldConfirmPassword', lang: lang),
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                      ),
                    ],
                    if (localError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        localError!,
                        style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                        final identifier = idCtrl.text.trim();
                        if (!_identifierLooksValid(identifier)) {
                          setModalState(
                            () => localError = tr('loginErrorInvalidIdentifier', lang: lang),
                          );
                          return;
                        }
                        if (!sent) {
                          setModalState(() {
                            localError = null;
                            busy = true;
                          });
                          try {
                            await ConvexAuthSession.requestPasswordReset(
                              emailOrUsername: identifier,
                            );
                            if (!ctx.mounted) return;
                            setModalState(() {
                              busy = false;
                              sent = true;
                            });
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(tr('loginResetCodeSent', lang: lang))),
                            );
                          } catch (e) {
                            setModalState(() {
                              busy = false;
                              localError =
                                  e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
                            });
                          }
                          return;
                        }

                        final code = codeCtrl.text.trim();
                        final newPass = newPassCtrl.text.trim();
                        final confirm = confirmCtrl.text.trim();
                        if (code.isEmpty) {
                          setModalState(
                            () => localError = tr('loginResetCodeRequired', lang: lang),
                          );
                          return;
                        }
                        if (newPass.length < 8) {
                          setModalState(
                            () => localError = trFill(
                              'loginErrorPasswordLength',
                              {'n': '${newPass.length}'},
                              lang: lang,
                            ),
                          );
                          return;
                        }
                        if (newPass != confirm) {
                          setModalState(
                            () => localError = tr('loginErrorPasswordMismatch', lang: lang),
                          );
                          return;
                        }

                        setModalState(() {
                          localError = null;
                          busy = true;
                        });
                        try {
                          await ConvexAuthSession.resetPasswordWithCode(
                            emailOrUsername: identifier,
                            code: code,
                            newPassword: newPass,
                          );
                          if (!ctx.mounted) return;
                          _user.text = identifier;
                          _pass.text = newPass;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(tr('loginResetSuccess', lang: lang))),
                          );
                          Navigator.pop(ctx);
                        } catch (e) {
                          setModalState(() {
                            busy = false;
                            localError =
                                e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
                          });
                        }
                      },
                      icon: Icon(sent ? Icons.lock_reset_rounded : Icons.mail_outline_rounded),
                      label: Text(
                        sent ? tr('loginResetApply', lang: lang) : tr('loginResetSend', lang: lang),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    idCtrl.dispose();
    codeCtrl.dispose();
    newPassCtrl.dispose();
    confirmCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.languageCode;
    final convexBusy = state.convexLoading;
    final useConvex = ConvexEnv.isConfigured && ConvexEnv.backendReady;

    final bp = context.bp;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: bp.backgroundGradient,
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
                    color: bp.loginPanelFill,
                    border: Border.all(color: bp.loginPanelBorder),
                    boxShadow: [
                      BoxShadow(
                        color: bp.loginGlow,
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: AutofillGroup(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: bp.loginLogoGradient,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: bp.loginLogoShadow,
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
                          useConvex
                              ? tr('loginTitleCloud', lang: lang)
                              : tr('loginTitleOffline', lang: lang),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: bp.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          useConvex
                              ? (_signUp
                                  ? tr('loginSubtitleSignUp', lang: lang)
                                  : tr('loginSubtitleSignIn', lang: lang))
                              : tr('loginSubtitleOffline', lang: lang),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: bp.textSecondary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        _AuthTextField(
                          icon: Icons.person_outline_rounded,
                          controller: _user,
                          hint: tr('loginFieldIdentifier', lang: lang),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username, AutofillHints.email],
                        ),
                        const SizedBox(height: 14),
                        _AuthPasswordField(
                          controller: _pass,
                          hint: tr('loginFieldPassword', lang: lang),
                          textInputAction:
                              useConvex && _signUp ? TextInputAction.next : TextInputAction.done,
                          autofillHints: _signUp
                              ? const [AutofillHints.newPassword]
                              : const [AutofillHints.password],
                        ),
                        if (useConvex && _signUp) ...[
                          const SizedBox(height: 14),
                          _AuthPasswordField(
                            controller: _passConfirm,
                            hint: tr('loginFieldConfirmPassword', lang: lang),
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                          ),
                        ],
                        if (useConvex) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.center,
                            child: TextButton(
                              onPressed: () => setState(() {
                                _signUp = !_signUp;
                                _localError = null;
                                _passConfirm.clear();
                              }),
                              child: Text(
                                _signUp
                                    ? tr('loginToggleToSignIn', lang: lang)
                                    : tr('loginToggleToSignUp', lang: lang),
                                style: TextStyle(color: bp.primary.withValues(alpha: 0.95)),
                              ),
                            ),
                          ),
                          if (!_signUp)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: (convexBusy || _busy)
                                    ? null
                                    : () => _openForgotPasswordSheet(state),
                                child: Text(
                                  tr('loginForgotPassword', lang: lang),
                                  style: TextStyle(color: bp.primary.withValues(alpha: 0.95)),
                                ),
                              ),
                            ),
                        ],
                        if (_combinedError(state, useConvex) != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _combinedError(state, useConvex)!,
                            style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13),
                            textAlign: TextAlign.center,
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
                                          _localError =
                                              tr('loginErrorEmptyIdentifier', lang: lang);
                                          _busy = false;
                                        });
                                        return;
                                      }
                                      if (!demoLocal && !_identifierLooksValid(u)) {
                                        setState(() {
                                          _localError =
                                              tr('loginErrorInvalidIdentifier', lang: lang);
                                          _busy = false;
                                        });
                                        return;
                                      }
                                      if (!demoLocal && p.length < 8) {
                                        setState(() {
                                          _localError = trFill(
                                            'loginErrorPasswordLength',
                                            {'n': '${p.length}'},
                                            lang: lang,
                                          );
                                          _busy = false;
                                        });
                                        return;
                                      }
                                      if (_signUp && !demoLocal) {
                                        if (_passConfirm.text.trim() != p) {
                                          setState(() {
                                            _localError =
                                                tr('loginErrorPasswordMismatch', lang: lang);
                                            _busy = false;
                                          });
                                          return;
                                        }
                                      }
                                    }
                                    final ok = await context.read<AppState>().tryLogin(
                                          _user.text,
                                          _pass.text,
                                          signUp: _signUp,
                                        );
                                    if (!context.mounted) return;
                                    final app = context.read<AppState>();
                                    setState(() {
                                      _busy = false;
                                      if (!ok && useConvex) {
                                        _localError = app.convexError ??
                                            'Sign in failed. Please try again.';
                                      }
                                      if (!ok && !useConvex) {
                                        _localError =
                                            tr('loginErrorOfflineDemo', lang: lang);
                                      }
                                    });
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                                  ? (_signUp
                                      ? tr('loginActionSignUp', lang: lang)
                                      : tr('loginActionSignIn', lang: lang))
                                  : tr('loginActionOffline', lang: lang),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          useConvex
                              ? tr('loginFootnoteCloud', lang: lang)
                              : tr('loginFootnoteOffline', lang: lang),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: bp.textSecondary,
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
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.icon,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
  });

  final IconData icon;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final bp = context.bp;
    final fieldBg = bp.brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.35)
        : bp.surface.withValues(alpha: 0.95);
    return Container(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bp.glassBorder),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints?.toList(),
        style: TextStyle(color: bp.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: bp.textSecondary.withValues(alpha: 0.65)),
          prefixIcon: Icon(icon, color: bp.textSecondary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        ),
      ),
    );
  }
}

class _AuthPasswordField extends StatefulWidget {
  const _AuthPasswordField({
    required this.controller,
    required this.hint,
    this.textInputAction,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  @override
  State<_AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<_AuthPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppState>().languageCode;
    final bp = context.bp;
    final fieldBg = bp.brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.35)
        : bp.surface.withValues(alpha: 0.95);
    return Container(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bp.glassBorder),
      ),
      child: TextField(
        controller: widget.controller,
        obscureText: _obscure,
        keyboardType: TextInputType.visiblePassword,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints?.toList(),
        style: TextStyle(color: bp.textPrimary),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(color: bp.textSecondary.withValues(alpha: 0.65)),
          prefixIcon: Icon(Icons.lock_outline_rounded, color: bp.textSecondary),
          suffixIcon: IconButton(
            tooltip: _obscure
                ? tr('loginShowPassword', lang: lang)
                : tr('loginHidePassword', lang: lang),
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(
              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: bp.textSecondary,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
        ),
      ),
    );
  }
}
