import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:pet_satellite/models/event.dart';
import 'package:pet_satellite/models/pet_profile.dart';
import 'package:pet_satellite/models/suggested_event.dart';
import 'package:pet_satellite/models/treatment.dart';
import 'package:pet_satellite/models/user_profile.dart';
import 'package:pet_satellite/pages/registration_flows/user_registration_flow.dart';
import 'package:pet_satellite/services/ai_service.dart';
import 'package:pet_satellite/services/api_service.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/authentification_service.dart';
import 'package:pet_satellite/services/event_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/activity_indicator.dart';
import 'package:pet_satellite/theme/widgets/base_widgets.dart';
import 'package:pet_satellite/theme/widgets/confirm_delete.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/event_sheet.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/hold_to_talk_mic.dart';
import 'package:provider/provider.dart';

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  late final Future<AIChatController> _future;

  @override
  void initState() {
    super.initState();
    _future = _createController();
  }

  Future<AIChatController> _createController() async {
    final controller = AIChatController(
      basePath: GetIt.instance<ApiService>().aiUrl,
    );
    await controller.init();
    return controller;
  }

  @override
  Widget build(BuildContext context) {
    final auth = GetIt.instance<AuthService>();
    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        if (!auth.isAuthenticated) {
          return Scaffold(
            resizeToAvoidBottomInset: false,
            body: Container(
              decoration: context
                  .watch<AppearanceController>()
                  .gradientDecoration,
              child: const SafeArea(bottom: false, child: _AuthGate()),
            ),
          );
        }
        return FutureBuilder<AIChatController>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Scaffold(
                body: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: context
                      .watch<AppearanceController>()
                      .gradientDecoration,
                  child: InlineLoading(isLoading: !snapshot.hasData),
                ),
              );
            }

            return ChangeNotifierProvider.value(
              value: snapshot.data!,
              child: Builder(
                builder: (context) {
                  return Scaffold(
                    // Клавиатуру обрабатываем вручную в _ChatView (Column +
                    // отступ инпута), поэтому Scaffold не ресайзим — градиент
                    // остаётся на весь экран, без «прыжков».
                    resizeToAvoidBottomInset: false,
                    body: Container(
                      decoration: context
                          .watch<AppearanceController>()
                          .gradientDecoration,
                      // bottom: false — нижний отступ задаём сами.
                      child: const SafeArea(bottom: false, child: _ChatView()),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────
// Auth gate — blocks the chat until the user signs in.
// ──────────────────────────────────────────────────────────

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  Future<void> _openLogin(BuildContext context) async {
    await Navigator.of(context).push<UserProfile?>(
      MaterialPageRoute(
        builder: (_) => const UserRegistrationFlow(),
        fullscreenDialog: true,
      ),
    );
    // No setState needed — AuthService notifies and the outer AnimatedBuilder
    // rebuilds when the auth store updates.
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppearanceController>().primaryColor;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SoftRoundedIcon(
                icon: Icons.auto_awesome,
                gradient: ThemeColors.aiChatIconGradient,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Помощник по уходу',
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: GlassPlate(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Войдите, чтобы общаться с ассистентом',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Аккаунт нужен для работы ИИ-помощника и открывает '
                        'дополнительные возможности:',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: context
                              .watch<AppearanceController>()
                              .secondaryColor,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _Benefit(
                        icon: Icons.auto_awesome,
                        color: accent,
                        title: 'ИИ-ветеринар на связи',
                        subtitle:
                            'Советы по уходу с учётом истории и событий '
                            'питомца.',
                      ),
                      _Benefit(
                        icon: Icons.cloud_done_outlined,
                        color: accent,
                        title: 'Облачное сохранение',
                        subtitle:
                            'Профили и история не потеряются при смене '
                            'устройства.',
                      ),
                      _Benefit(
                        icon: Icons.family_restroom_outlined,
                        color: accent,
                        title: 'Семейный доступ',
                        subtitle:
                            'Скоро: несколько человек смогут вести одного '
                            'питомца вместе.',
                        comingSoon: true,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _openLogin(context),
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Войти или создать аккаунт'),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool comingSoon;

  const _Benefit({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withAlpha(28),
              border: Border.all(color: color.withAlpha(70), width: 1.2),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(title, style: theme.textTheme.titleSmall),
                    ),
                    if (comingSoon) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withAlpha(28),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'скоро',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context
                        .watch<AppearanceController>()
                        .secondaryColor
                        .withAlpha(160),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Status dots
// ──────────────────────────────────────────────────────────

class _OfflineDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = Colors.grey;
    return SizedBox(
      width: 8,
      height: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [BoxShadow(color: color.withAlpha(128), blurRadius: 4)],
        ),
      ),
    );
  }
}

class _OnlineDot extends StatefulWidget {
  final Color color;

  const _OnlineDot({required this.color});

  @override
  State<_OnlineDot> createState() => _OnlineDotState();
}

class _OnlineDotState extends State<_OnlineDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _opacity = Tween<double>(
      begin: 0.45,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 8,
      height: 8,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final alpha = (_opacity.value * 255).round();
          return DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withAlpha(alpha),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withAlpha((alpha * 0.55).round()),
                  blurRadius: 4 + _opacity.value * 5,
                  spreadRadius: _opacity.value,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Main chat view
// ──────────────────────────────────────────────────────────

class _ChatView extends StatefulWidget {
  const _ChatView();

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  late final AIChatController _controller;
  late Future<bool> _future;
  Timer? _healthTimer;

  @override
  void initState() {
    super.initState();
    _controller = context.read<AIChatController>();
    _future = _controller.healthCheck();
    // Периодически перепроверяем доступность бота.
    // ВАЖНО: блочное тело setState — стрелочный вариант
    // `setState(() => _future = ...)` возвращает Future и Flutter бросает
    // «setState() callback argument returned a Future».
    _healthTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {
        _future = _controller.healthCheck();
      });
    });
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    super.dispose();
  }

  void _openHistorySheet(AIChatController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HistorySheet(controller: controller),
    );
  }

  void _openAttachmentPicker(AIChatController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AttachmentPickerSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AIChatController>();

    // Ручное управление клавиатурой (Scaffold не ресайзит): когда она открыта —
    // поднимаем нижний блок на её высоту, иначе — на безопасную зону (навбар).
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final bottomInset = keyboardInset > 0 ? keyboardInset : safeBottom;

    final isEmpty = controller.messages.isEmpty;

    return Column(
      children: [
        const SizedBox(height: 12),
        _ChatHeader(
          controller: controller,
          statusFuture: _future,
          onNewThread: controller.messages.isNotEmpty
              ? () => controller.startNewThread()
              : null,
          onHistory: () => _openHistorySheet(controller),
        ),

        // ── Сообщения (занимают всё свободное место, ужимаются с клавиатурой) ─
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: isEmpty
                ? SingleChildScrollView(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
                    child: _WelcomeState(petName: controller.petName),
                  )
                : _FadingMessageList(controller: controller),
          ),
        ),

        // ── Нижний блок: индикатор/ошибка + чип вложения + поле ввода ─────────
        Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SizeTransition(sizeFactor: anim, child: child),
                ),
                child: controller.isLoading
                    ? const Padding(
                        key: ValueKey('typing'),
                        padding: EdgeInsets.fromLTRB(20, 0, 16, 6),
                        child: _TypingIndicator(),
                      )
                    : controller.error != null
                    ? Padding(
                        key: const ValueKey('error'),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                        child: _ErrorBanner(
                          message: controller.error!,
                          canRetry: controller.canRetry,
                          onRetry: () => controller.retryLast(),
                          onDismiss: () => controller.clearError(),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('none')),
              ),
              if (controller.pendingAttachment != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: _AttachmentChip(
                    attachment: controller.pendingAttachment!,
                    onRemove: controller.clearAttachment,
                  ),
                ),
              _InputBar(onAttach: () => _openAttachmentPicker(controller)),
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────
// Header
// ──────────────────────────────────────────────────────────

class _ChatHeader extends StatelessWidget {
  final AIChatController controller;
  final Future<bool> statusFuture;
  final VoidCallback? onNewThread;
  final VoidCallback onHistory;

  const _ChatHeader({
    required this.controller,
    required this.statusFuture,
    required this.onNewThread,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppearanceController>().primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassPlate(
        child: ListTile(
          leading: SoftRoundedIcon(
            icon: Icons.auto_awesome,
            gradient: ThemeColors.aiChatIconGradient,
          ),
          title: Text(
            'Помощник по уходу',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          subtitle: FutureBuilder<bool>(
            future: statusFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return Row(
                  spacing: 6,
                  children: [
                    _OfflineDot(),
                    Text(
                      'проверка связи…',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.copyWith(color: Colors.grey),
                    ),
                  ],
                );
              }
              final online = snapshot.data == true;
              return Row(
                spacing: 6,
                children: online
                    ? [
                        _OnlineDot(color: ThemeColors.aiChatOnlineColor),
                        Text(
                          'на связи',
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(color: ThemeColors.aiChatOnlineColor),
                        ),
                      ]
                    : [
                        _OfflineDot(),
                        Text(
                          'оффлайн',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium!.copyWith(color: Colors.grey),
                        ),
                      ],
              );
            },
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Новый диалог',
                icon: Icon(
                  Icons.add_comment_outlined,
                  color: onNewThread != null ? accent : Colors.black12,
                ),
                onPressed: onNewThread,
              ),
              IconButton(
                tooltip: 'История общения',
                icon: Icon(Icons.history, color: accent),
                onPressed: onHistory,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Message list with a cheap top fade (messages dissolve under the header)
// ──────────────────────────────────────────────────────────

class _FadingMessageList extends StatelessWidget {
  final AIChatController controller;
  const _FadingMessageList({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      // Мягкое «растворение» сообщений у верхней кромки списка (под шапкой).
      // Один шейдер — дёшево, без per-frame BackdropFilter.
      shaderCallback: (rect) {
        final h = rect.height;
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Colors.transparent, Colors.black],
          stops: [0.0, (28 / h).clamp(0.0, 1.0)],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: ListView.builder(
        reverse: true,
        clipBehavior: Clip.hardEdge,
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        itemCount: controller.messages.length,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final msgs = controller.messages;
          final msg = msgs[msgs.length - 1 - index];
          return _MessageBubble(msg: msg);
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Empty / welcome state
// ──────────────────────────────────────────────────────────

class _WelcomeState extends StatelessWidget {
  final String petName;

  const _WelcomeState({required this.petName});

  @override
  Widget build(BuildContext context) {
    final chat = context.read<AIChatController>();
    final primaryColor = context.watch<AppearanceController>().primaryColor;

    const quickReplies = [
      'Что ты умеешь?',
      'Сколько корма в день?',
      'Когда ближайшая прививка?',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SoftRoundedIcon(
                icon: Icons.auto_awesome,
                gradient: ThemeColors.aiChatIconGradient,
                size: 14,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: _BubbleContainer(
                  isUser: false,
                  child: Text(
                    'Привет! Я знаю историю $petName и могу подсказать про корм, '
                    'прививки или поведение. Можно прикрепить запись (🧷) — '
                    'я учту её в ответе. О чём хочешь узнать?',
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: context
                          .watch<AppearanceController>()
                          .secondaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: quickReplies.map((reply) {
                return GlassCard(
                  callback: () {
                    HapticFeedback.lightImpact();
                    chat.sendMessage(reply);
                  },
                  padding: 10,
                  transparent: true,
                  color: primaryColor,
                  child: Text(
                    reply,
                    style: const TextStyle(

                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Bubble container
// ──────────────────────────────────────────────────────────

class _BubbleContainer extends StatelessWidget {
  final bool isUser;
  final Widget child;
  final Widget? widget;
  final bool showWidget;

  const _BubbleContainer({
    required this.isUser,
    required this.child,
    this.widget,
    this.showWidget = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isUser
        ? context.watch<AppearanceController>().primaryColor
        : Colors.white;

    final borderRadius = isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          );

    return AnimatedContainer(
      duration: Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: color,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          // Виджет предложенных событий разворачивается анимацией, когда печать
          // ответа заканчивается (showWidget). AnimatedSize обёрнут только вокруг
          // виджета, поэтому текст во время трансляции растёт без задержки, а на
          // перезагрузке (size не меняется) анимация не проигрывается повторно.
          if (widget != null)
            AnimatedSize(
              duration: const Duration(milliseconds: 340),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topLeft,
              child: showWidget ? widget! : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Message bubble
// ──────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;

  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';

    final textWidget = Text(
      msg.content,
      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
        inherit: true,
        color: isUser
            ? ThemeColors.white
            : context.watch<AppearanceController>().secondaryColor,
      ),
    );

    final events = isUser ? const <SuggestedEvent>[] : msg.attachedEvents;

    final suggestedEventWidget = events.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < events.length; i++) ...[
                const _SuggestedDivider(),
                _SuggestedEventCard(msg: msg, index: i, event: events[i]),
              ],
            ],
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                SoftRoundedIcon(
                  icon: Icons.auto_awesome,
                  gradient: ThemeColors.aiChatIconGradient,
                  size: 14,
                ),
                const SizedBox(width: 6),
              ],
              _BubbleContainer(
                isUser: isUser,
                widget: suggestedEventWidget,
                showWidget: msg.completed,
                child: textWidget,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Suggested-event card (under an assistant message)
// ──────────────────────────────────────────────────────────

class _SuggestedEventCard extends StatefulWidget {
  final ChatMessage msg;
  final int index;
  final SuggestedEvent event;

  const _SuggestedEventCard({
    required this.msg,
    required this.index,
    required this.event,
  });

  @override
  State<_SuggestedEventCard> createState() => _SuggestedEventCardState();
}

class _SuggestedEventCardState extends State<_SuggestedEventCard> {
  bool _busy = false;

  SuggestedEvent get _event => widget.event;

  Future<void> _create() async {
    setState(() => _busy = true);
    await context.read<AIChatController>().createSuggestedEvent(
      widget.msg,
      widget.index,
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _cancel() async {
    await context.read<AIChatController>().cancelSuggestedEvent(
      widget.msg,
      widget.index,
    );
  }

  Future<void> _view() async {
    final id = _event.createdEventId;
    if (id == null) return;
    final controller = context.read<AIChatController>();
    final event = await controller.findCreatedEvent(id);
    if (!mounted) return;
    if (event == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Событие не найдено')));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventSheet(event: event),
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = _event.category;
    final created = _event.status == SuggestedEventStatus.created;
    final cancelled = _event.status == SuggestedEventStatus.cancelled;
    final accent = context.watch<AppearanceController>().primaryColor;
    final theme = Theme.of(context);

    final whenLabel = DateFormat('d MMM, HH:mm', 'ru').format(_event.dateTime);

    // ── Заголовок-статус ──────────────────────────────────────────────────
    late final Widget caption;
    if (created) {
      caption = _CaptionRow(
        icon: Icons.check_circle,
        color: ThemeColors.ok.mainColor,
        text: 'Событие создано',
      );
    } else if (cancelled) {
      caption = _CaptionRow(
        icon: Icons.cancel_outlined,
        color: Colors.grey,
        text: 'Не создано',
      );
    } else {
      caption = _CaptionRow(
        icon: Icons.event_outlined,
        color: accent,
        text: 'Предлагаю добавить событие',
      );
    }

    final iconColor = cancelled ? Colors.grey : category.color;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        caption,
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withAlpha(28),
                border: Border.all(color: iconColor.withAlpha(70), width: 1.2),
              ),
              child: Icon(category.icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _event.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      decoration: cancelled ? TextDecoration.lineThrough : null,
                      color: cancelled ? Colors.grey : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 13,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(whenLabel, style: theme.textTheme.bodySmall),
                      if (_event.repeat != RepeatInterval.none) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.repeat,
                          size: 13,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _event.repeat.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Созданная карточка кликабельна — подсказываем шевроном.
            if (created)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: accent.withAlpha(160),
                ),
              ),
          ],
        ),

        // ── Действия (только для ожидающих подтверждения) ────────────────
        if (!created && !cancelled) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _cancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Отмена'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _create,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Создать'),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    // Созданная карточка целиком открывает событие по нажатии.
    if (created) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _view,
        child: body,
      );
    }
    return body;
  }
}

/// Тонкий разделитель внутри пузыря сообщения — отделяет текст ответа от
/// карточек предложенных событий и карточки друг от друга.
class _SuggestedDivider extends StatelessWidget {
  const _SuggestedDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1, thickness: 1, color: Colors.grey.withAlpha(40)),
    );
  }
}

class _CaptionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _CaptionRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────
// Animated typing indicator (three bouncing dots)
// ──────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SoftRoundedIcon(
          icon: Icons.auto_awesome,
          gradient: ThemeColors.aiChatIconGradient,
          size: 14,
        ),
        const SizedBox(width: 6),
        _BubbleContainer(
          isUser: false,
          child: SizedBox(
            width: 38,
            height: 16,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(3, (i) {
                    final t = (_ctrl.value - i * 0.18) % 1.0;
                    // Подъём в первой трети цикла, затем покой.
                    final lift = t < 0.4
                        ? Curves.easeOut.transform(t / 0.4)
                        : 1 -
                              Curves.easeIn.transform(
                                ((t - 0.4) / 0.6).clamp(0.0, 1.0),
                              );
                    return Transform.translate(
                      offset: Offset(0, -3.0 * lift),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ThemeColors.aiChatOnlineColor.withAlpha(
                            (120 + 135 * lift).round(),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────
// Error banner with retry
// ──────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  const _ErrorBanner({
    required this.message,
    required this.canRetry,
    required this.onRetry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPlate(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: ThemeColors.dangerZone, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ThemeColors.dangerZone,
                ),
              ),
            ),
            if (canRetry)
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  size: 20,
                  color: context.watch<AppearanceController>().primaryColor,
                ),
                onPressed: onRetry,
              ),
            IconButton(
              onPressed: onDismiss,
              icon: Icon(
                Icons.close,
                size: 20,
                color: ThemeColors.dangerZone.withAlpha(160),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Attachment chip (above input)
// ──────────────────────────────────────────────────────────

class _AttachmentChip extends StatelessWidget {
  final ChatAttachment attachment;
  final VoidCallback onRemove;

  const _AttachmentChip({required this.attachment, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: attachment.color.withAlpha(90)),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(16), blurRadius: 6),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(attachment.icon, size: 16, color: attachment.color),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                attachment.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close, size: 16, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Input bar
// ──────────────────────────────────────────────────────────

class _InputBar extends StatefulWidget {
  final VoidCallback onAttach;
  const _InputBar({required this.onAttach});

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final controller = TextEditingController();

  /// Текст поля на момент начала голосового ввода — распознанное дописываем к
  /// нему, чтобы не затирать уже набранное.
  String _voiceBase = '';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _send(AIChatController chat) {
    HapticFeedback.mediumImpact();
    chat.sendMessage(controller.text.trim());
    controller.clear();
    setState(() {});
  }

  void _onVoiceText(String words) {
    final sep = _voiceBase.isEmpty || _voiceBase.endsWith(' ') ? '' : ' ';
    final text = words.isEmpty ? _voiceBase : '$_voiceBase$sep$words';
    setState(() {
      controller.text = text;
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<AIChatController>();
    final accent = context.watch<AppearanceController>().primaryColor;

    final hasText = controller.text.trim().isNotEmpty;
    final canSend = hasText && !chat.isLoading;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // Input pill (attach + text field)
          Expanded(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: accent, width: 2),
                borderRadius: BorderRadiusGeometry.circular(24),
              ),
              child: Padding(
                padding: EdgeInsetsGeometry.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    GlassCard(
                      useShadow: false,
                      callback: chat.isLoading ? null : widget.onAttach,
                      padding: 10,
                      child: Icon(
                        Icons.attach_file_rounded,
                        color: chat.pendingAttachment != null
                            ? accent
                            : Colors.grey.shade500,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        maxLines: 3,
                        minLines: 1,
                        textInputAction: TextInputAction.newline,
                        decoration: baseInputDecoration(
                          context,
                          hint: 'Спросите о питомце...',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    // Голосовой ввод «по удержанию» (как в дневнике).
                    HoldToTalkMic(
                      onText: _onVoiceText,
                      onStart: () => _voiceBase = controller.text,
                      activeColor: ThemeColors.dangerZone,
                      idleColor: Colors.grey.shade500,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Отступ перед кнопкой схлопывается вместе с ней.
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            width: hasText ? 8 : 0,
          ),

          // Send button: спрятана при пустом поле, выезжает справа при вводе.
          // ClipRRect со скруглением кнопки — иначе прямоугольный клип
          // оставляет уголки фона в углах при сжатии/расширении.
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(24)),
            child: AnimatedAlign(
              alignment: Alignment.centerRight,
              widthFactor: hasText ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: hasText ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: GlassCard(
                  color: accent,
                  callback: canSend ? () => _send(chat) : null,
                  padding: 10,
                  child: Icon(
                    Icons.send,
                    color: canSend ? Colors.white : Colors.grey.shade400,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// History sheet — interactive threads
// ──────────────────────────────────────────────────────────

class _HistorySheet extends StatefulWidget {
  final AIChatController controller;

  const _HistorySheet({required this.controller});

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  late Future<List<ArchivedThread>> _future;

  AIChatController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _future = _controller.loadArchivedThreads();
  }

  void _reload() {
    setState(() => _future = _controller.loadArchivedThreads());
  }

  String _formatDate(DateTime date) =>
      DateFormat('d MMMM yyyy', 'ru_RU').format(date);

  Future<void> _deleteThread(ArchivedThread thread) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Удалить чат?',
      message: 'Переписка будет удалена без возможности восстановления.',
    );
    if (!confirmed) return;
    await _controller.deleteThread(thread.boxName);
    _reload();
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить все чаты?'),
        content: const Text(
          'Будут удалены все переписки с ассистентом, включая текущую. '
          'Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ThemeColors.dangerZone,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить все'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _controller.deleteAllThreads();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppearanceController>().primaryColor;

    return Container(
      height: 520,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: 12,
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'История переписок',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await _controller.startNewThread();
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Новый'),
                  style: TextButton.styleFrom(foregroundColor: accent),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<ArchivedThread>>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final threads = snapshot.data!;
                  if (threads.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Нет прошлых переписок.\nЗдесь появятся диалоги, '
                          'в которые можно вернуться и продолжить.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: threads.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final thread = threads[index];
                      final firstUserMsg = thread.messages
                          .where((m) => m.role == 'user')
                          .map((m) => m.content)
                          .firstOrNull;
                      final preview =
                          firstUserMsg ?? thread.messages.first.content;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: accent.withAlpha(30),
                          child: Icon(
                            Icons.forum_outlined,
                            color: accent,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          _formatDate(thread.date),
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: ThemeColors.dangerZone,
                            size: 20,
                          ),
                          tooltip: 'Удалить чат',
                          onPressed: () => _deleteThread(thread),
                        ),
                        onTap: () async {
                          await _controller.switchToThread(thread.boxName);
                          if (context.mounted) Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
              ),
            ),

            // ── Удалить все ───────────────────────────────────────────────
            FutureBuilder<List<ArchivedThread>>(
              future: _future,
              builder: (context, snapshot) {
                final hasThreads = (snapshot.data?.isNotEmpty ?? false);
                if (!hasThreads) return const SizedBox.shrink();
                return Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: _deleteAll,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: const Text('Удалить все чаты'),
                    style: TextButton.styleFrom(
                      foregroundColor: ThemeColors.dangerZone,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Attachment picker sheet
// ──────────────────────────────────────────────────────────

class _AttachmentPickerSheet extends StatefulWidget {
  final AIChatController controller;
  const _AttachmentPickerSheet({required this.controller});

  @override
  State<_AttachmentPickerSheet> createState() => _AttachmentPickerSheetState();
}

class _AttachmentPickerSheetState extends State<_AttachmentPickerSheet> {
  List<Event> _events = [];
  bool _loadingEvents = true;

  Pet? get _pet => widget.controller.pet;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final pet = _pet;
    if (pet == null) {
      setState(() => _loadingEvents = false);
      return;
    }
    final all = await EventService().loadEvents(pet.id);
    all.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    if (mounted) {
      setState(() {
        _events = all.take(15).toList();
        _loadingEvents = false;
      });
    }
  }

  void _pick(ChatAttachment a) {
    widget.controller.setAttachment(a);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppearanceController>().primaryColor;
    final pet = _pet;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: ThemeColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.watch<AppearanceController>().secondaryColor.withAlpha(120),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Прикрепить к диалогу',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Expanded(
                child: pet == null
                    ? const Center(child: Text('Нет данных питомца'))
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          // ── Препараты ───────────────────────────────────
                          if (pet.pillReminders.isNotEmpty) ...[
                            _SectionLabel('Препараты'),
                            ...pet.pillReminders.map(
                              (p) => _PickRow(
                                icon: p.kind?.icon ?? Icons.medication_outlined,
                                color: p.color != null
                                    ? Color(p.color!)
                                    : accent,
                                title: p.name,
                                subtitle: p.doseLabel,
                                onTap: () => _pick(
                                  ChatAttachment(
                                    type: 'pill',
                                    label: p.name,
                                    icon:
                                        p.kind?.icon ??
                                        Icons.medication_outlined,
                                    color: p.color != null
                                        ? Color(p.color!)
                                        : accent,
                                    data: p.toJson(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // ── Прививки и обработки ─────────────────────────
                          if (pet.treatmentHistory.entries.isNotEmpty) ...[
                            _SectionLabel('Прививки и обработки'),
                            ...pet.treatmentHistory.entries.map(
                              (t) => _PickRow(
                                icon: t.kind.icon,
                                color: t.displayColor,
                                title: t.displayName,
                                subtitle:
                                    'Следующее: ${DateFormat('d MMM yyyy', 'ru').format(t.nextDate)}',
                                onTap: () => _pick(
                                  ChatAttachment(
                                    type: 'treatment',
                                    label: t.displayName,
                                    icon: t.kind.icon,
                                    color: t.displayColor,
                                    data: t.toJson(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // ── Заметки ──────────────────────────────────────
                          if (pet.noteHistory.entries.isNotEmpty) ...[
                            _SectionLabel('Заметки'),
                            ...pet.noteHistory.entries.reversed
                                .take(10)
                                .map(
                                  (n) => _PickRow(
                                    icon:
                                        n.symptomTag?.icon ??
                                        Icons.event_note_outlined,
                                    color: n.symptomTag?.color ?? accent,
                                    title: n.note,
                                    subtitle: DateFormat(
                                      'd MMM yyyy, HH:mm',
                                      'ru',
                                    ).format(n.date),
                                    onTap: () => _pick(
                                      ChatAttachment(
                                        type: 'note',
                                        label: n.note,
                                        icon:
                                            n.symptomTag?.icon ??
                                            Icons.event_note_outlined,
                                        color: n.symptomTag?.color ?? accent,
                                        data: n.toJson(),
                                      ),
                                    ),
                                  ),
                                ),
                            const SizedBox(height: 12),
                          ],

                          // ── События ──────────────────────────────────────
                          _SectionLabel('События'),
                          if (_loadingEvents)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            )
                          else if (_events.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Событий пока нет',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            )
                          else
                            ..._events.map(
                              (e) => _PickRow(
                                icon: e.style.icon,
                                color: e.style.color ?? accent,
                                title: e.name,
                                subtitle: DateFormat(
                                  'd MMM yyyy',
                                  'ru',
                                ).format(e.dateTime),
                                onTap: () => _pick(
                                  ChatAttachment(
                                    type: 'event',
                                    label: e.name,
                                    icon: e.style.icon,
                                    color: e.style.color ?? accent,
                                    data: e.toJson(),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6, top: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.watch<AppearanceController>().secondaryColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PickRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassPlate(
        padding: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withAlpha(28),
                    border: Border.all(color: color.withAlpha(70), width: 1.2),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.add_circle_outline,
                  color: context.watch<AppearanceController>().secondaryColor,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
