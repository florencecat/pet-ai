import 'package:flutter/material.dart';
import 'package:pet_satellite/models/user_profile.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/user_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:provider/provider.dart';

// ─── Popular Russian cities for autocomplete ─────────────────────────────────

const _kRussianCities = [
  'Москва',
  'Санкт-Петербург',
  'Новосибирск',
  'Екатеринбург',
  'Казань',
  'Нижний Новгород',
  'Челябинск',
  'Самара',
  'Уфа',
  'Ростов-на-Дону',
  'Красноярск',
  'Пермь',
  'Воронеж',
  'Волгоград',
  'Краснодар',
  'Саратов',
  'Тюмень',
  'Тольятти',
  'Ижевск',
  'Барнаул',
  'Ульяновск',
  'Иркутск',
  'Хабаровск',
  'Ярославль',
  'Владивосток',
  'Махачкала',
  'Томск',
  'Оренбург',
  'Кемерово',
  'Новокузнецк',
  'Рязань',
  'Астрахань',
  'Набережные Челны',
  'Пенза',
  'Липецк',
  'Тула',
  'Киров',
  'Чебоксары',
  'Калининград',
  'Брянск',
  'Курск',
  'Иваново',
  'Магнитогорск',
  'Тверь',
  'Нижний Тагил',
  'Ставрополь',
  'Улан-Удэ',
  'Белгород',
  'Сочи',
  'Якутск',
  'Мурманск',
  'Архангельск',
  'Вологда',
  'Симферополь',
  'Владикавказ',
  'Нальчик',
  'Грозный',
  'Саранск',
  'Орёл',
  'Смоленск',
  'Чита',
  'Сургут',
  'Нижневартовск',
  'Череповец',
  'Владимир',
  'Уссурийск',
  'Нижнекамск',
  'Петрозаводск',
  'Кострома',
  'Новороссийск',
  'Таганрог',
  'Йошкар-Ола',
  'Комсомольск-на-Амуре',
  'Балашиха',
  'Подольск',
  'Химки',
  'Мытищи',
  'Люберцы',
  'Одинцово',
  'Красногорск',
];

// ─── Mock verification code ───────────────────────────────────────────────────

const _kMockCode = '123456';

// ─── Card helper ─────────────────────────────────────────────────────────────

Widget _card({required Widget child, EdgeInsets? padding, Color? color}) =>
    Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? ThemeColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );

// ─── Main flow widget ─────────────────────────────────────────────────────────

class UserRegistrationFlow extends StatefulWidget {
  /// If true, the flow was opened to *edit* an existing profile.
  final UserProfile? existing;

  const UserRegistrationFlow({super.key, this.existing});

  @override
  State<UserRegistrationFlow> createState() => _UserRegistrationFlowState();
}

class _UserRegistrationFlowState extends State<UserRegistrationFlow> {
  int _step = 0;
  static const _totalSteps = 2;

