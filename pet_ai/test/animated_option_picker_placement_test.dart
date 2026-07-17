import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/widgets/animated_option_picker.dart';

/// Меню должно раскрываться в ту сторону, где есть место: у нижнего края
/// экрана — вверх, иначе вниз.
void main() {
  Widget host(Alignment where) {
    return ChangeNotifierProvider<AppearanceController>(
      create: (_) => AppearanceController(),
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: where,
            child: AnimatedOptionPicker<int>(
              value: 0,
              options: const [
                PickerOption(value: 0, label: 'o0'),
                PickerOption(value: 1, label: 'o1'),
                PickerOption(value: 2, label: 'o2'),
                PickerOption(value: 3, label: 'o3'),
              ],
              onChanged: (_) {},
              child: const Text('trigger'),
            ),
          ),
        ),
      ),
    );
  }

  /// Клавиатуру поднимаем на уровне view: Scaffold прячет её от MediaQuery
  /// внутри body, так что подмена MediaQuery ничего бы не проверила.
  void showKeyboard(WidgetTester tester, double logicalHeight) {
    tester.view.viewInsets = FakeViewPadding(
      bottom: logicalHeight * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.reset);
  }

  Future<Rect> openAndGetMenuRect(WidgetTester tester) async {
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();
    // Крайние пункты задают вертикальные границы карточки.
    final top = tester.getRect(find.text('o0'));
    final bottom = tester.getRect(find.text('o3'));
    return Rect.fromLTRB(top.left, top.top, bottom.right, bottom.bottom);
  }

  testWidgets('у нижнего края раскрывается вверх', (tester) async {
    await tester.pumpWidget(host(Alignment.bottomCenter));
    final trigger = tester.getRect(find.text('trigger'));
    final menu = await openAndGetMenuRect(tester);

    expect(menu.bottom, lessThanOrEqualTo(trigger.top));
  });

  testWidgets('у верхнего края раскрывается вниз', (tester) async {
    await tester.pumpWidget(host(Alignment.topCenter));
    final trigger = tester.getRect(find.text('trigger'));
    final menu = await openAndGetMenuRect(tester);

    expect(menu.top, greaterThanOrEqualTo(trigger.bottom));
  });

  testWidgets('с открытой клавиатурой раскрывается вверх', (tester) async {
    showKeyboard(tester, 300);
    await tester.pumpWidget(host(Alignment.bottomCenter));
    final trigger = tester.getRect(find.text('trigger'));
    final menu = await openAndGetMenuRect(tester);

    expect(menu.bottom, lessThanOrEqualTo(trigger.top));
  });

  testWidgets('меню не вылезает за экран', (tester) async {
    await tester.pumpWidget(host(Alignment.bottomCenter));
    final menu = await openAndGetMenuRect(tester);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;

    expect(menu.top, greaterThanOrEqualTo(0));
    expect(menu.bottom, lessThanOrEqualTo(screen.height));
  });
}
