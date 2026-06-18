import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Кнопка голосового ввода с записью «по удержанию»: распознавание идёт, пока
/// кнопку держат нажатой, и прекращается при отпускании (как в мессенджерах).
///
/// Распознанный текст отдаётся через [onText] по мере речи. [onStart]
/// вызывается в момент начала записи (например, чтобы запомнить базовый текст
/// поля). Виджет сам инициализирует и освобождает движок распознавания и
/// показывает недоступное состояние, если речь не поддерживается.
class HoldToTalkMic extends StatefulWidget {
  final ValueChanged<String> onText;
  final VoidCallback? onStart;
  final VoidCallback? onStop;

  final Color activeColor;
  final Color idleColor;
  final double size;

  const HoldToTalkMic({
    super.key,
    required this.onText,
    required this.activeColor,
    required this.idleColor,
    this.onStart,
    this.onStop,
    this.size = 26,
  });

  @override
  State<HoldToTalkMic> createState() => _HoldToTalkMicState();
}

class _HoldToTalkMicState extends State<HoldToTalkMic> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ok = await _speech.initialize(
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
        onStatus: (status) {
          if (mounted && (status == 'done' || status == 'notListening')) {
            setState(() => _listening = false);
          }
        },
      );
      if (mounted) setState(() => _available = ok);
    } catch (_) {
      // Распознавание речи может быть недоступно — тихо отключаем кнопку.
      if (mounted) setState(() => _available = false);
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (!_available || _listening) return;
    widget.onStart?.call();
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) => widget.onText(result.recognizedWords),
      localeId: 'ru_RU',
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 10),
    );
  }

  Future<void> _stop() async {
    if (!_listening) return;
    await _speech.stop();
    widget.onStop?.call();
    if (mounted) setState(() => _listening = false);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _available;
    final diameter = widget.size + 18;

    return Listener(
      onPointerDown: enabled ? (_) => _start() : null,
      onPointerUp: enabled ? (_) => _stop() : null,
      onPointerCancel: enabled ? (_) => _stop() : null,
      child: Tooltip(
        message: enabled
            ? (_listening ? 'Отпустите, чтобы остановить' : 'Удерживайте для записи')
            : 'Голосовой ввод недоступен',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _listening
                ? widget.activeColor
                : widget.idleColor.withAlpha(40),
          ),
          child: Icon(
            _listening ? Icons.mic : Icons.mic_none,
            size: widget.size,
            color: _listening
                ? Colors.white
                : enabled
                ? widget.idleColor
                : widget.idleColor.withAlpha(90),
          ),
        ),
      ),
    );
  }
}
