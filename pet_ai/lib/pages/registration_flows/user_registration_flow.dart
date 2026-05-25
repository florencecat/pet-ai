import 'package:flutter/material.dart';
import 'package:pet_satellite/models/user_profile.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/authentification_service.dart';
import 'package:pet_satellite/services/user_profile_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:provider/provider.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

bool _isValidEmail(String email) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim());

/// Password must be ≥ 8 chars and contain at least one letter and one digit.
bool _isValidPassword(String pwd) {
  if (pwd.length < 8) return false;
  final hasLetter = RegExp(r'[A-Za-zА-Яа-яЁё]').hasMatch(pwd);
  final hasDigit = RegExp(r'\d').hasMatch(pwd);
  return hasLetter && hasDigit;
}

Widget _card({required Widget child, EdgeInsets? padding, Color? color}) =>
    Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? ThemeColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );

// ─── Flow ─────────────────────────────────────────────────────────────────────

class UserRegistrationFlow extends StatefulWidget {
  const UserRegistrationFlow({super.key});

  @override
  State<UserRegistrationFlow> createState() => _UserRegistrationFlowState();
}

class _UserRegistrationFlowState extends State<UserRegistrationFlow> {
  // ── Step state ───────────────────────────────────────────────────────────
  int _step = 0;
  static const _totalSteps = 3;

  // Step 0 — Name
  final _nameCtrl = TextEditingController();

  // Step 1 — Credentials
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  // Step 2 — OTP
  String? _otpId;
  final _codeCtrl = TextEditingController();
  bool _codeError = false;

  // General
  bool _loading = false;
  String? _serverError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _back() {
    if (_step == 0) return;
    setState(() {
      _step--;
      _serverError = null;
      if (_step == 1) {
        // Returning to credentials from OTP — clear code state.
        _codeCtrl.clear();
        _codeError = false;
        _otpId = null;
      }
    });
  }

  void _exit() => Navigator.of(context).pop();

  // ── Step 0: Name ──────────────────────────────────────────────────────────

  void _submitName() {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите ваше имя'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _step = 1);
  }

  // ── Step 1: Credentials ───────────────────────────────────────────────────

  /// Returns true if all fields pass local validation.
  bool _validateCredentials() {
    String? emailErr, pwdErr, confirmErr;

    if (!_isValidEmail(_emailCtrl.text)) {
      emailErr = 'Некорректный адрес эл. почты';
    }

    final pwd = _passwordCtrl.text;
    if (pwd.isEmpty) {
      pwdErr = 'Введите пароль';
    } else if (pwd.length < 8) {
      pwdErr = 'Минимум 8 символов';
    } else if (!_isValidPassword(pwd)) {
      pwdErr = 'Используйте буквы и цифры';
    }

    if (_confirmCtrl.text != pwd) {
      confirmErr = 'Пароли не совпадают';
    }

    setState(() {
      _emailError = emailErr;
      _passwordError = pwdErr;
      _confirmError = confirmErr;
      _serverError = null;
    });

    return emailErr == null && pwdErr == null && confirmErr == null;
  }

  Future<void> _submitCredentials() async {
    if (!_validateCredentials()) return;

    setState(() { _loading = true; _serverError = null; });

    final result = await UserService().register(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      // Passwords are passed directly to the HTTPS endpoint and not stored.
      password: _passwordCtrl.text,
      passwordConfirm: _confirmCtrl.text,
    );

    if (!mounted) return;

    setState(() => _loading = false);

    if (result.success) {
      setState(() {
        _otpId = result.otpId;
        _step = 2;
        _codeCtrl.clear();
        _codeError = false;
        _serverError = null;
      });
    } else {
      // Map server errors to field-level or banner errors.
      if (result.code == 409) {
        setState(() => _emailError = 'Этот адрес уже зарегистрирован');
      } else {
        setState(
          () => _serverError =
              result.errorMessage ?? 'Ошибка регистрации — попробуйте позже',
        );
      }
    }
  }

