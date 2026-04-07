import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pet_ai/services/ai_service.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/widgets/activity_indicator.dart';
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
    return FutureBuilder<AIChatController>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(body: InlineLoading(isLoading: !snapshot.hasData));
        }

        return ChangeNotifierProvider.value(
          value: snapshot.data!,
          child: Builder(
            builder: (context) {
              return Scaffold(
                appBar: AppBar(
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.history),
                      onPressed: () {
                        final controller = context.read<AIChatController>();

                        _openHistorySheet(context, controller);
                      },
                    ),
                  ],
                ),
                body: const _ChatView(),
              );
            },
          ),
        );
      },
    );
  }

  void _openHistorySheet(BuildContext context, AIChatController controller) {
    showModalBottomSheet(
      context: context, // ✅ теперь правильный context
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _HistorySheet(controller: controller);
      },
    );
  }
}

class _ChatView extends StatelessWidget {
  const _ChatView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AIChatController>();

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.only(top: 12),
                itemCount: controller.messages.length,
                itemBuilder: (context, index) {
                  final msg = controller.messages.reversed.toList()[index];

                  return _MessageBubble(msg: msg);
                },
              ),
            ),
            const _InputBar(),
          ],
        ),

        if (controller.isLoading)
          Positioned(bottom: 90, left: 16, child: _TypingIndicator()),
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
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isUser ? ThemeColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
        ),
        child: Text(
          msg.content,
          style: TextStyle(color: isUser ? Colors.white : Colors.black87),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),

      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Спросите о питомце...',
                filled: true,
                fillColor: ThemeColors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none
                ),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: controller.text.isEmpty
                ? null
                : () {
                    chat.sendMessage(controller.text);
                    controller.clear();
                  },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: BoxBorder.all(
                  color: controller.text.isEmpty
                      ? Colors.grey.shade400
                      : ThemeColors.primary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.send,
                color: controller.text.isEmpty
                    ? Colors.grey.shade400
                    : ThemeColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: const Text('Печатает...'),
    );
  }
}

class _HistorySheet extends StatelessWidget {
  final AIChatController controller;

  const _HistorySheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: DraggableBottomSheet(
            hintText: 'Поиск...',
            leadingIcon: Icons.history,
            scrollController: scrollController,
            allItems: controller.messages.map((msg) {
              final prefix = msg.role == "user" ? "Вы: " : "Чат-бот: ";
              return prefix + msg.content;
            }).toList(),
          ),
        );
      },
    );
  }
}
