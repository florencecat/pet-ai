import 'package:flutter/material.dart';
import 'package:pet_ai/theme/app_colors.dart';

import '../../theme/widgets/draggable_bottom_sheet.dart';

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _controller = TextEditingController();
  String _response = '';
  final List<String> _history = [
    'Как часто нужно чистить уши собаке?',
    'Что делать, если питомец отказывается от еды?',
    'Как понять, что пора к ветеринару?',
  ];

  //void _attachPhoto() {}

  void _sendPrompt() {
    setState(() {
      _response =
          '🤖 Ответ ИИ на запрос: "${_controller.text}".\n\n(В реальном приложении сюда подставится результат модели.)';
      _history.insert(0, _controller.text);
      _controller.clear();
    });
  }

  void _openHistorySheet() {
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent, // 👈 чтобы был виден полупрозрачный фон
      barrierColor: Colors.black54, // 👈 затемнённая подложка
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.6,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: DraggableBottomSheet(
                allItems: _history,
                hintText: 'Поиск вопроса...',
                leadingIcon: Icons.question_answer,
                scrollController: scrollController,
              ),
            );
          },
        );

        // return DraggableScrollableSheet(
        //   expand: false,
        //   initialChildSize: 0.5,
        //   minChildSize: 0.3,
        //   maxChildSize: 0.9,
        //   builder: (context, scrollController) {
        //     return ListView.builder(
        //       controller: scrollController,
        //       itemCount: _history.length,
        //       itemBuilder: (context, index) {
        //         final prompt = _history[index];
        //         return ListTile(
        //           leading: const Icon(Icons.history),
        //           title: Text(prompt),
        //           subtitle: const Text('Ответ ИИ сохранён (заглушка)'),
        //           onTap: () {
        //             Navigator.pop(context);
        //             setState(() {
        //               _response =
        //               '📜 Повтор выбранного запроса:\n\n"$prompt"\n\n(Здесь можно подгрузить сохранённый ответ)';
        //             });
        //           },
        //         );
        //       },
        //     );
        //   },
        // );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'История запросов',
            onPressed: _openHistorySheet,
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Текст в центре
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  child: Text(
                    _response.isEmpty
                        ? 'Задайте вопрос, чтобы получить ответ от ИИ.'
                        : _response,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

            // Поле ввода внизу
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.attach_file,
                        color: ThemeColors.primary,
                      ),
                      onPressed: _sendPrompt,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Введите вопрос об уходе за питомцем',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: ThemeColors.primary,
                      ),
                      onPressed: _sendPrompt,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