  // ── Step 2: OTP ───────────────────────────────────────────────────────────

  Future<void> _submitCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6 || _otpId == null) return;

    setState(() { _loading = true; _serverError = null; _codeError = false; });

    final result = await UserService().verifyOTP(otpId: _otpId!, code: code);

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      await _finish();
    } else {
      setState(() {
        _codeError = true;
        _serverError = result.errorMessage ?? 'Ошибка подтверждения';
      });
    }
  }

  Future<void> _resendCode() async {
    setState(() { _loading = true; _serverError = null; });

    final result = await UserService().resendOTP(_emailCtrl.text.trim());

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      setState(() {
        _otpId = result.otpId;
        _codeCtrl.clear();
        _codeError = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Код отправлен повторно'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(
        () => _serverError =
            result.errorMessage ?? 'Не удалось отправить код',
      );
    }
  }

  // ── Finish ────────────────────────────────────────────────────────────────

  Future<void> _finish() async {
    // Read the server-assigned user ID from the PocketBase auth store.
    final record = AuthService.pb.authStore.record;
    final profile = UserProfile(
      id: record?.id ?? '',
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      emailVerified: true,
    );

    await UserService().save(profile);
    if (mounted) Navigator.of(context).pop(profile);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _RegHeader(
              step: _step,
              totalSteps: _totalSteps,
              onBack: _step > 0 ? _back : null,
              onClose: _exit,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(parent: anim, curve: Curves.easeOut),
                    ),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: _buildStep(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _Step0(
          nameCtrl: _nameCtrl,
          onNext: _submitName,
          onExit: _exit,
        );
      case 1:
        return _Step1(
          emailCtrl: _emailCtrl,
          passwordCtrl: _passwordCtrl,
          confirmCtrl: _confirmCtrl,
          emailError: _emailError,
          passwordError: _passwordError,
          confirmError: _confirmError,
          serverError: _serverError,
          loading: _loading,
          onNext: _submitCredentials,
          onBack: _back,
        );
      case 2:
        return _Step2(
          email: _emailCtrl.text.trim(),
          codeCtrl: _codeCtrl,
          codeError: _codeError,
          serverError: _serverError,
          loading: _loading,
          onVerify: _submitCode,
          onResend: _resendCode,
          onBack: _back,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _RegHeader extends StatelessWidget {
  final int step;
  final int totalSteps;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  const _RegHeader({
    required this.step,
    required this.totalSteps,
    this.onBack,
    this.onClose,
  });

  String get _title => switch (step) {
        0 => 'Ваш профиль',
        1 => 'Данные для входа',
        _ => 'Подтверждение',
      };

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AppearanceController>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              if (onBack != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  onPressed: onBack,
                  color: ac.secondaryColor,
                )
              else
                const SizedBox(width: 48),
              Expanded(
                child: Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (onClose != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: onClose,
                  color: ac.secondaryColor.withAlpha(160),
                )
              else
                const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(totalSteps, (i) {
                final active = i <= step;
                final current = i == step;
                return Expanded(
                  flex: current ? 3 : 1,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    margin:
                        EdgeInsets.only(right: i < totalSteps - 1 ? 6 : 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: active
                          ? ac.secondaryColor
                          : ac.primaryColor.withAlpha(92),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─── Step 0 — Имя ────────────────────────────────────────────────────────────

class _Step0 extends StatelessWidget {
  final TextEditingController nameCtrl;
  final VoidCallback onNext;
  final VoidCallback onExit;

  const _Step0({
    required this.nameCtrl,
    required this.onNext,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AppearanceController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Как вас\nзовут?',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Профиль не обязателен — он поможет с синхронизацией и резервными копиями.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ac.secondaryColor.withAlpha(160),
                      ),
                ),
                const SizedBox(height: 24),
                _card(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: TextField(
                    controller: nameCtrl,
                    style: Theme.of(context).textTheme.bodyLarge,
                    cursorColor: ac.secondaryColor,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => onNext(),
                    decoration: InputDecoration(
                      hintText: 'Имя',
                      hintStyle: Theme.of(context).textTheme.bodyLarge!
                          .copyWith(color: Colors.grey.shade400),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _BottomBar(
          label: 'Далее',
          onNext: onNext,
          onNextAvailable: true,
          onExit: onExit,
        ),
      ],
    );
  }
}

// ─── Step 1 — Почта, пароль, подтверждение ────────────────────────────────────

class _Step1 extends StatefulWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController confirmCtrl;
  final String? emailError;
  final String? passwordError;
  final String? confirmError;
  final String? serverError;
  final bool loading;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step1({
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.confirmCtrl,
    required this.emailError,
    required this.passwordError,
    required this.confirmError,
    required this.serverError,
    required this.loading,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<_Step1> createState() => _Step1State();
}

class _Step1State extends State<_Step1> {
  bool _passwordVisible = false;
  bool _confirmVisible = false;

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AppearanceController>();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Данные\nдля входа',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Они понадобятся, чтобы войти с другого устройства.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: ac.secondaryColor.withAlpha(160),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Email ────────────────────────────────────────────────────
                _card(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: TextField(
                    controller: widget.emailCtrl,
                    style: theme.textTheme.bodyLarge,
                    cursorColor: ac.secondaryColor,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      hintText: 'Эл. почта',
                      hintStyle: theme.textTheme.bodyLarge!
                          .copyWith(color: Colors.grey.shade400),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (widget.emailError != null)
                  _FieldError(widget.emailError!),

                const SizedBox(height: 12),

                // ── Пароль ───────────────────────────────────────────────────
                _card(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: TextField(
                    controller: widget.passwordCtrl,
                    style: theme.textTheme.bodyLarge,
                    cursorColor: ac.secondaryColor,
                    obscureText: !_passwordVisible,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      hintText: 'Пароль',
                      hintStyle: theme.textTheme.bodyLarge!
                          .copyWith(color: Colors.grey.shade400),
                      border: InputBorder.none,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: Colors.grey.shade400,
                        ),
                        onPressed: () => setState(
                          () => _passwordVisible = !_passwordVisible,
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.passwordError != null)
                  _FieldError(widget.passwordError!),

                const SizedBox(height: 12),

                // ── Подтверждение пароля ─────────────────────────────────────
                _card(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: TextField(
                    controller: widget.confirmCtrl,
                    style: theme.textTheme.bodyLarge,
                    cursorColor: ac.secondaryColor,
                    obscureText: !_confirmVisible,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    onSubmitted: (_) => widget.onNext(),
                    decoration: InputDecoration(
                      hintText: 'Повторите пароль',
                      hintStyle: theme.textTheme.bodyLarge!
                          .copyWith(color: Colors.grey.shade400),
                      border: InputBorder.none,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _confirmVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: Colors.grey.shade400,
                        ),
                        onPressed: () => setState(
                          () => _confirmVisible = !_confirmVisible,
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.confirmError != null)
                  _FieldError(widget.confirmError!),

                // ── Password hint ─────────────────────────────────────────────
                const SizedBox(height: 8),
                Text(
                  'Минимум 8 символов, буквы и цифры',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade400,
                  ),
                ),

                // ── Server-level error ────────────────────────────────────────
                if (widget.serverError != null) ...[
                  const SizedBox(height: 12),
                  _ServerError(widget.serverError!),
                ],
              ],
            ),
          ),
        ),

        _BottomBar(
          label: 'Далее',
          onNext: widget.onNext,
          onNextAvailable: !widget.loading,
          loading: widget.loading,
          onBack: widget.onBack,
        ),
      ],
    );
  }
}

// ─── Step 2 — OTP ─────────────────────────────────────────────────────────────

class _Step2 extends StatelessWidget {
  final String email;
  final TextEditingController codeCtrl;
  final bool codeError;
  final String? serverError;
  final bool loading;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onBack;

  const _Step2({
    required this.email,
    required this.codeCtrl,
    required this.codeError,
    required this.serverError,
    required this.loading,
    required this.onVerify,
    required this.onResend,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AppearanceController>();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Введите\nкод',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),

                // Email reminder chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: ac.primaryColor.withAlpha(18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ac.primaryColor.withAlpha(60)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 15,
                        color: ac.secondaryColor,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Код отправлен на $email',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: ac.secondaryColor.withAlpha(200),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Large centred 6-digit code input
                ListenableBuilder(
                  listenable: codeCtrl,
                  builder: (context, _) {
                    return TextField(
                      controller: codeCtrl,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        letterSpacing: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: '000000',
                        hintStyle: theme.textTheme.headlineMedium?.copyWith(
                          letterSpacing: 14,
                          color: Colors.grey.shade300,
                        ),
                        counterText: '',
                        errorText: codeError ? 'Неверный код' : null,
                        filled: true,
                        fillColor: ThemeColors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 18),
                      ),
                    );
                  },
                ),

                if (serverError != null) ...[
                  const SizedBox(height: 10),
                  _ServerError(serverError!),
                ],

                const SizedBox(height: 20),

                // Resend
                Center(
                  child: TextButton(
                    onPressed: loading ? null : onResend,
                    child: Text(
                      'Отправить код повторно',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ac.secondaryColor.withAlpha(160),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        ListenableBuilder(
          listenable: codeCtrl,
          builder: (context, _) => _BottomBar(
            label: 'Подтвердить',
            nextIcon: Icons.verified_rounded,
            onNext: onVerify,
            onNextAvailable: codeCtrl.text.length == 6 && !loading,
            loading: loading,
            onBack: onBack,
          ),
        ),
      ],
    );
  }
}

// ─── Field error ──────────────────────────────────────────────────────────────

class _FieldError extends StatelessWidget {
  final String text;
  const _FieldError(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 12, top: 5),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ThemeColors.dangerZone,
              ),
        ),
      );
}

// ─── Server error banner ──────────────────────────────────────────────────────

class _ServerError extends StatelessWidget {
  final String text;
  const _ServerError(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: ThemeColors.dangerZone.withAlpha(12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ThemeColors.dangerZone.withAlpha(60)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline,
                size: 16, color: ThemeColors.dangerZone),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: ThemeColors.dangerZone,
                    ),
              ),
            ),
          ],
        ),
      );
}

