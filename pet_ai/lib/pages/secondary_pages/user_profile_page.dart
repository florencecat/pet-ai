import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:pet_satellite/models/user_profile.dart';
import 'package:pet_satellite/services/ai_service.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/cloud_sync_service.dart';
import 'package:pet_satellite/services/event_service.dart';
import 'package:pet_satellite/services/file_storage_service.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/services/user_profile_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/app_text_styles.dart';
import 'package:pet_satellite/theme/widgets/base_widgets.dart';
import 'package:pet_satellite/theme/widgets/confirm_delete.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/suggestion_list.dart';
import 'package:provider/provider.dart';

// ─── Russian cities ───────────────────────────────────────────────────────────

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

const _kMockCode = '123456';

bool _isValidEmail(String email) {
  if (email.isEmpty) return false;
  final at = email.indexOf('@');
  if (at <= 0) return false;
  final dot = email.indexOf('.', at + 2);
  return dot != -1 && dot < email.length - 1;
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class UserProfileEditPage extends StatefulWidget {
  final UserProfile profile;

  const UserProfileEditPage({super.key, required this.profile});

  @override
  State<UserProfileEditPage> createState() => _UserProfileEditPageState();
}

class _UserProfileEditPageState extends State<UserProfileEditPage> {
  late UserProfile _profile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);
    await UserProfileService().save(_profile);
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context, _profile);
    }
  }

  // ── Field sheets ─────────────────────────────────────────────────────────

  /// Generic single-field text sheet (name, etc.).
  /// Captures [accent] before opening so no Provider subscription inside.
  Future<void> _editName() async {
    final accent = context.read<AppearanceController>().primaryColor;
    final ctrl = TextEditingController(text: _profile.name);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableSheet(
        title: 'Имя',
        onBack: () => Navigator.pop(ctx),
        initialSize: 0.45,
        minSize: 0.35,
        maxSize: 0.9,
        body: _TextSheetBody(
          ctrl: ctrl,
          hint: 'Имя',
          accent: accent,
          capitalize: TextCapitalization.words,
          onSave: (v) => Navigator.pop(ctx, v),
        ),
      ),
    );
    ctrl.dispose();
    if (result != null && result.isNotEmpty) {
      setState(() => _profile = _profile.copyWith(name: result));
    }
  }

  Future<void> _editCity() async {
    // Capture accent BEFORE opening the sheet to avoid context.watch inside
    final accent = context.read<AppearanceController>().primaryColor;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CitySheet(initial: _profile.city, accent: accent),
    );
    if (result != null && mounted) {
      setState(() => _profile = _profile.copyWith(city: result));
    }
  }

  /// Opens the combined email-entry + verification sheet.
  /// Email is only written to the profile when verification succeeds.
  Future<void> _openEmailSheet({bool startAtVerification = false}) async {
    final accent = context.read<AppearanceController>().primaryColor;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmailEditSheet(
        initialEmail: _profile.email,
        accent: accent,
        startAtVerification: startAtVerification && _profile.email.isNotEmpty,
      ),
    );
    // result == verified email; null == cancelled
    if (result != null && mounted) {
      setState(
        () => _profile = _profile.copyWith(email: result, emailVerified: true),
      );
      await UserProfileService().save(_profile);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Почта подтверждена ✓')));
      }
    }
  }

  /// Безвозвратно удаляет аккаунт: сначала все данные на сервере
  /// (питомцы/история/файлы/чаты), затем саму запись пользователя, затем
  /// локальные данные. Удаление сетевое — при сбое ничего локально не трогаем и
  /// показываем ошибку, чтобы не отрапортовать об удалении ложно (данные
  /// пользователя не должны остаться на сервере).
  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Удалить аккаунт?',
      message:
          'Все данные — питомцы, история, документы и переписка с ИИ — будут '
          'безвозвратно удалены с сервера и с этого устройства. Восстановить '
          'их будет невозможно.',
      ignorePreferences: true,
    );
    if (!confirmed || !context.mounted) return;

    // Модальный индикатор на время сетевого удаления (несколько секунд).
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final sync = GetIt.instance<CloudSyncService>();

    try {
      await sync.wipeRemote();
      await UserProfileService().deleteAccount();
    } catch (_) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              sync.lastError ?? 'Не удалось удалить аккаунт — проверьте связь',
            ),
          ),
        );
      }
      return;
    }

    // Сервер очищен — стираем локальные данные (файлы документов, события,
    // профили, историю чата и локальный профиль пользователя).
    final profiles = await PetProfileService().loadAllProfiles();
    for (final p in profiles) {
      await FileStorageService().clearAll(p.id);
    }
    await EventService().clearEventsForAll(profiles.map((p) => p.id).toList());
    await PetProfileService().clearAll();
    await AIChatController.clearMessageHistory();
    await UserProfileService().delete();

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // закрыть индикатор
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil('/registration', (_) => false);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AppearanceController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Профиль', style: theme.textTheme.titleMedium),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Сохранить',
                    style: TextStyle(
                      color: ac.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
        children: [
          // ── Avatar ────────────────────────────────────────────────────────
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ac.primaryColor.withAlpha(25),
                border: Border.all(
                  color: ac.primaryColor.withAlpha(80),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.person_rounded,
                color: ac.primaryColor,
                size: 34,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Основное ─────────────────────────────────────────────────────
          _SectionHeader('Основное'),
          const SizedBox(height: 6),
          GlassPlate(
            padding: 0,
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.person_outline,
                  label: 'Имя',
                  value: _profile.name.isEmpty ? '—' : _profile.name,
                  accent: ac.primaryColor,
                  onTap: _editName,
                ),
                _Separator(),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Город',
                  value: _profile.city.isEmpty ? 'Не указан' : _profile.city,
                  accent: ac.primaryColor,
                  muted: _profile.city.isEmpty,
                  onTap: _editCity,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Эл. почта ────────────────────────────────────────────────────
          _SectionHeader('Эл. почта'),
          const SizedBox(height: 6),
          GlassPlate(
            padding: 0,
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.email_outlined,
                  label: _profile.email.isEmpty ? 'Добавить почту' : 'Адрес',
                  value: _profile.email.isEmpty ? 'Не указана' : _profile.email,
                  accent: ac.primaryColor,
                  muted: _profile.email.isEmpty,
                  trailing: _profile.emailVerified ? _VerifiedBadge() : null,
                  onTap: () => _openEmailSheet(),
                ),
                if (_profile.email.isNotEmpty && !_profile.emailVerified) ...[
                  _Separator(),
                  _ActionRow(
                    icon: Icons.verified_outlined,
                    label: 'Подтвердить почту',
                    accent: ac.primaryColor,
                    onTap: () => _openEmailSheet(startAtVerification: true),
                  ),
                ],
              ],
            ),
          ),

          if (_profile.email.isEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Почта потребуется для синхронизации и резервных копий.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ac.secondaryColor.withAlpha(140),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // ── Удалить профиль ───────────────────────────────────────────────
          GlassPlate(
            padding: 0,
            child: _ActionRow(
              icon: Icons.delete_outline,
              label: 'Удалить профиль',
              accent: ThemeColors.dangerZone,
              onTap: () async => await _deleteAccount(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextSheetBody extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final Color accent;
  final TextCapitalization capitalize;
  final ValueChanged<String> onSave;

  const _TextSheetBody({
    required this.ctrl,
    required this.hint,
    required this.accent,
    required this.onSave,
    this.capitalize = TextCapitalization.sentences,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: capitalize,
          decoration: baseInputDecoration(context, hint),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => onSave(ctrl.text.trim()),
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 2),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: context.watch<AppearanceController>().secondaryColor.withAlpha(
          160,
        ),
        letterSpacing: 0.8,
      ),
    ),
  );
}

// ─── Info row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final bool muted;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.muted = false,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = context.watch<AppearanceController>().secondaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: accent.withAlpha(200)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: secondary.withAlpha(140),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: muted ? secondary.withAlpha(100) : secondary,
                      fontWeight: muted ? FontWeight.w400 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ] else if (onTap != null)
              Icon(
                Icons.chevron_right,
                size: 18,
                color: secondary.withAlpha(100),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Action row ───────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback? onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Icon(Icons.chevron_right, size: 18, color: accent.withAlpha(140)),
        ],
      ),
    ),
  );
}

