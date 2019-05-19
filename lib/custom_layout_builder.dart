import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class LayoutBuilderId extends ParentDataWidget<CustomMultiChildLayoutBuilder> {
  /// Marks a child with a layout identifier.
  ///
  /// Both the child and the id arguments must not be null.
  LayoutBuilderId({
    Key key,
    @required this.id,
    @required Widget child,
  })  : assert(child != null),
        assert(id != null),
        super(key: key ?? ValueKey<Object>(id), child: child);

  /// An object representing the identity of this child.
  ///
  /// The [id] needs to be unique among the children that the
  /// [CustomMultiChildLayoutBuilder] manages.
  final Object id;

  @override
  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parentData is MultiChildLayoutParentData);
    final MultiChildLayoutParentData parentData = renderObject.parentData;
    if (parentData.id != id) {
      parentData.id = id;
      final AbstractNode targetParent = renderObject.parent;
      if (targetParent is RenderObject) targetParent.markNeedsLayout();
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Object>('id', id));
  }
}

typedef CustomMultiChildBuilder = Widget Function(BuildContext context, Object data);

class CustomMultiChildLayoutBuilder extends RenderObjectWidget {
  /// Creates a custom multi-child layout.
  ///
  /// The [delegate] argument must not be null.
  CustomMultiChildLayoutBuilder({
    Key key,
    @required this.delegate,
    this.children = const <Object, CustomMultiChildBuilder>{}, // TODO deduplicate ids of LayoutBuilderId and map keys
  })  : assert(delegate != null),
        assert(children != null),
        super(key: key);

  final Map<Object, CustomMultiChildBuilder> children;

  /// The delegate that controls the layout of the children.
  final MultiChildLayoutBuilderDelegate delegate;

  @override
  RenderCustomMultiChildLayoutBox createRenderObject(BuildContext context) {
    return RenderCustomMultiChildLayoutBox(delegate: delegate);
  }

  @override
  void updateRenderObject(BuildContext context, RenderCustomMultiChildLayoutBox renderObject) {
    renderObject.delegate = delegate;
  }

  @override
  RenderObjectElement createElement() => MultiChildRenderObjectElement(this);
}

class MultiChildRenderObjectElement extends RenderObjectElement {
  /// Creates an element that uses the given widget as its configuration.
  MultiChildRenderObjectElement(CustomMultiChildLayoutBuilder widget) : super(widget);

  @override
  CustomMultiChildLayoutBuilder get widget => super.widget;

  /// The current list of children of this element.
  Map<Object, Element> _children = {};

  @override
  void insertChildRenderObject(RenderObject child, Element slot) {
    final ContainerRenderObjectMixin<RenderObject, ContainerParentDataMixin<RenderObject>> renderObject =
        this.renderObject;
    assert(renderObject.debugValidateChild(child));
    renderObject.insert(child, after: slot?.renderObject);
    assert(renderObject == this.renderObject);
  }

  @override
  void moveChildRenderObject(RenderObject child, dynamic slot) {
    final ContainerRenderObjectMixin<RenderObject, ContainerParentDataMixin<RenderObject>> renderObject =
        this.renderObject;
    assert(child.parent == renderObject);
    renderObject.move(child, after: slot?.renderObject);
    assert(renderObject == this.renderObject);
  }

  @override
  void removeChildRenderObject(RenderObject child) {
    final ContainerRenderObjectMixin<RenderObject, ContainerParentDataMixin<RenderObject>> renderObject =
        this.renderObject;
    assert(child.parent == renderObject);
    renderObject.remove(child);
    assert(renderObject == this.renderObject);
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    for (Element child in _children.values) {
      visitor(child);
    }
  }

  @override
  void forgetChild(Element child) {
    assert(_children.containsValue(child));
    _children.remove(child);
  }

  @override
  void performRebuild() {
    // This gets called if markNeedsBuild() is called on us.
    // That might happen if, e.g., our builder uses Inherited widgets.
    renderObject.markNeedsLayout();
    super.performRebuild(); // Calls widget.updateRenderObject (a no-op in this case).
  }

  @override
  void mount(Element parent, dynamic newSlot) {
    super.mount(parent, newSlot);
    widget.delegate._buildWidget = _buildWidget;
  }

  @override
  void unmount() {
    widget.delegate._buildWidget = null;
    super.unmount();
  }

  void _buildWidget(Object childId, Object data) {
    owner.buildScope(this, () {
      Widget built;
      if (widget.children[childId] != null) {
        try {
          built = widget.children[childId](this, data);
          debugWidgetBuilderValue(widget, built);
        } catch (e, stack) {
          built = ErrorWidget.builder(_debugReportException(ErrorDescription('building $widget'), e, stack));
        }
      }
      try {
        _children[childId] = updateChild(_children[childId], built, null);
        assert(_children[childId] != null);
      } catch (e, stack) {
        built = ErrorWidget.builder(_debugReportException(ErrorDescription('building $widget'), e, stack));
        _children[childId] = updateChild(null, built, slot);
      }
    });
  }

