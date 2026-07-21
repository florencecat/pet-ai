import 'package:flutter/material.dart';
import 'package:pet_satellite/models/walk.dart';
import 'package:pet_satellite/theme/app_text_styles.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';

/// Столбчатый график минут прогулок за период — «в 3 цвета», как на макете 2a.
///
///  • выделенный столбик (сегодня / текущий период) — насыщенный зелёный;
///  • «слабый» день (заметно ниже среднего, но не пустой) — персиковый;
///  • остальные — светло-зелёный.
class WalkChart extends StatelessWidget {
  final List<WalkBucket> buckets;

  /// Средние минуты в день для подписи под графиком.
  final int averagePerDay;

  const WalkChart({
    super.key,
    required this.buckets,
    required this.averagePerDay,
  });

  // Палитра графика (совпадает с макетом).
  static const _strong = Color(0xFF3FAE8F); // выделенный
  static const _normal = Color(0xFFCBE9DF); // обычный
  static const _low = Color(0xFFF3D9C9); // слабый день

  Color _barColor(WalkBucket b, int maxMinutes, double avg) {
    if (b.highlight && b.minutes > 0) return _strong;
    if (b.minutes == maxMinutes && maxMinutes > 0) return _strong;
    if (b.minutes > 0 && avg > 0 && b.minutes < avg * 0.5) return _low;
    return _normal;
  }

  @override
  Widget build(BuildContext context) {
    final maxMinutes = buckets.fold<int>(0, (m, b) => b.minutes > m ? b.minutes : m);
    final avg = averagePerDay.toDouble();

    return GlassPlate(
      useShadow: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 110,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final b in buckets)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.5),
                        child: _Bar(
                          bucket: b,
                          fraction: maxMinutes == 0
                              ? 0
                              : b.minutes / maxMinutes,
                          color: _barColor(b, maxMinutes, avg),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              averagePerDay > 0
                  ? 'Минуты прогулок · в среднем $averagePerDay мин/день'
                  : 'Минуты прогулок за период',
              textAlign: TextAlign.center,
              style: context.subtitleStyle,
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final WalkBucket bucket;
  final double fraction; // 0..1 относительно максимума
  final Color color;

  const _Bar({
    required this.bucket,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Минимальная видимая высота, чтобы пустые дни не «схлопывались» в ноль.
    final heightFactor = (0.06 + fraction * 0.94).clamp(0.06, 1.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: FractionallySizedBox(
            alignment: Alignment.bottomCenter,
            heightFactor: heightFactor,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: bucket.minutes == 0 ? color.withAlpha(90) : color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          bucket.label,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: context.subtitleStyle.copyWith(
            fontSize: 10.5,
            fontWeight: bucket.highlight ? FontWeight.w800 : FontWeight.w700,
            color: bucket.highlight
                ? context.titleColor
                : context.subtitleColor,
          ),
        ),
      ],
    );
  }
}