// ─── Verified badge ───────────────────────────────────────────────────────────

class _VerifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: ThemeColors.ok.mainColor.withAlpha(20),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: ThemeColors.ok.mainColor.withAlpha(80)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.verified_outlined,
          size: 13,
          color: ThemeColors.ok.mainColor,
        ),
        const SizedBox(width: 4),
        Text(
          'Подтверждена',
          style: context.subtitleStyle.copyWith(
            color: ThemeColors.ok.mainColor,
          ),
        ),
      ],
    ),
  );
}

// ─── Separator ────────────────────────────────────────────────────────────────

class _Separator extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, indent: 46, color: ThemeColors.border.withAlpha(50));
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET WIDGETS
// These widgets are shown inside showModalBottomSheet → DraggableSheet.
// They must NOT call context.watch<AppearanceController>() because the
// InheritedElement can be deactivated before its dependents during sheet
// dismissal, causing the '_dependents.isEmpty' assertion.
// Solution: receive [accent] as a constructor parameter.
// ─────────────────────────────────────────────────────────────────────────────

// ─── City sheet ───────────────────────────────────────────────────────────────

class _CitySheet extends StatefulWidget {
  final String initial;
  final Color accent; // captured outside; no context.watch inside

  const _CitySheet({required this.initial, required this.accent});

