import 'package:flutter/material.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class NoteDraggableSheet extends StatefulWidget {
  final PetProfile profile;

  const NoteDraggableSheet({super.key, required this.profile});

  @override
  State<NoteDraggableSheet> createState() => _NoteDraggableSheet();
}

class _NoteDraggableSheet extends State<NoteDraggableSheet> {
  final TextEditingController _controller = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  Future<void> _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              _controller.text = result.recognizedWords;
              _controller.selection = TextSelection.fromPosition(
                TextPosition(offset: _controller.text.length),
              );
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableSheet(
      title: "Быстрая заметка",
      centerTitle: true,
      body: Column(
        children: [
          SizedBox(
            height: 250,
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                hintText: 'Напишите заметку...',
                border: InputBorder.none,
              ),
            )
          ),
          Center(
            child: IconButton(
              style: IconButton.styleFrom(backgroundColor: ThemeColors.border, foregroundColor: ThemeColors.white),
              onPressed: _toggleListening,
              icon: Icon(_isListening ? Icons.mic : Icons.mic_none, size: 32),
            ),
          ),
        ],
      ),
    );
  }
}