  // Step 1
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  // Step 2
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _codeSent = false;
  bool _codeError = false;
  bool _emailError = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _cityCtrl.text = e.city;
      _emailCtrl.text = e.email;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 0) {
      if (_nameCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Введите ваше имя'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() {
        _step--;
        _codeSent = false;
        _codeError = false;
        _codeCtrl.clear();
      });
    }
  }

  void _sendCode() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _emailError = true;
      });
      return;
    }
    setState(() {
      _emailError = false;
      _codeSent = true;
      _codeError = false;
      _codeCtrl.clear();
    });
  }

  void _validateCode() {
    // Verify code if we sent one (mock: accept _kMockCode or skip if email empty)
    if (_codeSent && _codeCtrl.text.length == 6) {
      setState(() => _codeError = _codeCtrl.text.trim() != _kMockCode);
    }
  }

  void _exit() => Navigator.of(context).pop();

  Future<void> _finish() async {
    final email = _emailCtrl.text.trim();

    final profile = UserProfile.create(
      name: _nameCtrl.text.trim(),
      email: email,
      city: _cityCtrl.text.trim(),
    ).copyWith(emailVerified: _codeSent && _codeCtrl.text.trim() == _kMockCode);

    await UserService().save(profile);
    if (mounted) Navigator.of(context).pop(profile);
  }

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
        return _Step1(
          nameCtrl: _nameCtrl,
          cityCtrl: _cityCtrl,
          onNext: _next,
          onExit: _exit,
        );
      case 1:
        return _Step2(
          emailCtrl: _emailCtrl,
          codeCtrl: _codeCtrl,
          codeSent: _codeSent,
          codeError: _codeError,
          emailError: _emailError,
          onSendCode: _sendCode,
          onValidate: _validateCode,
          onNext: _next,
          onBack: () {
            if (_step > 0) setState(() => _step--);
          },
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

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AppearanceController>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  step == totalSteps - 1 ? 'Подтверждение' : 'Ваш профиль',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
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
                    margin: EdgeInsets.only(right: i < totalSteps - 1 ? 6 : 0),
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

// ─── Step 1: Имя + город ─────────────────────────────────────────────────────

class _Step1 extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController cityCtrl;
  final VoidCallback onNext;
  final VoidCallback onExit;

  const _Step1({
    required this.nameCtrl,
    required this.cityCtrl,
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

                // ── Имя ─────────────────────────────────────────────────────
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
                    decoration: InputDecoration(
                      hintText: 'Имя',
                      hintStyle: Theme.of(context).textTheme.bodyLarge!
                          .copyWith(color: Colors.grey.shade400),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Город (с автодополнением) ────────────────────────────────
                _CityAutocomplete(
                  controller: cityCtrl,
                  accentColor: ac.secondaryColor,
                ),
                const SizedBox(height: 8),
                Text(
                  'Город не обязателен',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade400),
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

// ─── City autocomplete ────────────────────────────────────────────────────────

class _CityAutocomplete extends StatelessWidget {
  final TextEditingController controller;
  final Color accentColor;

  const _CityAutocomplete({
    required this.controller,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue value) {
        if (value.text.isEmpty) return const [];
        final q = value.text.toLowerCase();
        return _kRussianCities
            .where((c) => c.toLowerCase().startsWith(q))
            .take(6);
      },
      displayStringForOption: (c) => c,
      onSelected: (c) => controller.text = c,
      fieldViewBuilder: (ctx, ctrl, focusNode, onSubmitted) {
        // Sync external controller → internal Autocomplete controller
        controller.addListener(() {
          if (ctrl.text != controller.text) ctrl.text = controller.text;
        });
        return _card(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: ctrl,
            focusNode: focusNode,
            style: Theme.of(context).textTheme.bodyLarge,
            cursorColor: accentColor,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Город (необязательно)',
              hintStyle: Theme.of(
                context,
              ).textTheme.bodyLarge!.copyWith(color: Colors.grey.shade400),
              border: InputBorder.none,
            ),
            onEditingComplete: onSubmitted,
          ),
        );
      },
      optionsViewBuilder: (ctx, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(16),
            color: ThemeColors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340, maxHeight: 200),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (_, i) {
                  final city = options.elementAt(i);
                  return InkWell(
                    onTap: () => onSelected(city),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: accentColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            city,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Step 2: Email + mock verification ───────────────────────────────────────

class _Step2 extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController codeCtrl;
  final bool codeSent;
  final bool codeError;
  final bool emailError;
  final VoidCallback onSendCode;
  final VoidCallback onValidate;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step2({
    required this.emailCtrl,
    required this.codeCtrl,
    required this.codeSent,
    required this.codeError,
    required this.emailError,
    required this.onSendCode,
    required this.onValidate,
    required this.onNext,
    required this.onBack,
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
                  'Подтвердите\nпочту',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Это поможет восстановить данные и в будущем войти с другого устройства.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                    controller: emailCtrl,
                    style: Theme.of(context).textTheme.bodyLarge,
                    cursorColor: ac.secondaryColor,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !codeSent,
                    decoration: InputDecoration(
                      hintText: 'Эл. почта',
                      hintStyle: Theme.of(context).textTheme.bodyLarge!
                          .copyWith(color: Colors.grey.shade400),
                      border: InputBorder.none,
                      errorText: emailError
                          ? 'Некорректный адрес эл. почты'
                          : null,
                    ),
                  ),
                ),

                // ── Код подтверждения ────────────────────────────────────────
                if (codeSent) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    onChanged: (_) => onValidate(),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          letterSpacing: 14,
                          fontWeight: FontWeight.w700,
                        ),
                    decoration: InputDecoration(
                      hintText: '000000',
                      hintStyle:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                  const SizedBox(height: 10),
                  // Mock hint
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
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: ac.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Тестовый режим: используйте код $_kMockCode',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: ac.secondaryColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        if (!codeSent)
          _BottomBar(
            label: 'Отправить',
            onNext: onSendCode,
            onNextAvailable: true,
            nextIcon: Icons.email_rounded,
            onBack: onBack,
          )
        else
          _BottomBar(
            label: 'Подтвердить',
            onNext: onNext,
            onNextAvailable: codeSent && codeCtrl.text.length == 6 && !codeError,
            nextIcon: Icons.verified_rounded,
            onBack: onBack,
          ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  final VoidCallback onNext;
  final bool onNextAvailable;
  final VoidCallback? onBack;
  final VoidCallback? onExit;
  final String label;
  final IconData nextIcon;

  const _BottomBar({
    required this.onNext,
    required this.onNextAvailable,
    this.onBack,
    this.onExit,
    required this.label,
    this.nextIcon = Icons.arrow_forward_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final color = onNextAvailable
        ? context.watch<AppearanceController>().secondaryColor
        : Colors.grey;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          if (onExit != null) ...[
            GestureDetector(
              onTap: onExit,
              child: Container(
                width: 50,
                height: 54,
                decoration: BoxDecoration(
                  color: ThemeColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: context
                        .watch<AppearanceController>()
                        .primaryColor
                        .withAlpha(92),
                  ),
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: context
                      .watch<AppearanceController>()
                      .secondaryColor
                      .withAlpha(192),
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          if (onBack != null) ...[
            GestureDetector(
              onTap: onBack,
              child: Container(
                width: 50,
                height: 54,
                decoration: BoxDecoration(
                  color: ThemeColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: context
                        .watch<AppearanceController>()
                        .primaryColor
                        .withAlpha(92),
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: context
                      .watch<AppearanceController>()
                      .secondaryColor
                      .withAlpha(192),
                  size: 18,
                ),
              ),
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
                  boxShadow: [
                    BoxShadow(
                      color: color.withAlpha(70),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: ThemeColors.white,
                      ),
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
