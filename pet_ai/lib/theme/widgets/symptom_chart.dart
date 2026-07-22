import 'package:flutter/material.dart';
import 'package:pet_satellite/models/note.dart';
import 'package:pet_satellite/theme/app_text_styles.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';

/// График динамики тяжести симптома по дням/месяцам — «в 3 цвета», как на
/// макете 2e. Пустые интервалы (без записей) остаются незакрашенными, столбик
/// с записью красится и растёт по тяжести (лёгкий→средний→сильный).
class SymptomChart extends StatelessWidget {
  final List<SymptomBar> bars;

  /// Подписи под всей шкалой слева/справа (для дневного вида: «4 июня» …
  /// «сегодня»). Если у столбиков есть собственные [SymptomBar.label]
  /// (помесячный вид) — эти подписи не показываем.
  final String? startLabel;
  final String? endLabel;

  const SymptomChart({
    super.key,
    required this.bars,
    this.startLabel,
    this.endLabel,
  });

  bool get _hasBarLabels => bars.any((b) => b.label != null);

  @override
  Widget build(BuildContext context) {
    return GlassPlate(
      useShadow: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 92,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final b in bars)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.5),
                        child: _Bar(bar: b, showLabel: _hasBarLabels),
                      ),
                    ),
                ],
              ),
            ),

            // ── Подпись диапазона (дневной вид) ────────────────────────────────
            if (!_hasBarLabels && (startLabel != null || endLabel != null)) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: context.subtitleColor.withAlpha(40)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      startLabel ?? '',
                      style: context.subtitleStyle.copyWith(fontSize: 10.5),
                    ),
                    Text(
                      endLabel ?? '',
                      style: context.subtitleStyle.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // ── Легенда тяжести ────────────────────────────────────────────────
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                for (final s in SymptomSeverity.values) _LegendDot(severity: s),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final SymptomBar bar;
  final bool showLabel;

  const _Bar({required this.bar, required this.showLabel});

  @override
  Widget build(BuildContext context) {
    final severity = bar.severity;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: severity == null
              ? const SizedBox.shrink()
              : FractionallySizedBox(
                  alignment: Alignment.bottomCenter,
                  heightFactor: severity.chartFraction,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: severity.chartColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 5),
          Text(
            bar.label ?? '',
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: context.subtitleStyle.copyWith(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final SymptomSeverity severity;

  const _LegendDot({required this.severity});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: severity.chartColor,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          severity.label,
          style: context.subtitleStyle.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
