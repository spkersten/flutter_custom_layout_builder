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

class ScreenWithNavigationBar extends StatefulWidget {
  @override
  _ScreenWithNavigationBarState createState() => _ScreenWithNavigationBarState();
}

class _ScreenWithNavigationBarState extends State<ScreenWithNavigationBar> {
  TextStyle _messageStyle = TextStyle(fontSize: 14);

  @override
  Widget build(BuildContext context) {
    return Material(
      child: CustomMultiChildLayoutBuilder(
        delegate: FooBuilder(),
        children: {
          LedgerId.navBar: (context, data) => LayoutBuilderId(
            id: LedgerId.navBar,
            child: GestureDetector(
              onTap: () => setState(() {
                _messageStyle = _messageStyle.copyWith(fontSize: _messageStyle.fontSize * 2);
              }),
              child: Container(
                color: Colors.red.withOpacity(0.8),
                child: Padding(padding: EdgeInsets.all(26),child: Text("Hello world", style: _messageStyle,)),
              ),
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
