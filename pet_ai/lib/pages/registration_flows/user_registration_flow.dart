import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:pet_satellite/models/user_profile.dart';
import 'package:pet_satellite/services/api_service.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/ai_service.dart';
import 'package:pet_satellite/services/cloud_sync_service.dart';
import 'package:pet_satellite/services/pb_service.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/services/user_profile_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:provider/provider.dart';

// ─── Backward-compat aliases ──────────────────────────────────────────────────

/// Old entry point kept for existing call-sites.
typedef UserRegistrationFlow = UserAuthFlow;

/// Old entry point kept for existing call-sites.
typedef UserLoginPage = UserAuthFlow;

// ─── Helpers ──────────────────────────────────────────────────────────────────

bool _isValidEmail(String email) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim());

Widget _card({required Widget child, EdgeInsets? padding, Color? color}) =>
    Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? ThemeColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );

// ─── Unified auth flow ────────────────────────────────────────────────────────
//
// Step 0 — Email   (calls requestAccess; detects new vs existing)
// Step 1 — OTP     (verifies the code)
// Step 2 — Name    (new-user only; collected after verification)
//
// Returns Navigator.pop(UserProfile) on success; null on cancel.

class UserAuthFlow extends StatefulWidget {
  const UserAuthFlow({super.key});

  @override
  State<UserAuthFlow> createState() => _UserAuthFlowState();
}

class _UserAuthFlowState extends State<UserAuthFlow> {
  int _step = 0;

  // Step 0
  final _emailCtrl = TextEditingController();
  String? _emailError;

  // Step 1
  String? _otpId;
  final _codeCtrl = TextEditingController();
  bool _codeError = false;

  // Step 2 — only for new users
  final _nameCtrl = TextEditingController();

  bool _isNewUser = false;
  bool _loading = false;
  String? _serverError;

  // Согласие с политикой использования — обязательно для шага 0.
  bool _agreedToPolicy = false;

  /// Progress bar length: 2 steps for existing users, 3 for new.
  int get _totalSteps => _isNewUser ? 3 : 2;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _back() {
    if (_step == 0) return;
    setState(() {
      _step--;
      _serverError = null;
      if (_step == 0) {
        _otpId = null;
        _codeCtrl.clear();
        _codeError = false;
      }
    });
  }

  // ── Step 0: Email → requestAccess ─────────────────────────────────────────

