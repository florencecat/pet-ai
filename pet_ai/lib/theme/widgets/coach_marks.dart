import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/app_text_styles.dart';
import 'package:pet_satellite/theme/widgets/floating_navigation_bar.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/pressable.dart';
import 'package:provider/provider.dart';

/// Шаг обучения: какой виджет подсветить и что про него рассказать.
class CoachMarkStep {
  /// Ключ подсвечиваемого виджета — по нему берём его положение на экране.
  final GlobalKey targetKey;

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  /// Скругление выреза — по умолчанию как у [GlassPlate].
  final double radius;

  /// На сколько вырез шире самого виджета.
  final double inflate;

  const CoachMarkStep({
    required this.targetKey,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    this.radius = 24,
    this.inflate = 6,
  });
}

/// Показывает обучение поверх текущего экрана и завершается, когда пользователь
/// прошёл все шаги или нажал «Пропустить».
///
/// Живёт в корневом [Overlay], а не в дереве страницы: затемнение должно
/// накрывать в том числе плавающую навигацию, а сама страница — остаться живой
/// под ним (её виджеты видно сквозь вырез).
Future<void> showCoachMarks(
  BuildContext context, {
  required List<CoachMarkStep> steps,
}) {
  if (steps.isEmpty) return Future.value();

  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<void>();
  late final OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) => _CoachMarks(
      steps: steps,
      onFinish: () {
        entry.remove();
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );

  overlay.insert(entry);
  return completer.future;
}

class _CoachMarks extends StatefulWidget {
  final List<CoachMarkStep> steps;
  final VoidCallback onFinish;

  const _CoachMarks({required this.steps, required this.onFinish});

  @override
  State<_CoachMarks> createState() => _CoachMarksState();
}

