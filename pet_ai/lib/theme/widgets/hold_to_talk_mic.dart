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
  String? _unavailableReason;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ok = await _speech.initialize(
        options: [
          // На сборках без сервиса распознавания по умолчанию (GrapheneOS и
          // прочие Android без сервисов Google) Settings.Secure
          // .voice_recognition_service пуст, и привязка к дефолтному
          // распознавателю не срабатывает. С этой опцией плагин ищет любой
          // установленный RecognitionService и подключается к нему явно.
          stt.SpeechToText.androidIntentLookup,
          // Плагин трогает getBondedDevices() в ходе инициализации, что на
          // Android 12+ требует BLUETOOTH_CONNECT. Разрешение не заявлено, и
          // без этой опции инициализация падает с SecurityException.
          stt.SpeechToText.androidNoBluetooth,
        ],
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _listening = false;
            if (!_available) _unavailableReason = error.errorMsg;
          });
        },
        onStatus: (status) {
          if (mounted && (status == 'done' || status == 'notListening')) {
            setState(() => _listening = false);
          }
        },
      );
      if (mounted) {
        setState(() {
          _available = ok;
          if (!ok) _unavailableReason ??= 'сервис распознавания речи не найден';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _available = false;
          _unavailableReason = e.toString();
        });
      }
    }
  }

  /// Кнопка в недоступном состоянии остаётся нажимаемой: молчаливо неактивный
  /// микрофон неотличим от сломанного, а причина видна только в logcat.
  void _explainUnavailable() {
    final reason = _unavailableReason ?? 'причина неизвестна';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Голосовой ввод недоступен: $reason. Установите приложение '
          'распознавания речи и назначьте его в настройках системы.',
        ),
        duration: const Duration(seconds: 6),
      ),
    );
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
      onPointerDown: enabled ? (_) => _start() : (_) => _explainUnavailable(),
      onPointerUp: enabled ? (_) => _stop() : null,
      onPointerCancel: enabled ? (_) => _stop() : null,
      child: Tooltip(
        message: enabled
            ? (_listening ? 'Отпустите, чтобы остановить' : 'Удерживайте для записи')
            : 'Голосовой ввод недоступен: ${_unavailableReason ?? 'причина неизвестна'}',
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