// ─── Bottom navigation bar ────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final VoidCallback onNext;
  final bool onNextAvailable;
  final bool loading;
  final VoidCallback? onBack;
  final VoidCallback? onExit;
  final String label;
  final IconData nextIcon;

  const _BottomBar({
    required this.onNext,
    required this.onNextAvailable,
    this.loading = false,
    this.onBack,
    this.onExit,
    required this.label,
    this.nextIcon = Icons.arrow_forward_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AppearanceController>();
    final color =
        onNextAvailable ? ac.secondaryColor : Colors.grey.shade300;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          if (onExit != null) ...[
            _SideButton(
              icon: Icons.close_rounded,
              onTap: onExit!,
              ac: ac,
            ),
            const SizedBox(width: 12),
          ],
          if (onBack != null) ...[
            _SideButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: onBack!,
              ac: ac,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: GestureDetector(
              onTap: onNextAvailable ? onNext : null,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: onNextAvailable
                      ? [
                          BoxShadow(
                            color: color.withAlpha(70),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: loading
                    ? const Center(
                        child: SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            label,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium!
                                .copyWith(color: ThemeColors.white),
                          ),
                          const SizedBox(width: 8),
                          Icon(nextIcon,
                              color: Colors.white, size: 20),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final AppearanceController ac;

  const _SideButton({
    required this.icon,
    required this.onTap,
    required this.ac,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 50,
          height: 54,
          decoration: BoxDecoration(
            color: ThemeColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: ac.primaryColor.withAlpha(92),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: ac.secondaryColor.withAlpha(192),
          ),
        ),
      );
}