class _CoachMarksState extends State<_CoachMarks>
    with TickerProviderStateMixin {
  /// Появление/исчезновение всего слоя.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  late final CurvedAnimation _fadeCurve = CurvedAnimation(
    parent: _fade,
    curve: Curves.easeOut,
  );

  /// Переезд выреза от прошлого шага к текущему.
  late final AnimationController _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );

  /// Ключ карточки-подсказки — по нему считаем свободную область экрана, чтобы
  /// не подсвечивать виджет, который карточка сама же и закрывает.
  final _cardKey = GlobalKey();

  /// Список, в котором живут цели. Запоминаем с первого найденного шага: он
  /// нужен, чтобы доводить до целей, которые ленивый список ещё не построил.
  ScrollableState? _scrollable;

  int _index = 0;
  RRect? _from;
  RRect? _to;
  bool _cardOnTop = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _fade.forward();
    // Первый кадр нужен, чтобы измерить карточку-подсказку и цель.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusStep());
  }

  @override
  void dispose() {
    _fadeCurve.dispose();
    _fade.dispose();
    _move.dispose();
    super.dispose();
  }

  // ── Позиционирование выреза ─────────────────────────────────────────────────

  static Rect? _rectOf(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  double get _safeTop => MediaQuery.paddingOf(context).top + 16;

  double get _safeBottom =>
      MediaQuery.paddingOf(context).bottom + FloatingNavigationBar.bottomInset;

  /// Куда карточка-подсказка встанет при заданном значении [onTop]. Считаем от
  /// её размера, а не от текущего положения: иначе выбор места зависел бы от
  /// того, куда её увёл прошлый шаг.
  Rect? _cardSlot({required bool onTop}) {
    final cardContext = _cardKey.currentContext;
    if (cardContext == null) return null;
    final card = _rectOf(cardContext);
    if (card == null) return null;

    final screen = MediaQuery.sizeOf(context);
    return Rect.fromLTWH(
      card.left,
      onTop ? _safeTop : screen.height - _safeBottom - card.height,
      card.width,
      card.height,
    );
  }

  /// Область экрана между системной зоной сверху и карточкой-подсказкой снизу.
  Rect? _freeArea() {
    final card = _cardSlot(onTop: false);
    if (card == null) return null;

    return Rect.fromLTRB(
      0,
      MediaQuery.paddingOf(context).top,
      MediaQuery.sizeOf(context).width,
      card.top - 16,
    );
  }

  /// Карточка-подсказка не должна закрывать подсветку. Обычно она внизу, как в
  /// макете, но если увести цель прокруткой не вышло (короткая страница,
  /// закреплённый заголовок) — уводим наверх саму карточку.
  bool _cardShouldGoUp(Rect target) {
    final probe = target.inflate(16);
    final atBottom = _cardSlot(onTop: false);
    if (atBottom == null || !probe.overlaps(atBottom)) return false;

    final atTop = _cardSlot(onTop: true);
    // Наверху мешает не меньше — оставляем внизу, как в макете.
    return atTop != null && !probe.overlaps(atTop);
  }

  /// Прокрутка завершается на последнем тике анимации, а раскладка с итоговым
  /// смещением приезжает только следующим кадром — измерять цель можно после.
  static Future<void> _settled() => SchedulerBinding.instance.endOfFrame;

  /// Ищет цель шага, даже если ленивый список ещё не построил её.
  ///
  /// Такую цель нельзя показать через [Scrollable.ensureVisible] — у неё просто
  /// нет контекста, — поэтому проматываем список с начала, пока она не
  /// появится. Цели в закреплённом заголовке живут вне списка и находятся сразу.
  Future<BuildContext?> _resolveTarget(GlobalKey key) async {
    if (key.currentContext != null) return key.currentContext;

    final position = _scrollable?.position;
    if (position == null || !position.hasContentDimensions) return null;

    Future<void> scrollTo(double offset) async {
      await position.animateTo(
        offset.clamp(0.0, position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
      await _settled();
    }

    // С начала — иначе цель выше текущей позиции осталась бы ненайденной.
    await scrollTo(0);
    while (mounted &&
        key.currentContext == null &&
        position.pixels < position.maxScrollExtent) {
      await scrollTo(position.pixels + position.viewportDimension * 0.8);
    }
    return mounted ? key.currentContext : null;
  }

  /// Подводит вырез к цели текущего шага, подкручивая список, если цель уехала
  /// за пределы свободной области.
  Future<void> _focusStep() async {
    final step = widget.steps[_index];
    final targetContext = await _resolveTarget(step.targetKey);
    if (!mounted) return;
    if (targetContext == null || !targetContext.mounted) {
      // Экран перестроился и цели больше нет — обучение теряет смысл.
      _finish();
      return;
    }
    _scrollable ??= Scrollable.maybeOf(targetContext);

    var rect = _rectOf(targetContext);
    final free = _freeArea();
    if (rect != null &&
        free != null &&
        (rect.top < free.top || rect.bottom > free.bottom)) {
      await Scrollable.ensureVisible(
        targetContext,
        alignment: 0.15,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      await _settled();
      if (!mounted) return;
      // Пока крутился список, цель могла перестроиться — берём её заново.
      final settled = step.targetKey.currentContext;
      rect = settled != null && settled.mounted ? _rectOf(settled) : null;
    }

    if (rect == null) {
      _finish();
      return;
    }

    final hole = RRect.fromRectAndRadius(
      rect.inflate(step.inflate),
      Radius.circular(step.radius + step.inflate),
    );

    setState(() {
      // Первый шаг просто проявляется вместе со слоем, дальше — переезжает.
      _from = _to ?? hole;
      _to = hole;
      _cardOnTop = _cardShouldGoUp(rect!);
    });
    _move.forward(from: 0);
  }

  // ── Навигация по шагам ──────────────────────────────────────────────────────

  void _next() {
    triggerHaptic(HapticStrength.light);
    if (_index >= widget.steps.length - 1) {
      _finish();
      return;
    }
    setState(() => _index++);
    _focusStep();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    await _fade.reverse();
    widget.onFinish();
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final primary = context.watch<AppearanceController>().primaryColor;

    return FadeTransition(
      opacity: _fadeCurve,
      child: Stack(
        children: [
          // Полноэкранный «перехватчик»: пока идёт обучение, страница под слоем
          // не должна реагировать на касания — подсвеченный виджет видно, но
          // нажать на него нельзя.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: AnimatedBuilder(
                animation: _move,
                builder: (context, _) => CustomPaint(
                  painter: _ScrimPainter(
                    hole: RRect.lerp(
                      _from,
                      _to,
                      Curves.easeInOutCubic.transform(_move.value),
                    ),
                    glow: primary,
                  ),
                ),
              ),
            ),
          ),
          AnimatedAlign(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            alignment: _cardOnTop
                ? Alignment.topCenter
                : Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, _safeTop, 16, _safeBottom),
              child: SizedBox(
                width: double.infinity,
                child: _buildCard(context, primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, Color primary) {
    final step = widget.steps[_index];
    final isLast = _index == widget.steps.length - 1;

    return GlassPlate(
      key: _cardKey,
      transparent: false,
      padding: 16,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
        alignment: _cardOnTop ? Alignment.topCenter : Alignment.bottomCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Column(
            key: ValueKey(_index),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SoftRoundedIcon(icon: step.icon, color: step.iconColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_index + 1} / ${widget.steps.length}',
                    style: context.subtitleStyle,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(step.description, style: context.subtitleMediumStyle),
              const SizedBox(height: 16),
              Row(
                children: [
                  _StepDots(
                    count: widget.steps.length,
                    index: _index,
                    color: primary,
                  ),
                  const SizedBox(width: 12),
                  // Кнопки прижаты вправо и при нехватке места ужимают
                  // «Пропустить» — на много шагов и крупном шрифте строка
                  // иначе не влезает.
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: TextButton(
                            onPressed: _finish,
                            child: Text(
                              'Пропустить',
                              style: context.subtitleStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        FilledButton(
                          onPressed: _next,
                          style: FilledButton.styleFrom(
                            backgroundColor: primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          child: Text(isLast ? 'Понятно' : 'Далее'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Индикатор шагов: активная точка вытягивается в «таблетку».
class _StepDots extends StatelessWidget {
  final int count;
  final int index;
  final Color color;

  const _StepDots({
    required this.count,
    required this.index,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(right: 5),
          width: active ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: active ? color : color.withAlpha(72),
          ),
        );
      }),
    );
  }
}

/// Затемнение с вырезом под подсвеченный виджет: свечение и светлое кольцо
/// рисуем строго снаружи выреза, чтобы сам виджет остался «чистым».
class _ScrimPainter extends CustomPainter {
  final RRect? hole;
  final Color glow;

  const _ScrimPainter({required this.hole, required this.glow});

  static const _scrim = Color(0xFF1E143A);

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final scrimPaint = Paint()..color = _scrim.withAlpha(140);

    final hole = this.hole;
    if (hole == null) {
      canvas.drawPath(full, scrimPaint);
      return;
    }

    final outside = Path.combine(
      PathOperation.difference,
      full,
      Path()..addRRect(hole),
    );

    canvas.save();
    canvas.clipPath(outside);
    canvas.drawPath(outside, scrimPaint);
    canvas.drawRRect(
      hole.inflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = glow.withAlpha(120)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawRRect(
      hole.inflate(2.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withAlpha(230),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScrimPainter oldDelegate) =>
      oldDelegate.hole != hole || oldDelegate.glow != glow;
}
