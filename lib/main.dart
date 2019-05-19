import 'package:flutter/material.dart';

import 'custom_layout_builder.dart';

void main() => runApp(TransparentNavigationBarExample());

class TransparentNavigationBarExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(home: ScreenWithNavigationBar());
}

enum LedgerId {
  navBar,
  main,
}

class ScreenWithNavigationBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      child: CustomMultiChildLayoutBuilder(
        delegate: FooBuilder(),
        children: {
          LedgerId.navBar: (context, data) => LayoutBuilderId(
            id: LedgerId.navBar,
            child: Container(
              color: Colors.red.withOpacity(0.8),
              child: Padding(padding: EdgeInsets.all(26),child: Text("Hello world")),
            ),
          ),
          LedgerId.main: (context, data) => LayoutBuilderId(
            id: LedgerId.main,
            child: CustomScrollView(
              slivers: <Widget>[
                SliverList(
                  delegate: SliverChildListDelegate(List.generate(20, (_) => Container(
                    height: 40,
                    color: Colors.purple, margin: EdgeInsets.all(4),
                  ))),
                ),
                SliverToBoxAdapter(child: SizedBox(height: data)),
              ],
            ),
          ),
        },
      ),
    );
  }
}

class FooBuilder extends MultiChildLayoutBuilderDelegate {
  @override
  void performLayout(Size size) {
    buildChild(LedgerId.navBar, "Hello World");
    final navBarSize = layoutChild(LedgerId.navBar, BoxConstraints(minWidth: size.width));
    positionChild(LedgerId.navBar, Offset(0, size.height - navBarSize.height));

    buildChild(LedgerId.main, navBarSize.height);
    layoutChild(LedgerId.main, BoxConstraints.tight(size));
    positionChild(LedgerId.main, Offset.zero);
  }

  @override
  bool shouldRelayout(MultiChildLayoutBuilderDelegate oldDelegate) => true;
}
