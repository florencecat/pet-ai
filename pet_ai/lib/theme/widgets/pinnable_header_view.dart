import 'package:flutter/material.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:provider/provider.dart';

/// Отступ страницы: по бокам, сверху (сверх системной зоны) и между заголовком
/// и содержимым — везде одинаковый.
const _padding = 16.0;

/// Высота тени под закреплённым заголовком.
const _shadowHeight = 8.0;

/// Скроллируемое тело страницы с заголовком сверху.
///
/// По настройке [AppearanceController.pinnedHeader] заголовок либо закреплён
/// (уезжает только содержимое), либо скроллится вместе с ним. Технически
/// разница ровно одна: лежит [header] внутри списка или над ним — поэтому
/// страница отдаёт заголовок и содержимое по отдельности, а раскладку из них
/// собирает виджет.
///
/// Чтобы применить к странице: отдать сюда `header` и `children` вместо того,
/// чтобы собирать `ListView` самой. Отступы виджет ставит те же, что страницы
/// задавали руками: 16 по бокам, сверху — системная зона плюс 16.
class PinnableHeaderView extends StatefulWidget {
  /// Заголовок страницы: название, имя питомца, статус.
  final Widget header;

  /// Содержимое под заголовком.
  final List<Widget> children;

  /// Отступ снизу — из-под содержимого должна выезжать плавающая навигация.
  final double bottomPadding;

  const PinnableHeaderView({
    super.key,
    required this.header,
    required this.children,
    this.bottomPadding = 100,
  });

  @override
  State<PinnableHeaderView> createState() => _PinnableHeaderViewState();
}

class _PinnableHeaderViewState extends State<PinnableHeaderView> {
  bool _scrolled = false;

  /// Тень нужна, только когда под заголовок уже что-то уехало. Перерисовываемся
  /// на переключении флага, а не на каждом пикселе скролла.
  bool _onScroll(ScrollNotification notification) {
    final scrolled = notification.metrics.pixels > 0;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + _padding;

    if (!context.watch<AppearanceController>().pinnedHeader) {
      return ListView(
        padding: EdgeInsets.fromLTRB(
          _padding,
          top,
          _padding,
          widget.bottomPadding,
        ),
        children: [
          widget.header,
          const SizedBox(height: _padding),
          ...widget.children,
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(_padding, top, _padding, _padding),
          child: widget.header,
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: Stack(
              children: [
                ListView(
                  padding: EdgeInsets.fromLTRB(
                    _padding,
                    0,
                    _padding,
                    widget.bottomPadding,
                  ),
                  children: widget.children,
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _HeaderShadow(visible: _scrolled),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Тень под закреплённым заголовком.
///
/// Рисуется поверх списка отдельной градиентной полоской, а не тенью бокса
/// самого заголовка: своей заливки у заголовка нет — за ним градиентный фон
/// страницы, — и обычный boxShadow просвечивал бы сквозь него.
class _HeaderShadow extends StatelessWidget {
  final bool visible;

  const _HeaderShadow({required this.visible});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: _shadowHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withAlpha(20), Colors.black.withAlpha(0)],
            ),
          ),
        ),
      ),
    );
  }
}