  Future<void> _submitEmail() async {
    // Защита на случай отправки по клавиатуре, когда согласие не отмечено.
    if (!_agreedToPolicy) return;
    final email = _emailCtrl.text.trim();
    if (!_isValidEmail(email)) {
      setState(() => _emailError = 'Некорректный адрес эл. почты');
      return;
    }
    setState(() {
      _emailError = null;
      _serverError = null;
      _loading = true;
    });

    final result = await UserProfileService().requestAccess(email);

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      setState(() {
        _otpId = result.otpId;
        _isNewUser = result.isNewUser;
        _step = 1;
        _codeCtrl.clear();
        _codeError = false;
        _serverError = null;
      });
    } else {
      setState(
        () => _serverError = result.errorMessage ?? 'Ошибка — попробуйте позже',
      );
    }
  }

  // ── Step 1: OTP → verifyOTP ───────────────────────────────────────────────

  Future<void> _submitCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6 || _otpId == null) return;

    setState(() {
      _loading = true;
      _serverError = null;
      _codeError = false;
    });

    final result = await UserProfileService().verifyOTP(otpId: _otpId!, code: code);

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      if (_isNewUser) {
        setState(() {
          _step = 2;
          _serverError = null;
        });
      } else {
        await _finish();
      }
    } else {
      setState(() {
        _codeError = true;
        _serverError = result.errorMessage ?? 'Ошибка подтверждения';
      });
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _loading = true;
      _serverError = null;
    });

    final result = await UserProfileService().resendOTP(_emailCtrl.text.trim());

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
        () => _serverError = result.errorMessage ?? 'Не удалось отправить код',
      );
    }
  }

  // ── Step 2: Name (new users only) ─────────────────────────────────────────

  Future<void> _submitName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите ваше имя'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _loading = true;
      _serverError = null;
    });

    await UserProfileService().updateName(name);

    if (!mounted) return;
    setState(() => _loading = false);

    await _finish();
  }

  // ── Finish ────────────────────────────────────────────────────────────────

  Future<void> _finish() async {
    final record = GetIt.instance<PocketBaseService>().pb.authStore.record;
    final name = _isNewUser
        ? _nameCtrl.text.trim()
        : (record?.data['name'] as String? ?? '');
    // Город восстанавливаем из облака при входе существующего пользователя.
    final city = record?.data['city'] as String? ?? '';
    final profile = UserProfile(
      id: record?.id ?? '',
      name: name,
      email: _emailCtrl.text.trim(),
      city: city,
      emailVerified: true,
    );

    await UserProfileService().save(profile);
    if (!mounted) return;

    await _checkAndOfferSync();

    if (mounted) Navigator.of(context).pop(profile);
  }

  Future<void> _checkAndOfferSync() async {
    final sync = CloudSyncService.instance;
    final hasRemote = await sync.checkHasRemoteData();
    if (!hasRemote || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SyncOfferDialog(),
    );
    if (confirmed != true || !mounted) return;

    final profiles = await PetProfileService().loadAllProfiles();
    if (profiles.isEmpty || !mounted) return;

    try {
      await sync.pullAll();
      await AIChatController.restoreThreadsFromCloud();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось загрузить данные с сервера'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _AuthHeader(
              step: _step,
              totalSteps: _totalSteps,
              onBack: _step > 0 ? _back : null,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0.04, 0),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(parent: anim, curve: Curves.easeOut),
                        ),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(key: ValueKey(_step), child: _buildStep()),
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
        return _EmailStep(
          emailCtrl: _emailCtrl,
          emailError: _emailError,
          serverError: _serverError,
          loading: _loading,
          agreedToPolicy: _agreedToPolicy,
          onAgreedChanged: (v) => setState(() => _agreedToPolicy = v),
          onNext: _submitEmail,
          onExit: Navigator.of(context).pop,
        );
      case 1:
        return _OtpStep(
          email: _emailCtrl.text.trim(),
          codeCtrl: _codeCtrl,
          codeError: _codeError,
          serverError: _serverError,
          loading: _loading,
          onVerify: _submitCode,
          onResend: _resendCode,
          onBack: _back,
        );
      case 2:
        return _NameStep(
          nameCtrl: _nameCtrl,
          loading: _loading,
          onNext: _submitName,
          onBack: _back,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _AuthHeader extends StatelessWidget {
  final int step;
  final int totalSteps;
  final VoidCallback? onBack;

  const _AuthHeader({
    required this.step,
    required this.totalSteps,
    this.onBack,
  });

  String get _title => switch (step) {
    0 => 'Войти или создать аккаунт',
    1 => 'Подтверждение',
    _ => 'Ваш профиль',
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
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: Navigator.of(context).pop,
                  color: ac.secondaryColor.withAlpha(160),
                ),
              Expanded(
                child: Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: Row(
                children: List.generate(totalSteps, (i) {
                  final active = i <= step;
                  final current = i == step;
                  return Expanded(
                    flex: current ? 3 : 1,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 4,
                      margin: EdgeInsets.only(
                        right: i < totalSteps - 1 ? 6 : 0,
                      ),
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
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─── Step 0 — Email ───────────────────────────────────────────────────────────

class _EmailStep extends StatelessWidget {
  final TextEditingController emailCtrl;
  final String? emailError;
  final String? serverError;
  final bool loading;
  final bool agreedToPolicy;
  final ValueChanged<bool> onAgreedChanged;
  final VoidCallback onNext;
  final VoidCallback onExit;

  const _EmailStep({
    required this.emailCtrl,
    required this.emailError,
    required this.serverError,
    required this.loading,
    required this.agreedToPolicy,
    required this.onAgreedChanged,
    required this.onNext,
    required this.onExit,
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
                Text('Введите\nпочту', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Мы отправим одноразовый код. Аккаунт будет создан автоматически, если его ещё нет.',
                  style: theme.textTheme.bodySmall?.copyWith(
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
                    controller: emailCtrl,
                    autofocus: true,
                    style: theme.textTheme.bodyLarge,
                    cursorColor: ac.secondaryColor,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    onSubmitted: (_) {
                      if (agreedToPolicy) onNext();
                    },
                    decoration: InputDecoration(
                      hintText: 'Эл. почта',
                      hintStyle: theme.textTheme.bodyLarge!.copyWith(
                        color: Colors.grey.shade400,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (emailError != null) _FieldError(emailError!),
                if (serverError != null) ...[
                  const SizedBox(height: 12),
                  _ServerError(serverError!),
                ],
              ],
            ),
          ),
        ),
        _PolicyConsent(agreed: agreedToPolicy, onChanged: onAgreedChanged),
        _BottomBar(
          label: 'Получить код',
          nextIcon: Icons.send_rounded,
          onNext: onNext,
          onNextAvailable: !loading && emailCtrl.text.isNotEmpty && agreedToPolicy,
          loading: loading,
          onExit: onExit,
        ),
      ],
    );
  }
}

// ─── Policy consent ───────────────────────────────────────────────────────────

/// Чекбокс согласия с политикой использования. Ссылка ведёт на termsUrl
/// (как в настройках) и открывается во внешнем браузере.
class _PolicyConsent extends StatefulWidget {
  final bool agreed;
  final ValueChanged<bool> onChanged;

  const _PolicyConsent({required this.agreed, required this.onChanged});

  @override
  State<_PolicyConsent> createState() => _PolicyConsentState();
}

class _PolicyConsentState extends State<_PolicyConsent> {
  late final TapGestureRecognizer _termsLinkTap;
  late final TapGestureRecognizer _privacyLinkTap;

  @override
  void initState() {
    super.initState();
    _termsLinkTap = TapGestureRecognizer()..onTap = () async => GetIt.instance<ApiService>().openTerms();
    _privacyLinkTap = TapGestureRecognizer()..onTap = () async => GetIt.instance<ApiService>().openPrivacy();
  }

  @override
  void dispose() {
    _termsLinkTap.dispose();
    _privacyLinkTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AppearanceController>();
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodySmall?.copyWith(
      color: ac.secondaryColor.withAlpha(180),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 20, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Checkbox(
              value: widget.agreed,
              onChanged: (v) => widget.onChanged(v ?? false),
              activeColor: ac.secondaryColor,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: baseStyle,
                children: [
                  const TextSpan(text: 'Я принимаю '),
                  TextSpan(
                    text: 'политику использования',
                    style: baseStyle?.copyWith(
                      color: ac.secondaryColor,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: _termsLinkTap,
                  ),
                  const TextSpan(text: ' и соглашаюсь с '),
                  TextSpan(
                    text: 'правилами обработки персональных данных',
                    style: baseStyle?.copyWith(
                      color: ac.secondaryColor,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: _privacyLinkTap,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 1 — OTP ─────────────────────────────────────────────────────────────

class _OtpStep extends StatelessWidget {
  final String email;
  final TextEditingController codeCtrl;
  final bool codeError;
  final String? serverError;
  final bool loading;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onBack;

  const _OtpStep({
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
                Text('Введите\nкод', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
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
                ListenableBuilder(
                  listenable: codeCtrl,
                  builder: (context, _) => TextField(
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                ),
                if (serverError != null) ...[
                  const SizedBox(height: 10),
                  _ServerError(serverError!),
                ],
                const SizedBox(height: 20),
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

// ─── Step 2 — Name (new users only) ──────────────────────────────────────────

class _NameStep extends StatelessWidget {
  final TextEditingController nameCtrl;
  final bool loading;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _NameStep({
    required this.nameCtrl,
    required this.loading,
    required this.onNext,
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
                Text('Как вас\nзовут?', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Будет отображаться в вашем профиле.',
                  style: theme.textTheme.bodySmall?.copyWith(
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
                    autofocus: true,
                    style: theme.textTheme.bodyLarge,
                    cursorColor: ac.secondaryColor,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onNext(),
                    decoration: InputDecoration(
                      hintText: 'Имя',
                      hintStyle: theme.textTheme.bodyLarge!.copyWith(
                        color: Colors.grey.shade400,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _BottomBar(
          label: 'Готово',
          nextIcon: Icons.check_rounded,
          onNext: onNext,
          onNextAvailable: !loading,
          loading: loading,
          onBack: onBack,
        ),
      ],
    );
  }
}

// ─── Shared UI widgets ────────────────────────────────────────────────────────

class _FieldError extends StatelessWidget {
  final String text;
  const _FieldError(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 12, top: 5),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: ThemeColors.dangerZone),
    ),
  );
}

class _ServerError extends StatelessWidget {
  final String text;
  const _ServerError(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: ThemeColors.dangerZone.withAlpha(12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ThemeColors.dangerZone.withAlpha(60)),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline, size: 16, color: ThemeColors.dangerZone),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: ThemeColors.dangerZone),
          ),
        ),
      ],
    ),
  );
}

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
    final color = onNextAvailable ? ac.secondaryColor : Colors.grey.shade300;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          if (onExit != null) ...[
            _SideButton(icon: Icons.close_rounded, onTap: onExit!, ac: ac),
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
                            style: Theme.of(context).textTheme.titleMedium!
                                .copyWith(color: ThemeColors.white),
                          ),
                          const SizedBox(width: 8),
                          Icon(nextIcon, color: Colors.white, size: 20),
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
        border: Border.all(color: ac.primaryColor.withAlpha(92)),
      ),
      child: Icon(icon, size: 18, color: ac.secondaryColor.withAlpha(192)),
    ),
  );
}

// ─── Sync-offer dialog ────────────────────────────────────────────────────────

class _SyncOfferDialog extends StatelessWidget {
  const _SyncOfferDialog();

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AppearanceController>();
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: ThemeColors.white,
      title: Row(
        children: [
          Icon(
            Icons.cloud_download_outlined,
            color: ac.secondaryColor,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text('Данные на сервере', style: theme.textTheme.titleMedium),
        ],
      ),
      content: Text(
        'На сервере найдены ваши данные. Загрузить их на это устройство?\n\n'
        'Текущие локальные данные будут заменены.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: ac.secondaryColor.withAlpha(180),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Пропустить',
            style: theme.textTheme.bodySmall?.copyWith(
              color: ac.secondaryColor.withAlpha(140),
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: ac.secondaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Загрузить'),
        ),
      ],
    );
  }
}