  @override
  void update(CustomMultiChildLayoutBuilder newWidget) {
    super.update(newWidget);
    assert(widget == newWidget);
    widget.delegate._buildWidget = _buildWidget;
    renderObject.markNeedsLayout();
    // TODO remove children that aren't children in newWidget anymore
  }
}

abstract class MultiChildLayoutBuilderDelegate {
  RenderBox Function(Object) _idToChild;
  Set<RenderBox> _debugChildrenNeedingLayout;
  void Function(VoidCallback callback) _invokeLayoutCallback;
  void Function(Object childId, Object data) _buildWidget;

  /// True if a non-null LayoutChild was provided for the specified id.
  ///
  /// Call this from the [performLayout] or [getSize] methods to
  /// determine which children are available, if the child list might
  /// vary.
  // TODO readd something similar?
//  bool hasChild(Object childId) => _idToChild[childId] != null;

  void buildChild(Object childId, Object data) {
    _invokeLayoutCallback(() {
      _buildWidget(childId, data);
    });
  }

  /// Ask the child to update its layout within the limits specified by
  /// the constraints parameter. The child's size is returned.
  ///
  /// Call this from your [performLayout] function to lay out each
  /// child. Every child must be laid out using this function exactly
  /// once each time the [performLayout] function is called.
  Size layoutChild(Object childId, BoxConstraints constraints) {
    final RenderBox child = _idToChild(childId);
    assert(() {
      if (child == null) {
        throw FlutterError('The $this custom multichild layout delegate tried to lay out a non-existent child.\n'
            'There is no child with the id "$childId".');
      }
      // TODO: reimplement similar diagnostics
//      if (!_debugChildrenNeedingLayout.remove(child)) {
//        throw FlutterError(
//            'The $this custom multichild layout delegate tried to lay out the child with id "$childId" more than once.\n'
//            'Each child must be laid out exactly once.');
//      }
      try {
        assert(constraints.debugAssertIsValid(isAppliedConstraint: true));
      } on AssertionError catch (exception) {
        throw FlutterError(
            'The $this custom multichild layout delegate provided invalid box constraints for the child with id "$childId".\n'
                '$exception\n'
                'The minimum width and height must be greater than or equal to zero.\n'
                'The maximum width must be greater than or equal to the minimum width.\n'
                'The maximum height must be greater than or equal to the minimum height.');
      }
      return true;
    }());
    child.layout(constraints, parentUsesSize: true);
    return child.size;
  }

  /// Specify the child's origin relative to this origin.
  ///
  /// Call this from your [performLayout] function to position each
  /// child. If you do not call this for a child, its position will
  /// remain unchanged. Children initially have their position set to
  /// (0,0), i.e. the top left of the [RenderCustomMultiChildLayoutBox].
  void positionChild(Object childId, Offset offset) {
    final RenderBox child = _idToChild(childId);
    assert(() {
      if (child == null) {
        throw FlutterError('The $this custom multichild layout delegate tried to position out a non-existent child:\n'
            'There is no child with the id "$childId".');
      }
      if (offset == null) {
        throw FlutterError(
            'The $this custom multichild layout delegate provided a null position for the child with id "$childId".');
      }
      return true;
    }());
    final MultiChildLayoutParentData childParentData = child.parentData;
    childParentData.offset = offset;
  }

  String _debugDescribeChild(RenderBox child) {
    final MultiChildLayoutParentData childParentData = child.parentData;
    return '${childParentData.id}: $child';
  }

  void _callPerformLayout(
      Size size,
      RenderBox Function() firstChild,
      void Function(VoidCallback callback) invokeLayoutCallback,
      ) {
    _invokeLayoutCallback = invokeLayoutCallback; // TODO backup for reentrance

    // A particular layout delegate could be called reentrantly, e.g. if it used
    // by both a parent and a child. So, we must restore the _idToChild map when
    // we return.
    final previousIdToChild = _idToChild;

    Set<RenderBox> debugPreviousChildrenNeedingLayout;
    assert(() {
      debugPreviousChildrenNeedingLayout = _debugChildrenNeedingLayout;
      _debugChildrenNeedingLayout = <RenderBox>{};
      return true;
    }());

    try {
      _idToChild = (Object childId) {
        RenderBox child = firstChild();
        while (child != null) {
          final MultiChildLayoutParentData childParentData = child.parentData;
          assert(() {
            if (childParentData.id == null) {
              throw FlutterError('The following child has no ID:\n'
                  '  $child\n'
                  'Every child of a RenderCustomMultiChildLayoutBox must have an ID in its parent data.');
            }
            return true;
          }());
          if (childParentData.id == childId) return child;
          // TODO: reimplement similar diagnostics
//        assert(() {
//          _debugChildrenNeedingLayout.add(child);
//          return true;
//        }());
          child = childParentData.nextSibling;
        }
        throw FlutterError('Child with ID: $childId has not been build.');
      };
      performLayout(size);
      assert(() {
        if (_debugChildrenNeedingLayout.isNotEmpty) {
          if (_debugChildrenNeedingLayout.length > 1) {
            throw FlutterError('The $this custom multichild layout delegate forgot to lay out the following children:\n'
                '  ${_debugChildrenNeedingLayout.map<String>(_debugDescribeChild).join("\n  ")}\n'
                'Each child must be laid out exactly once.');
          } else {
            throw FlutterError('The $this custom multichild layout delegate forgot to lay out the following child:\n'
                '  ${_debugDescribeChild(_debugChildrenNeedingLayout.single)}\n'
                'Each child must be laid out exactly once.');
          }
        }
        return true;
      }());
    } finally {
      _idToChild = previousIdToChild;
      assert(() {
        _debugChildrenNeedingLayout = debugPreviousChildrenNeedingLayout;
        return true;
      }());
    }
  }

