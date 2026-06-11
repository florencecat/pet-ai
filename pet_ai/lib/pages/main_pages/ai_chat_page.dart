import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:pet_satellite/services/ai_service.dart';
import 'package:pet_satellite/services/api_service.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/activity_indicator.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
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
    final topPadding = MediaQuery.of(context).padding.top;

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
                resizeToAvoidBottomInset: false,
                body: Container(
                  padding: EdgeInsets.fromLTRB(0, topPadding + 16, 0, 0),
                  decoration: context
                      .watch<AppearanceController>()
                      .gradientDecoration,
                  child: const _ChatView(),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

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
    // Fixed-size SizedBox so the Row layout never shifts during animation.
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
    // context.read — не регистрирует подписку; подходит для initState.
    // context.watch нельзя использовать вне build() — вызывает ошибку
    // деактивации InheritedElement и, как следствие, краш Scaffold layout.
    _controller = context.read<AIChatController>();
    _future = _controller.healthCheck();
    // Периодически перепроверяем доступность бота, чтобы статус был реальным.
    _healthTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _future = _controller.healthCheck());
    });
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    super.dispose();
  }

  void _openHistorySheet(BuildContext context, AIChatController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) {
        return _HistorySheet(controller: controller);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch for reactive rebuilds when messages arrive or isLoading changes.
    // _controller (set in initState via context.read) is only used for
    // healthCheck(); all live state is read from the watched instance here.
    final controller = context.watch<AIChatController>();
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    final isEmpty = controller.messages.isEmpty;

    return Stack(
      children: [
        // Тап по области сообщений скрывает клавиатуру.
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: isEmpty
                    ? Column(
                        children: [
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 4,
                              right: 4,
                              bottom: 185,
                            ),
                            child: _WelcomeState(petName: controller.petName),
                          ),
                        ],
                      )
                    : ListView.builder(
                        reverse: true,
                        clipBehavior: Clip.none,
                        padding: const EdgeInsets.only(
                          left: 4,
                          right: 4,
                          bottom: 185,
                          top: 108,
                        ),
                        itemCount: controller.messages.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final msg = controller
                              .messages[controller.messages.length - 1 - index];
                          return _MessageBubble(msg: msg);
                        },
                      ),
              ),
            ],
          ),
        ),

        const _GlobalEdgeBlur(),

        // Header card
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: Align(
            alignment: Alignment.topCenter,
            child: GlassCard(
              callback: () {
                _openHistorySheet(context, controller);
              },
              transparent: false,
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
                  future: _future,
                  builder: (context, snapshot) {
                    // Состояние проверки — пока первый запрос не завершился.
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return Row(
                        spacing: 6,
                        children: [
                          _OfflineDot(),
                          Text(
                            'проверка связи…',
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(color: Colors.grey),
                          ),
                        ],
                      );
                    }

                    final online = snapshot.data == true;
                    return Row(
                      spacing: 6,
                      children: online
                          ? [
                              _OnlineDot(
                                color: ThemeColors.aiChatOnlineColor,
                              ),
                              Text(
                                'на связи',
                                style: Theme.of(context).textTheme.bodyMedium!
                                    .copyWith(
                                      color: ThemeColors.aiChatOnlineColor,
                                    ),
                              ),
                            ]
                          : [
                              _OfflineDot(),
                              Text(
                                'оффлайн',
                                style: Theme.of(context).textTheme.bodyMedium!
                                    .copyWith(color: Colors.grey),
                              ),
                            ],
                    );
                  },
                ),
                trailing: Icon(
                  Icons.history,
                  color: context.watch<AppearanceController>().primaryColor,
                ),
              ),
            ),
          ),
        ),

        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: keyboardInset > 0 ? keyboardInset : bottomPadding,
            ),
            child: _InputBar(),
          ),
        ),

        // "Typing..." indicator
        if (controller.isLoading)
          Positioned(
            bottom: 191,
            left: 16,
            child: GlassPlate(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 14,
                ),
                child: const Text('Печатает...'),
              ),
            ),
          ),
      ],
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
      'Сколько корма в день?',
      'Когда прививка?',
      'Норма прогулок',
      'Почему мой питомец вялый?',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bot welcome bubble
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
                    'Привет! Я знаю историю $petName и могу подсказать про корм, прививки или поведение. О чём хочешь узнать?',
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: ThemeColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Quick-reply chips
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
                    style: TextStyle(
                      fontSize: 13,
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
// Shared bubble container with asymmetric border radius
// ──────────────────────────────────────────────────────────

class _BubbleContainer extends StatelessWidget {
  final bool isUser;
  final Widget child;

  const _BubbleContainer({required this.isUser, required this.child});

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

    return Container(
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
      child: child,
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
        color: isUser ? ThemeColors.white : ThemeColors.textPrimary,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
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
          _BubbleContainer(isUser: isUser, child: textWidget),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Input bar
// ──────────────────────────────────────────────────────────

class _InputBar extends StatefulWidget {
  const _InputBar();

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // watch — so the send button disables while the AI is replying.
    final chat = context.watch<AIChatController>();
    final canSend = controller.text.isNotEmpty && !chat.isLoading;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: GlassPlate(
              child: TextField(
                controller: controller,
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Спросите о питомце...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 8),

          GlassCard(
            callback: canSend
                ? () {
                    HapticFeedback.mediumImpact();
                    chat.sendMessage(controller.text);
                    controller.clear();
                    setState(() {});
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(
                Icons.send,
                color: canSend
                    ? context.watch<AppearanceController>().primaryColor
                    : Colors.grey.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// History sheet — shows archived threads
// ──────────────────────────────────────────────────────────

class _HistorySheet extends StatelessWidget {
  final AIChatController controller;

  const _HistorySheet({required this.controller});

  String _formatDate(DateTime date) {
    return DateFormat('d MMMM yyyy', 'ru_RU').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 500,
      child: Padding(
        padding: EdgeInsets.only(
          top: 12,
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
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

            Text(
              'История переписок',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            Expanded(
              child: FutureBuilder<List<ArchivedThread>>(
                future: controller.loadArchivedThreads(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final threads = snapshot.data!;

                  if (threads.isEmpty) {
                    return const Center(
                      child: Text(
                        'Нет архивных переписок.\nКаждый новый день начинается новый тред.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
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
                        leading: Icon(
                          Icons.chat_bubble_outline,
                          color: context
                              .watch<AppearanceController>()
                              .primaryColor,
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
                        trailing: Text(
                          '${thread.messages.length} сообщ.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Edge blur overlay
// ──────────────────────────────────────────────────────────

class _GlobalEdgeBlur extends StatelessWidget {
  const _GlobalEdgeBlur();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        children: [
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaY: 0.5, sigmaX: 0.5),
              child: Container(height: 120, decoration: const BoxDecoration()),
            ),
          ),

          const Spacer(),

          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaY: 1, sigmaX: 1),
              child: Container(height: 140, decoration: const BoxDecoration()),
            ),
          ),
        ],
      ),
    );
  }
}
