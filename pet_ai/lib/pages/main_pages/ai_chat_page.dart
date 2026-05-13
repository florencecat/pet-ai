import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pet_ai/services/ai_service.dart';
import 'package:pet_ai/services/appearance_controller.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/widgets/activity_indicator.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';
import 'package:provider/provider.dart';
import '../../theme/widgets/draggable_bottom_sheet.dart';

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

    final service = GigaChatService(
      authService: AuthService(authorizationKey: dotenv.env["GIGACHAT_KEY"]!),
    );

    _future = _createController(service);
  }

  Future<AIChatController> _createController(GigaChatService service) async {
    final controller = AIChatController(service: service);
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

class _ChatView extends StatelessWidget {
  const _ChatView();

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
    final controller = context.watch<AIChatController>();

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                clipBehavior: Clip.none,
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 185),
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

        const _GlobalEdgeBlur(),

        Padding(
          padding: EdgeInsetsGeometry.only(left: 16, right: 16),
          child: Align(
            alignment: AlignmentGeometry.topCenter,
            child: GlassCard(
              callback: () {
                final controller = context.read<AIChatController>();
                _openHistorySheet(context, controller);
              },
              transparent: false,
              child: ListTile(
                leading: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadiusGeometry.circular(12),
                    gradient: LinearGradient(
                      colors: ThemeColors.aiChatIconGradient,
                      begin: AlignmentGeometry.topLeft,
                      end: AlignmentGeometry.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsetsGeometry.all(12),
                    child: Icon(Icons.chat, color: Colors.white),
                  ),
                ),
                title: Text(
                  'Помощник по уходу',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                subtitle: Row(
                  spacing: 6,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: BoxBorder.all(
                          color: ThemeColors.aiChatOnlineColor.withAlpha(128),
                          width: 4,
                        ),
                        shape: BoxShape.circle,
                        color: ThemeColors.aiChatOnlineColor,
                      ),
                      width: 8,
                      height: 8,
                    ),
                    Text(
                      'на связи • знает всё про Барни',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: ThemeColors.aiChatOnlineColor,
                      ),
                    ),
                  ],
                ),
                trailing: Icon(
                  Icons.history,
                  color: context.watch<AppearanceController>().primaryColor,
                ),
              ),
            ),
          ),
        ),

        const Align(
          alignment: AlignmentGeometry.bottomCenter,
          child: Padding(
            padding: EdgeInsetsGeometry.only(bottom: 90),
            child: _InputBar(),
          ),
        ),

        if (controller.isLoading)
          Positioned(
            bottom: 191,
            left: 16,
            child: GlassPlate(
              child: Padding(
                padding: EdgeInsetsGeometry.symmetric(
                  vertical: 8,
                  horizontal: 14,
                ),
                child: Text('Печатает...'),
              ),
            ),
          ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;

  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        constraints: const BoxConstraints(maxWidth: 300),
        child: GlassPlate(
          color: isUser
              ? context.watch<AppearanceController>().primaryColor
              : Colors.white,
          child: Padding(
            padding: EdgeInsetsGeometry.symmetric(vertical: 8, horizontal: 14),
            child: Text(
              msg.content,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                inherit: true,
                color: isUser ? ThemeColors.white : ThemeColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatefulWidget {
  const _InputBar();

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final chat = context.read<AIChatController>();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: GlassPlate(
              child: TextField(
                controller: controller,
                maxLines: 3,
                minLines: 1,

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
            callback: controller.text.isEmpty
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    chat.sendMessage(controller.text);
                    controller.clear();
                  },
            child: Padding(
              padding: EdgeInsetsGeometry.all(10),
              child: Icon(
                Icons.send,
                color: controller.text.isEmpty
                    ? Colors.grey.shade400
                    : context.watch<AppearanceController>().primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySheet extends StatelessWidget {
  final AIChatController controller;

  const _HistorySheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 500,
      child: DraggableBottomSheet(
        hintText: 'Поиск...',
        leadingIcon: Icons.history,
        allItems: controller.messages.map((msg) {
          final prefix = msg.role == "user" ? "Вы: " : "Чат-бот: ";
          return prefix + msg.content;
        }).toList(),
      ),
    );
  }
}

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
              child: Container(height: 120, decoration: BoxDecoration()),
            ),
          ),

          const Spacer(),

          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaY: 1, sigmaX: 1),
              child: Container(height: 140, decoration: BoxDecoration()),
            ),
          ),
        ],
      ),
    );
  }
}