  /// Override this method to return the size of this object given the
  /// incoming constraints.
  ///
  /// The size cannot reflect the sizes of the children. If this layout has a
  /// fixed width or height the returned size can reflect that; the size will be
  /// constrained to the given constraints.
  ///
  /// By default, attempts to size the box to the biggest size
  /// possible given the constraints.
  Size getSize(BoxConstraints constraints) => constraints.biggest;

  /// Override this method to lay out and position all children given this
  /// widget's size.
  ///
  /// This method must call [layoutChild] for each child. It should also specify
  /// the final position of each child with [positionChild].
  void performLayout(Size size);

  /// Override this method to return true when the children need to be
  /// laid out.
  ///
  /// This should compare the fields of the current delegate and the given
  /// `oldDelegate` and return true if the fields are such that the layout would
  /// be different.
  bool shouldRelayout(covariant MultiChildLayoutBuilderDelegate oldDelegate);

  /// Override this method to include additional information in the
  /// debugging data printed by [debugDumpRenderTree] and friends.
  ///
  /// By default, returns the [runtimeType] of the class.
  @override
  String toString() => '$runtimeType';
}

/// Defers the layout of multiple children to a delegate.
///
/// The delegate can determine the layout constraints for each child and can
/// decide where to position each child. The delegate can also determine the
/// size of the parent, but the size of the parent cannot depend on the sizes of
/// the children.
class RenderCustomMultiChildLayoutBox extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, MultiChildLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, MultiChildLayoutParentData> {
  /// Creates a render object that customizes the layout of multiple children.
  ///
  /// The [delegate] argument must not be null.
  RenderCustomMultiChildLayoutBox({
    List<RenderBox> children,
    @required MultiChildLayoutBuilderDelegate delegate,
  })  : assert(delegate != null),
        _delegate = delegate;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! MultiChildLayoutParentData) child.parentData = MultiChildLayoutParentData();
  }

  /// The delegate that controls the layout of the children.
  MultiChildLayoutBuilderDelegate get delegate => _delegate;
  MultiChildLayoutBuilderDelegate _delegate;

  set delegate(MultiChildLayoutBuilderDelegate value) {
    assert(value != null);
    if (_delegate == value) return;
    if (value.runtimeType != _delegate.runtimeType || value.shouldRelayout(_delegate)) markNeedsLayout();
    _delegate = value;
  }

  Size _getSize(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    return constraints.constrain(_delegate.getSize(constraints));
  }

  // TODO(ianh): It's a bit dubious to be using the getSize function from the delegate to
  // figure out the intrinsic dimensions. We really should either not support intrinsics,
  // or we should expose intrinsic delegate callbacks and throw if they're not implemented.

  @override
  double computeMinIntrinsicWidth(double height) {
    final double width = _getSize(BoxConstraints.tightForFinite(height: height)).width;
    if (width.isFinite) return width;
    return 0.0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final double width = _getSize(BoxConstraints.tightForFinite(height: height)).width;
    if (width.isFinite) return width;
    return 0.0;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final double height = _getSize(BoxConstraints.tightForFinite(width: width)).height;
    if (height.isFinite) return height;
    return 0.0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final double height = _getSize(BoxConstraints.tightForFinite(width: width)).height;
    if (height.isFinite) return height;
    return 0.0;
  }

  @override
  void performLayout() {
    size = _getSize(constraints);
    delegate._callPerformLayout(size, () => firstChild, (callback) => invokeLayoutCallback((_) => callback()));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(HitTestResult result, {Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}

FlutterErrorDetails _debugReportException(
    DiagnosticsNode context,
    dynamic exception,
    StackTrace stack, {
      InformationCollector informationCollector,
    }) {
  final FlutterErrorDetails details = FlutterErrorDetails(
    exception: exception,
    stack: stack,
    library: 'widgets library',
    context: context,
    informationCollector: informationCollector,
  );
  FlutterError.reportError(details);
  return details;
}