  @override
  State<_CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<_CitySheet> {
  late final TextEditingController _ctrl;
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
    _ctrl.addListener(_onChanged);
    _onChanged();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    final q = _ctrl.text.toLowerCase();
    setState(() {
      _suggestions = q.isEmpty
          ? []
          : _kRussianCities
                .where((c) => c.toLowerCase().startsWith(q))
                .take(6)
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // No context.watch — use widget.accent directly.
    return DraggableSheet(
      title: 'Город',
      onBack: () => Navigator.pop(context),
      initialSize: 0.55,
      minSize: 0.4,
      maxSize: 0.9,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: baseInputDecoration(
              context,
              'Город',
              suffixIcon: _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _ctrl.clear();
                        setState(() => _suggestions = []);
                      },
                    )
                  : null,
            ),
          ),

          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            SuggestionList(
              suggestions: _suggestions,
              accent: widget.accent,
              onSelected: (city) {
                _ctrl.text = city;
                setState(() => _suggestions = []);
              },
            ),
          ],

          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: widget.accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Сохранить'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text(
              'Очистить',
              style: TextStyle(color: ThemeColors.dangerZone.withAlpha(180)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Combined email edit + verification sheet ─────────────────────────────────
// Step 1: enter & validate email → "Отправить код"
// Step 2: enter 6-digit code → "Подтвердить"
// Returns the verified email string, or null if cancelled.

class _EmailEditSheet extends StatefulWidget {
  final String initialEmail;
  final Color accent; // captured outside; no context.watch inside
  final bool startAtVerification;

  const _EmailEditSheet({
    required this.initialEmail,
    required this.accent,
    this.startAtVerification = false,
  });

  @override
  State<_EmailEditSheet> createState() => _EmailEditSheetState();
}

class _EmailEditSheetState extends State<_EmailEditSheet> {
  late final TextEditingController _emailCtrl;
  final _codeCtrl = TextEditingController();

  bool _codeSent = false;
  bool _emailError = false;
  bool _codeError = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
    if (widget.startAtVerification) {
      _codeSent = true;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _sendCode() {
    final email = _emailCtrl.text.trim();
    if (!_isValidEmail(email)) {
      setState(() => _emailError = true);
      return;
    }
    setState(() {
      _emailError = false;
      _codeSent = true;
      _codeError = false;
      _codeCtrl.clear();
    });
  }

  void _verify() {
    if (_codeCtrl.text.trim() == _kMockCode) {
      Navigator.pop(context, _emailCtrl.text.trim());
    } else {
      setState(() => _codeError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // No context.watch — use widget.accent directly.
    return DraggableSheet(
      title: _codeSent ? 'Введите код' : 'Эл. почта',
      centerTitle: true,
      onBack: _codeSent
          ? () => setState(() {
              _codeSent = false;
              _codeError = false;
              _codeCtrl.clear();
            })
          : () => Navigator.pop(context),
      initialSize: 0.55,
      minSize: 0.4,
      maxSize: 0.9,
      body: _codeSent ? _buildCodeStep(context) : _buildEmailStep(context),
    );
  }

  Widget _buildEmailStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _emailCtrl,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Адрес эл. почты',
            labelStyle: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade500),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            errorText: _emailError ? 'Введите корректный адрес' : null,
          ),
          onChanged: (_) {
            if (_emailError) setState(() => _emailError = false);
          },
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _sendCode,
          icon: const Icon(Icons.send_outlined, size: 18),
          label: const Text('Отправить код'),
          style: FilledButton.styleFrom(
            backgroundColor: widget.accent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Email reminder chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.accent.withAlpha(18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.accent.withAlpha(60)),
          ),
          child: Row(
            children: [
              Icon(Icons.email_outlined, size: 15, color: widget.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _emailCtrl.text.trim(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Large centred code input
        TextField(
          controller: _codeCtrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          onChanged: (_) {
            if (_codeError) setState(() => _codeError = false);
          },
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            letterSpacing: 14,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: '000000',
            hintStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
              letterSpacing: 14,
              color: Colors.grey.shade300,
            ),
            counterText: '',
            errorText: _codeError ? 'Неверный код' : null,
            filled: true,
            fillColor: Colors.white,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.accent.withAlpha(15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.accent.withAlpha(50)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 15, color: widget.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Тестовый режим · код $_kMockCode',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        FilledButton.icon(
          onPressed: _verify,
          icon: const Icon(Icons.verified_outlined, size: 18),
          label: const Text('Подтвердить'),
          style: FilledButton.styleFrom(
            backgroundColor: widget.accent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() {
            _codeSent = false;
            _codeError = false;
            _codeCtrl.clear();
          }),
          child: Text(
            'Изменить адрес',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      ],
    );
  }
}
