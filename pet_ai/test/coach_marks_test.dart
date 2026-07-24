import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/widgets/coach_marks.dart';

/// Обучение подсвечивает виджеты по их ключам: вырез должен встать ровно на
/// цель текущего шага, «Далее» — переводить на следующую, а последний шаг и
/// «Пропустить» — снимать слой.
void main() {
  final vetKey = GlobalKey();
  final filesKey = GlobalKey();

  List<CoachMarkStep> steps() => [
    CoachMarkStep(
      targetKey: vetKey,
      icon: Icons.medical_services_outlined,
      iconColor: Colors.orange,
      title: 'Карточка для ветеринара',
      description: 'Актуальная информация по питомцу в одном месте.',
    ),
    CoachMarkStep(
      targetKey: filesKey,
      icon: Icons.description_outlined,
      iconColor: Colors.brown,
      title: 'Файлы',
      description: 'Анализы, чеки и другие документы.',
    ),
  ];

  /// Экран с двумя целями фиксированного размера — позиции известны заранее.
  Widget host(void Function(BuildContext) onReady) {
    return ChangeNotifierProvider<AppearanceController>(
      create: (_) => AppearanceController(),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                SizedBox(key: vetKey, height: 80, width: 300),
                SizedBox(key: filesKey, height: 80, width: 300),
                TextButton(
                  onPressed: () => onReady(context),
                  child: const Text('go'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Прямоугольник, который слой вырезал в затемнении. Художник затемнения
  /// приватный, поэтому находим его по имени типа.
  RRect? holeOf(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(
      find.byWidgetPredicate(
        (w) =>
            w is CustomPaint &&
            w.painter.runtimeType.toString() == '_ScrimPainter',
      ),
    );
    return (paint.painter as dynamic).hole as RRect?;
  }

  Rect rectOf(GlobalKey key) {
    final box = key.currentContext!.findRenderObject() as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  testWidgets('вырез встаёт на цель шага и переезжает по «Далее»', (
    tester,
  ) async {
    await tester.pumpWidget(
      host((context) => showCoachMarks(context, steps: steps())),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Карточка для ветеринара'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(holeOf(tester)!.outerRect, rectOf(vetKey).inflate(6));

    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();

    expect(find.text('Файлы'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(holeOf(tester)!.outerRect, rectOf(filesKey).inflate(6));

    // Последний шаг закрывает обучение.
    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    expect(find.text('Файлы'), findsNothing);
  });

  testWidgets('«Пропустить» снимает слой на любом шаге', (tester) async {
    await tester.pumpWidget(
      host((context) => showCoachMarks(context, steps: steps())),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Пропустить'));
    await tester.pumpAndSettle();

    expect(find.text('Карточка для ветеринара'), findsNothing);
  });

  testWidgets('доводит до цели, которую ленивый список ещё не построил', (
    tester,
  ) async {
    // Экран здоровья: закреплённый заголовок вне списка + длинные секции, из
    // которых нижняя далеко за пределами вьюпорта.
    final headerKey = GlobalKey();
    final topKey = GlobalKey();
    final farKey = GlobalKey();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppearanceController>(
        create: (_) => AppearanceController(),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  SizedBox(key: headerKey, height: 60, width: 300),
                  TextButton(
                    onPressed: () => showCoachMarks(
                      context,
                      steps: [
                        CoachMarkStep(
                          targetKey: topKey,
                          icon: Icons.dashboard_customize_outlined,
                          iconColor: Colors.purple,
                          title: 'Мои трекеры',
                          description: 'Дашборд здоровья.',
                        ),
                        CoachMarkStep(
                          targetKey: farKey,
                          icon: Icons.healing_outlined,
                          iconColor: Colors.blue,
                          title: 'Препараты',
                          description: 'Курсы лекарств.',
                        ),
                        CoachMarkStep(
                          targetKey: headerKey,
                          icon: Icons.favorite_outline,
                          iconColor: Colors.teal,
                          title: 'Оценка здоровья',
                          description: 'Общий вывод по данным питомца.',
                        ),
                      ],
                    ),
                    child: const Text('go'),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        SizedBox(key: topKey, height: 300),
                        // Целая «простыня» между секциями: нижняя цель заведомо
                        // не построена на старте.
                        for (var i = 0; i < 20; i++) const SizedBox(height: 200),
                        SizedBox(key: farKey, height: 120),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(farKey.currentContext, isNull, reason: 'цель не должна быть готова');

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(holeOf(tester)!.outerRect, rectOf(topKey).inflate(6));

    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    expect(find.text('Препараты'), findsOneWidget);
    expect(holeOf(tester)!.outerRect, rectOf(farKey).inflate(6));

    // Последний шаг — вне списка (закреплённый заголовок), к тому же выше
    // текущей позиции прокрутки.
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    expect(find.text('Оценка здоровья'), findsOneWidget);
    expect(holeOf(tester)!.outerRect, rectOf(headerKey).inflate(6));
  });

  testWidgets('слой перехватывает касания по экрану под ним', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      ChangeNotifierProvider<AppearanceController>(
        create: (_) => AppearanceController(),
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  SizedBox(
                    key: vetKey,
                    height: 80,
                    width: 300,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => tapped = true,
                    ),
                  ),
                  SizedBox(key: filesKey, height: 80, width: 300),
                  TextButton(
                    onPressed: () => showCoachMarks(context, steps: steps()),
                    child: const Text('go'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    // Подсвеченный виджет видно сквозь вырез, но нажать на него нельзя.
    await tester.tapAt(rectOf(vetKey).center);
    await tester.pumpAndSettle();
    expect(tapped, isFalse);
  });
}
