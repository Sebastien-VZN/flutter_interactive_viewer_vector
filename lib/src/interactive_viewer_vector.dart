/// Fork of the Flutter SDK InteractiveViewer with a direct RenderTransform
/// update (markNeedsPaint) instead of setState: avoids a full widget tree
/// rebuild on every pan/zoom frame.
///
/// Derived from the Flutter SDK (BSD 3-Clause, Copyright 2014 The Flutter Authors).
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart' show Quad, Vector3;

/// A signature for widget builders that take a [Quad] of the current viewport.
///
/// See also:
///   * [InteractiveViewerVector.builder], whose builder is of this type.
///   * [WidgetBuilder], which is similar, but takes no viewport.
typedef InteractiveViewerVectorWidgetBuilder = Widget Function(BuildContext context, Quad viewport);

/// A widget that enables pan and zoom interactions with its child.
///
/// The user can transform the child by dragging to pan or pinching to zoom.
///
/// By default, InteractiveViewerVector clips its child using [Clip.hardEdge].
/// To prevent this behavior, consider setting [clipBehavior] to [Clip.none].
/// When [clipBehavior] is [Clip.none], InteractiveViewerVector may draw outside of
/// its original area of the screen, such as when a child is zoomed in and
/// increases in size. However, it will not receive gestures outside of its original area.
/// To prevent dead areas where InteractiveViewerVector does not receive gestures,
/// don't set [clipBehavior] or be sure that the InteractiveViewerVector widget is the
/// size of the area that should be interactive.
@immutable
class InteractiveViewerVector extends StatefulWidget {
  /// Create an InteractiveViewerVector.
  const InteractiveViewerVector({
    required Widget this.child,
    super.key,
    this.clipBehavior = Clip.hardEdge,
    this.panAxis = PanAxis.free,
    this.boundaryMargin = EdgeInsets.zero,
    this.constrained = true,
    // These default scale values were eyeballed as reasonable limits for common
    // use cases.
    this.maxScale = 2.5,
    this.minScale = 0.8,
    this.interactionEndFrictionCoefficient = _kDrag,
    this.onInteractionEnd,
    this.onInteractionStart,
    this.onInteractionUpdate,
    this.panEnabled = true,
    this.scaleEnabled = true,
    this.scaleFactor = kDefaultMouseScrollToScaleFactor,
    this.transformationController,
    this.alignment,
    this.trackpadScrollCausesScale = false,
  }) : builder = null;

  /// Creates an InteractiveViewerVector for a child that is created on demand.
  ///
  /// Can be used to render a child that changes in response to the current
  /// transformation.
  ///
  /// See the [builder] attribute docs for an example of using it to optimize a
  /// large child.
  const InteractiveViewerVector.builder({
    required InteractiveViewerVectorWidgetBuilder this.builder,
    super.key,
    this.clipBehavior = Clip.hardEdge,
    this.panAxis = PanAxis.free,
    this.boundaryMargin = EdgeInsets.zero,
    // These default scale values were eyeballed as reasonable limits for common
    // use cases.
    this.maxScale = 2.5,
    this.minScale = 0.8,
    this.interactionEndFrictionCoefficient = _kDrag,
    this.onInteractionEnd,
    this.onInteractionStart,
    this.onInteractionUpdate,
    this.panEnabled = true,
    this.scaleEnabled = true,
    this.scaleFactor = 200.0,
    this.transformationController,
    this.alignment,
    this.trackpadScrollCausesScale = false,
  }) : constrained = false,
       child = null;

  /// The alignment of the child's origin, relative to the size of the box.
  final Alignment? alignment;

  /// If set to [Clip.none], the child may extend beyond the size of the InteractiveViewerVector,
  /// but it will not receive gestures in these areas.
  /// Be sure that the InteractiveViewerVector is the desired size when using [Clip.none].
  ///
  /// Defaults to [Clip.hardEdge].
  final Clip clipBehavior;

  /// When set to [PanAxis.aligned], panning is only allowed in the horizontal
  /// axis or the vertical axis, diagonal panning is not allowed.
  ///
  /// When set to [PanAxis.vertical] or [PanAxis.horizontal] panning is only
  /// allowed in the specified axis. For example, if set to [PanAxis.vertical],
  /// panning will only be allowed in the vertical axis. And if set to [PanAxis.horizontal],
  /// panning will only be allowed in the horizontal axis.
  ///
  /// When set to [PanAxis.free] panning is allowed in all directions.
  ///
  /// Defaults to [PanAxis.free].
  final PanAxis panAxis;

  /// A margin for the visible boundaries of the child.
  ///
  /// Any transformation that results in the viewport being able to view outside
  /// of the boundaries will be stopped at the boundary. The boundaries do not
  /// rotate with the rest of the scene, so they are always aligned with the
  /// viewport.
  ///
  /// To produce no boundaries at all, pass infinite [EdgeInsets], such as
  /// `EdgeInsets.all(double.infinity)`.
  ///
  /// No edge can be NaN.
  ///
  /// Defaults to [EdgeInsets.zero], which results in boundaries that are the
  /// exact same size and position as the [child].
  final EdgeInsets boundaryMargin;

  /// Builds the child of this widget.
  ///
  /// Passed with the [InteractiveViewerVector.builder] constructor. Otherwise, the
  /// [child] parameter must be passed directly, and this is null.
  ///
  /// See also:
  ///
  ///   * [ListView.builder], which follows a similar pattern.
  final InteractiveViewerVectorWidgetBuilder? builder;

  /// The child [Widget] that is transformed by InteractiveViewerVector.
  ///
  /// If the [InteractiveViewerVector.builder] constructor is used, then this will be
  /// null, otherwise it is required.
  final Widget? child;

  /// Whether the normal size constraints at this point in the widget tree are
  /// applied to the child.
  ///
  /// If set to false, then the child will be given infinite constraints. This
  /// is often useful when a child should be bigger than the InteractiveViewerVector.
  ///
  /// For example, for a child which is bigger than the viewport but can be
  /// panned to reveal parts that were initially offscreen, [constrained] must
  /// be set to false to allow it to size itself properly. If [constrained] is
  /// true and the child can only size itself to the viewport, then areas
  /// initially outside of the viewport will not be able to receive user
  /// interaction events. If experiencing regions of the child that are not
  /// receptive to user gestures, make sure [constrained] is false and the child
  /// is sized properly.
  ///
  /// Defaults to true.
  final bool constrained;

  /// If false, the user will be prevented from panning.
  ///
  /// Defaults to true.
  ///
  /// See also:
  ///
  ///   * [scaleEnabled], which is similar but for scale.
  final bool panEnabled;

  /// If false, the user will be prevented from scaling.
  ///
  /// Defaults to true.
  ///
  /// See also:
  ///
  ///   * [panEnabled], which is similar but for panning.
  final bool scaleEnabled;

  /// Whether trackpad scrolling causes a scale gesture.
  final bool trackpadScrollCausesScale;

  /// Determines the amount of scale to be performed per pointer scroll.
  ///
  /// Defaults to [kDefaultMouseScrollToScaleFactor].
  ///
  /// Increasing this value above the default causes scaling to feel slower,
  /// while decreasing it causes scaling to feel faster.
  ///
  /// The amount of scale is calculated as the exponential function of the
  /// [PointerScrollEvent.scrollDelta] to [scaleFactor] ratio. In the Flutter
  /// engine, the mousewheel [PointerScrollEvent.scrollDelta] is hardcoded to 20
  /// per scroll, while a trackpad scroll can be any amount.
  ///
  /// Affects only pointer device scrolling, not pinch to zoom.
  final double scaleFactor;

  /// The maximum allowed scale.
  ///
  /// The scale will be clamped between this and [minScale] inclusively.
  ///
  /// Defaults to 2.5.
  ///
  /// Must be greater than zero and greater than [minScale].
  final double maxScale;

  /// The minimum allowed scale.
  ///
  /// The scale will be clamped between this and [maxScale] inclusively.
  ///
  /// Scale is also affected by [boundaryMargin]. If the scale would result in
  /// viewing beyond the boundary, then it will not be allowed. By default,
  /// boundaryMargin is EdgeInsets.zero, so scaling below 1.0 will not be
  /// allowed in most cases without first increasing the boundaryMargin.
  ///
  /// Defaults to 0.8.
  ///
  /// Must be a finite number greater than zero and less than [maxScale].
  final double minScale;

  /// Changes the deceleration behavior after a gesture.
  ///
  /// Defaults to 0.0000135.
  ///
  /// Must be a finite number greater than zero.
  final double interactionEndFrictionCoefficient;

  /// Called when the user ends a pan or scale gesture on the widget.
  ///
  /// At the time this is called, the [TransformationControllerVector] will have
  /// already been updated to reflect the change caused by the interaction,
  /// though a pan may cause an inertia animation after this is called as well.
  ///
  /// Will be called even if the interaction is disabled with [panEnabled] or
  /// [scaleEnabled] for both touch gestures and mouse interactions.
  ///
  /// A [GestureDetector] wrapping the InteractiveViewerVector will not respond to
  /// [GestureDetector.onScaleStart], [GestureDetector.onScaleUpdate], and
  /// [GestureDetector.onScaleEnd]. Use [onInteractionStart],
  /// [onInteractionUpdate], and [onInteractionEnd] to respond to those
  /// gestures.
  ///
  /// See also:
  ///
  ///  * [onInteractionStart], which handles the start of the same interaction.
  ///  * [onInteractionUpdate], which handles an update to the same interaction.
  final GestureScaleEndCallback? onInteractionEnd;

  /// Called when the user begins a pan or scale gesture on the widget.
  ///
  /// At the time this is called, the [TransformationControllerVector] will not have
  /// changed due to this interaction.
  ///
  /// The coordinates provided in the details' `focalPoint` and
  /// `localFocalPoint` are normal Flutter event coordinates, not
  /// InteractiveViewerVector scene coordinates. See
  /// [TransformationControllerVector.toScene] for how to convert these coordinates to
  /// scene coordinates relative to the child.
  ///
  /// See also:
  ///
  ///  * [onInteractionUpdate], which handles an update to the same interaction.
  ///  * [onInteractionEnd], which handles the end of the same interaction.
  final GestureScaleStartCallback? onInteractionStart;

  /// Called when the user updates a pan or scale gesture on the widget.
  ///
  /// At the time this is called, the [TransformationControllerVector] will have
  /// already been updated to reflect the change caused by the interaction, if
  /// the interaction caused the matrix to change.
  ///
  /// The coordinates provided in the details' `focalPoint` and
  /// `localFocalPoint` are normal Flutter event coordinates, not
  /// InteractiveViewerVector scene coordinates. See
  /// [TransformationControllerVector.toScene] for how to convert these coordinates to
  /// scene coordinates relative to the child.
  ///
  /// See also:
  ///
  ///  * [onInteractionStart], which handles the start of the same interaction.
  ///  * [onInteractionEnd], which handles the end of the same interaction.
  final GestureScaleUpdateCallback? onInteractionUpdate;

  /// A [TransformationControllerVector] for the transformation performed on the
  /// child.
  ///
  /// Whenever the child is transformed, the [Matrix4] value is updated and all
  /// listeners are notified. If the value is set, InteractiveViewerVector will update
  /// to respect the new value.
  ///
  /// See also:
  ///
  ///  * [ValueNotifier], the parent class of TransformationControllerVector.
  ///  * [TextEditingController] for an example of another similar pattern.
  final TransformationControllerVector? transformationController;

  // Used as the coefficient of friction in the inertial translation animation.
  // This value was eyeballed to give a feel similar to Google Photos.
  static const double _kDrag = 0.0000135;

  /// Returns the closest point to the given point on the given line segment.
  @visibleForTesting
  static Vector3 getNearestPointOnLine(Vector3 point, Vector3 l1, Vector3 l2) {
    final lengthSquared = math.pow(l2.x - l1.x, 2.0).toDouble() + math.pow(l2.y - l1.y, 2.0).toDouble();

    // In this case, l1 == l2.
    if (lengthSquared == 0) {
      return l1;
    }

    // Calculate how far down the line segment the closest point is and return
    // the point.
    final l1P = point - l1;
    final l1L2 = l2 - l1;
    final fraction = clampDouble(l1P.dot(l1L2) / lengthSquared, 0, 1);
    return l1 + l1L2 * fraction;
  }

  /// Given a quad, return its axis aligned bounding box.
  @visibleForTesting
  static Quad getAxisAlignedBoundingBox(Quad quad) {
    final double minX = math.min(quad.point0.x, math.min(quad.point1.x, math.min(quad.point2.x, quad.point3.x)));
    final double minY = math.min(quad.point0.y, math.min(quad.point1.y, math.min(quad.point2.y, quad.point3.y)));
    final double maxX = math.max(quad.point0.x, math.max(quad.point1.x, math.max(quad.point2.x, quad.point3.x)));
    final double maxY = math.max(quad.point0.y, math.max(quad.point1.y, math.max(quad.point2.y, quad.point3.y)));
    return Quad.points(Vector3(minX, minY, 0), Vector3(maxX, minY, 0), Vector3(maxX, maxY, 0), Vector3(minX, maxY, 0));
  }

  /// Returns true iff the point is inside the rectangle given by the Quad,
  /// inclusively.
  /// Algorithm from https://math.stackexchange.com/a/190373.
  @visibleForTesting
  static bool pointIsInside(Vector3 point, Quad quad) {
    final aM = point - quad.point0;
    final aB = quad.point1 - quad.point0;
    final aD = quad.point3 - quad.point0;

    final aMAB = aM.dot(aB);
    final aBAB = aB.dot(aB);
    final aMAD = aM.dot(aD);
    final aDAD = aD.dot(aD);

    return 0 <= aMAB && aMAB <= aBAB && 0 <= aMAD && aMAD <= aDAD;
  }

  /// Get the point inside (inclusively) the given Quad that is nearest to the
  /// given Vector3.
  @visibleForTesting
  static Vector3 getNearestPointInside(Vector3 point, Quad quad) {
    // If the point is inside the axis aligned bounding box, then it's ok where
    // it is.
    if (pointIsInside(point, quad)) {
      return point;
    }

    // Otherwise, return the nearest point on the quad.
    final closestPoints = <Vector3>[
      InteractiveViewerVector.getNearestPointOnLine(point, quad.point0, quad.point1),
      InteractiveViewerVector.getNearestPointOnLine(point, quad.point1, quad.point2),
      InteractiveViewerVector.getNearestPointOnLine(point, quad.point2, quad.point3),
      InteractiveViewerVector.getNearestPointOnLine(point, quad.point3, quad.point0),
    ];
    var minDistance = double.infinity;
    late Vector3 closestOverall;
    for (final closePoint in closestPoints) {
      final distance = math.sqrt(math.pow(point.x - closePoint.x, 2) + math.pow(point.y - closePoint.y, 2));
      if (distance < minDistance) {
        minDistance = distance;
        closestOverall = closePoint;
      }
    }
    return closestOverall;
  }

  @override
  State<InteractiveViewerVector> createState() => _InteractiveViewerVectorState();
}

class _InteractiveViewerVectorState extends State<InteractiveViewerVector> with TickerProviderStateMixin {
  late TransformationControllerVector _transformer =
      widget.transformationController ?? TransformationControllerVector();

  final GlobalKey _childKey = GlobalKey();
  final GlobalKey _parentKey = GlobalKey();
  final GlobalKey _transformKey = GlobalKey();
  Animation<Offset>? _animation;
  Animation<double>? _scaleAnimation;
  late Offset _scaleAnimationFocalPoint;
  late AnimationController _controller;
  late AnimationController _scaleController;
  Axis? _currentAxis; // Used with panAxis.
  Offset? _referenceFocalPoint; // Point where the current gesture began.
  double? _scaleStart; // Scale value at start of scaling gesture.
  _GestureType? _gestureType;

  // The _boundaryRect is calculated by adding the boundaryMargin to the size of
  // the child.
  Rect get _boundaryRect {
    final childRenderBox = _childKey.currentContext!.findRenderObject()! as RenderBox;
    final childSize = childRenderBox.size;
    final boundaryRect = widget.boundaryMargin.inflateRect(Offset.zero & childSize);
    assert(!boundaryRect.isEmpty, "InteractiveViewerVector's child must have nonzero dimensions.");
    // Boundaries that are partially infinite are not allowed because Matrix4's
    // rotation and translation methods don't handle infinites well.
    assert(
      boundaryRect.isFinite ||
          (boundaryRect.left.isInfinite &&
              boundaryRect.top.isInfinite &&
              boundaryRect.right.isInfinite &&
              boundaryRect.bottom.isInfinite),
      "boundaryRect must either be infinite in all directions or finite in all directions.",
    );
    return boundaryRect;
  }

  // The Rect representing the child's parent.
  Rect get _viewport {
    final parentRenderBox = _parentKey.currentContext!.findRenderObject()! as RenderBox;
    return Offset.zero & parentRenderBox.size;
  }

  // Return a new matrix representing the given matrix after applying the given
  // translation.
  Matrix4 _matrixTranslate(Matrix4 matrix, Offset translation) {
    if (translation == Offset.zero) {
      return matrix.clone();
    }

    final Offset alignedTranslation;

    if (_currentAxis != null) {
      alignedTranslation = switch (widget.panAxis) {
        PanAxis.horizontal => _alignAxis(translation, Axis.horizontal),
        PanAxis.vertical => _alignAxis(translation, Axis.vertical),
        PanAxis.aligned => _alignAxis(translation, _currentAxis!),
        PanAxis.free => translation,
      };
    } else {
      alignedTranslation = translation;
    }

    final nextMatrix = matrix.clone()..translateByDouble(alignedTranslation.dx, alignedTranslation.dy, 0, 1);

    // Transform the viewport to determine where its four corners will be after
    // the child has been transformed.
    final nextViewport = _transformViewport(nextMatrix, _viewport);

    // If the boundaries are infinite, then no need to check if the translation
    // fits within them.
    if (_boundaryRect.isInfinite) {
      return nextMatrix;
    }

    final boundariesAabbQuad = Quad.points(
      Vector3(_boundaryRect.left, _boundaryRect.top, 0),
      Vector3(_boundaryRect.right, _boundaryRect.top, 0),
      Vector3(_boundaryRect.right, _boundaryRect.bottom, 0),
      Vector3(_boundaryRect.left, _boundaryRect.bottom, 0),
    );

    // If the given translation fits completely within the boundaries, allow it.
    final offendingDistance = _exceedsBy(boundariesAabbQuad, nextViewport);
    if (offendingDistance == Offset.zero) {
      return nextMatrix;
    }

    // Desired translation goes out of bounds, so translate to the nearest
    // in-bounds point instead.
    final nextTotalTranslation = _getMatrixTranslation(nextMatrix);
    final currentScale = matrix.getMaxScaleOnAxis();
    final correctedTotalTranslation = Offset(
      nextTotalTranslation.dx - offendingDistance.dx * currentScale,
      nextTotalTranslation.dy - offendingDistance.dy * currentScale,
    );
    final correctedMatrix = matrix.clone()
      ..setTranslation(Vector3(correctedTotalTranslation.dx, correctedTotalTranslation.dy, 0));

    // Double check that the corrected translation fits.
    final correctedViewport = _transformViewport(correctedMatrix, _viewport);
    final offendingCorrectedDistance = _exceedsBy(boundariesAabbQuad, correctedViewport);
    if (offendingCorrectedDistance == Offset.zero) {
      return correctedMatrix;
    }

    // If the corrected translation doesn't fit in either direction, don't allow
    // any translation at all. This happens when the viewport is larger than the
    // entire boundary.
    if (offendingCorrectedDistance.dx != 0.0 && offendingCorrectedDistance.dy != 0.0) {
      return matrix.clone();
    }

    // Otherwise, allow translation in only the direction that fits. This
    // happens when the viewport is larger than the boundary in one direction.
    final unidirectionalCorrectedTotalTranslation = Offset(
      offendingCorrectedDistance.dx == 0.0 ? correctedTotalTranslation.dx : 0.0,
      offendingCorrectedDistance.dy == 0.0 ? correctedTotalTranslation.dy : 0.0,
    );
    return matrix.clone()..setTranslation(
      Vector3(unidirectionalCorrectedTotalTranslation.dx, unidirectionalCorrectedTotalTranslation.dy, 0),
    );
  }

  // Return a new matrix representing the given matrix after applying the given
  // scale.
  Matrix4 _matrixScale(Matrix4 matrix, double scale) {
    if (scale == 1.0) {
      return matrix.clone();
    }
    //assert(scale != 0.0);

    // Don't allow a scale that results in an overall scale beyond min/max
    // scale.
    final currentScale = _transformer.value.getMaxScaleOnAxis();
    final double totalScale = math.max(
      currentScale * scale,
      // Ensure that the scale cannot make the child so big that it can't fit
      // inside the boundaries (in either direction).
      math.max(_viewport.width / _boundaryRect.width, _viewport.height / _boundaryRect.height),
    );
    final clampedTotalScale = clampDouble(totalScale, widget.minScale, widget.maxScale);
    final clampedScale = clampedTotalScale / currentScale;
    return matrix.clone()..scaleByDouble(clampedScale, clampedScale, clampedScale, 1);
  }

  // Returns true iff the given _GestureType is enabled.
  bool _gestureIsSupported(_GestureType? gestureType) {
    return switch (gestureType) {
      _GestureType.scale => widget.scaleEnabled,
      _GestureType.pan || null => widget.panEnabled,
    };
  }

  // Decide which type of gesture this is by comparing the amount of scale
  // and rotation in the gesture, if any. Scale starts at 1 and rotation
  // starts at 0. Pan will have no scale and no rotation because it uses only one
  // finger.
  _GestureType _getGestureType(ScaleUpdateDetails details) {
    final scale = !widget.scaleEnabled ? 1.0 : details.scale;
    if (scale != 1.0) {
      return _GestureType.scale;
    } else {
      return _GestureType.pan;
    }
  }

  // Handle the start of a gesture. All of pan, scale, and rotate are handled
  // with GestureDetector's scale gesture.
  void _onScaleStart(ScaleStartDetails details) {
    widget.onInteractionStart?.call(details);

    if (_controller.isAnimating) {
      _controller
        ..stop()
        ..reset();
      _animation?.removeListener(_handleInertiaAnimation);
      _animation = null;
    }
    if (_scaleController.isAnimating) {
      _scaleController
        ..stop()
        ..reset();
      _scaleAnimation?.removeListener(_handleScaleAnimation);
      _scaleAnimation = null;
    }

    _gestureType = null;
    _currentAxis = null;
    _scaleStart = _transformer.value.getMaxScaleOnAxis();
    _referenceFocalPoint = _transformer.toScene(details.localFocalPoint);
  }

  // Handle an update to an ongoing gesture. All of pan, scale, and rotate are
  // handled with GestureDetector's scale gesture.
  void _onScaleUpdate(ScaleUpdateDetails details) {
    final scale = _transformer.value.getMaxScaleOnAxis();
    _scaleAnimationFocalPoint = details.localFocalPoint;
    final focalPointScene = _transformer.toScene(details.localFocalPoint);

    if (_gestureType == _GestureType.pan) {
      // When a gesture first starts, it sometimes has no change in scale and
      // rotation despite being a two-finger gesture. Here the gesture is
      // allowed to be reinterpreted as its correct type after originally
      // being marked as a pan.
      _gestureType = _getGestureType(details);
    } else {
      _gestureType ??= _getGestureType(details);
    }
    if (!_gestureIsSupported(_gestureType)) {
      widget.onInteractionUpdate?.call(details);
      return;
    }

    switch (_gestureType!) {
      case _GestureType.scale:
        // details.scale gives us the amount to change the scale as of the
        // start of this gesture, so calculate the amount to scale as of the
        // previous call to _onScaleUpdate.
        final desiredScale = _scaleStart! * details.scale;
        final scaleChange = desiredScale / scale;
        _transformer.value = _matrixScale(_transformer.value, scaleChange);

        // While scaling, translate such that the user's two fingers stay on
        // the same places in the scene. That means that the focal point of
        // the scale should be on the same place in the scene before and after
        // the scale.
        final focalPointSceneScaled = _transformer.toScene(details.localFocalPoint);
        _transformer.value = _matrixTranslate(_transformer.value, focalPointSceneScaled - _referenceFocalPoint!);

        // details.localFocalPoint should now be at the same location as the
        // original _referenceFocalPoint point. If it's not, that's because
        // the translate came in contact with a boundary. In that case, update
        // _referenceFocalPoint so subsequent updates happen in relation to
        // the new effective focal point.
        final focalPointSceneCheck = _transformer.toScene(details.localFocalPoint);
        if (_round(_referenceFocalPoint!) != _round(focalPointSceneCheck)) {
          _referenceFocalPoint = focalPointSceneCheck;
        }

      case _GestureType.pan:
        // details may have a change in scale here when scaleEnabled is false.
        // In an effort to keep the behavior similar whether or not scaleEnabled
        // is true, these gestures are thrown away.
        if (details.scale != 1.0) {
          widget.onInteractionUpdate?.call(details);
          return;
        }
        _currentAxis ??= _getPanAxis(_referenceFocalPoint!, focalPointScene);
        // Translate so that the same point in the scene is underneath the
        // focal point before and after the movement.
        final translationChange = focalPointScene - _referenceFocalPoint!;
        _transformer.value = _matrixTranslate(_transformer.value, translationChange);
        _referenceFocalPoint = _transformer.toScene(details.localFocalPoint);
    }
    widget.onInteractionUpdate?.call(details);
  }

  // Handle the end of a gesture of _GestureType. All of pan, scale, and rotate
  // are handled with GestureDetector's scale gesture.
  Future<void> _onScaleEnd(ScaleEndDetails details) async {
    widget.onInteractionEnd?.call(details);
    _scaleStart = null;
    _referenceFocalPoint = null;

    _animation?.removeListener(_handleInertiaAnimation);
    _scaleAnimation?.removeListener(_handleScaleAnimation);
    _controller.reset();
    _scaleController.reset();

    if (!_gestureIsSupported(_gestureType)) {
      _currentAxis = null;
      return;
    }

    switch (_gestureType) {
      case _GestureType.pan:
        if (details.velocity.pixelsPerSecond.distance < kMinFlingVelocity) {
          _currentAxis = null;
          return;
        }
        final translationVector = _transformer.value.getTranslation();
        final translation = Offset(translationVector.x, translationVector.y);
        final frictionSimulationX = FrictionSimulation(
          widget.interactionEndFrictionCoefficient,
          translation.dx,
          details.velocity.pixelsPerSecond.dx,
        );
        final frictionSimulationY = FrictionSimulation(
          widget.interactionEndFrictionCoefficient,
          translation.dy,
          details.velocity.pixelsPerSecond.dy,
        );
        final tFinal = _getFinalTime(
          details.velocity.pixelsPerSecond.distance,
          widget.interactionEndFrictionCoefficient,
        );
        _animation = Tween<Offset>(
          begin: translation,
          end: Offset(frictionSimulationX.finalX, frictionSimulationY.finalX),
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.decelerate));
        _controller.duration = Duration(milliseconds: (tFinal * 1000).round());
        _animation!.addListener(_handleInertiaAnimation);
        await _controller.forward();
      case _GestureType.scale:
        if (details.scaleVelocity.abs() < 0.1) {
          _currentAxis = null;
          return;
        }
        final scale = _transformer.value.getMaxScaleOnAxis();
        final frictionSimulation = FrictionSimulation(
          widget.interactionEndFrictionCoefficient * widget.scaleFactor,
          scale,
          details.scaleVelocity / 10,
        );
        final tFinal = _getFinalTime(
          details.scaleVelocity.abs(),
          widget.interactionEndFrictionCoefficient,
          effectivelyMotionless: 0.1,
        );
        _scaleAnimation = Tween<double>(
          begin: scale,
          end: frictionSimulation.x(tFinal),
        ).animate(CurvedAnimation(parent: _scaleController, curve: Curves.decelerate));
        _scaleController.duration = Duration(milliseconds: (tFinal * 1000).round());
        _scaleAnimation!.addListener(_handleScaleAnimation);
        await _scaleController.forward();
      case null:
        break;
    }
  }

  // Handle mousewheel and web trackpad scroll events.
  void _receivedPointerSignal(PointerSignalEvent event) {
    final local = event.localPosition;
    final global = event.position;
    final double scaleChange;
    if (event is PointerScrollEvent) {
      if (event.kind == PointerDeviceKind.trackpad && !widget.trackpadScrollCausesScale) {
        // Trackpad scroll, so treat it as a pan.
        widget.onInteractionStart?.call(ScaleStartDetails(focalPoint: global, localFocalPoint: local));

        final localDelta = PointerEvent.transformDeltaViaPositions(
          untransformedEndPosition: global + event.scrollDelta,
          untransformedDelta: event.scrollDelta,
          transform: event.transform,
        );

        if (!_gestureIsSupported(_GestureType.pan)) {
          widget.onInteractionUpdate?.call(
            ScaleUpdateDetails(
              focalPoint: global - event.scrollDelta,
              localFocalPoint: local - event.scrollDelta,
              focalPointDelta: -localDelta,
            ),
          );
          widget.onInteractionEnd?.call(ScaleEndDetails());
          return;
        }

        final focalPointScene = _transformer.toScene(local);
        final newFocalPointScene = _transformer.toScene(local - localDelta);

        _transformer.value = _matrixTranslate(_transformer.value, newFocalPointScene - focalPointScene);

        widget.onInteractionUpdate?.call(
          ScaleUpdateDetails(
            focalPoint: global - event.scrollDelta,
            localFocalPoint: local - localDelta,
            focalPointDelta: -localDelta,
          ),
        );
        widget.onInteractionEnd?.call(ScaleEndDetails());
        return;
      }
      // Ignore left and right mouse wheel scroll.
      if (event.scrollDelta.dy == 0.0) {
        return;
      }
      scaleChange = math.exp(-event.scrollDelta.dy / widget.scaleFactor);
    } else if (event is PointerScaleEvent) {
      scaleChange = event.scale;
    } else {
      return;
    }
    widget.onInteractionStart?.call(ScaleStartDetails(focalPoint: global, localFocalPoint: local));

    if (!_gestureIsSupported(_GestureType.scale)) {
      widget.onInteractionUpdate?.call(
        ScaleUpdateDetails(focalPoint: global, localFocalPoint: local, scale: scaleChange),
      );
      widget.onInteractionEnd?.call(ScaleEndDetails());
      return;
    }

    final focalPointScene = _transformer.toScene(local);
    _transformer.value = _matrixScale(_transformer.value, scaleChange);

    // After scaling, translate such that the event's position is at the
    // same scene point before and after the scale.
    final focalPointSceneScaled = _transformer.toScene(local);
    _transformer.value = _matrixTranslate(_transformer.value, focalPointSceneScaled - focalPointScene);

    widget.onInteractionUpdate?.call(
      ScaleUpdateDetails(focalPoint: global, localFocalPoint: local, scale: scaleChange),
    );
    widget.onInteractionEnd?.call(ScaleEndDetails());
  }

  void _handleInertiaAnimation() {
    if (!_controller.isAnimating) {
      _currentAxis = null;
      _animation?.removeListener(_handleInertiaAnimation);
      _animation = null;
      _controller.reset();
      return;
    }
    // Translate such that the resulting translation is _animation.value.
    final translationVector = _transformer.value.getTranslation();
    final translation = Offset(translationVector.x, translationVector.y);
    _transformer.value = _matrixTranslate(
      _transformer.value,
      _transformer.toScene(_animation!.value) - _transformer.toScene(translation),
    );
  }

  void _handleScaleAnimation() {
    if (!_scaleController.isAnimating) {
      _currentAxis = null;
      _scaleAnimation?.removeListener(_handleScaleAnimation);
      _scaleAnimation = null;
      _scaleController.reset();
      return;
    }
    final desiredScale = _scaleAnimation!.value;
    final scaleChange = desiredScale / _transformer.value.getMaxScaleOnAxis();
    final referenceFocalPoint = _transformer.toScene(_scaleAnimationFocalPoint);
    _transformer.value = _matrixScale(_transformer.value, scaleChange);

    // While scaling, translate such that the user's two fingers stay on
    // the same places in the scene. That means that the focal point of
    // the scale should be on the same place in the scene before and after
    // the scale.
    final focalPointSceneScaled = _transformer.toScene(_scaleAnimationFocalPoint);
    _transformer.value = _matrixTranslate(_transformer.value, focalPointSceneScaled - referenceFocalPoint);
  }

  void _handleTransformation() {
    // Update direct du RenderTransform — markNeedsPaint au lieu de setState.
    // Évite le rebuild complet du widget tree à chaque frame de pan/zoom.
    final renderObject = _transformKey.currentContext?.findRenderObject();
    if (renderObject is RenderTransform) {
      renderObject.transform = _transformer.value;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _scaleController = AnimationController(vsync: this);

    _transformer.addListener(_handleTransformation);
    // Injecte le callback de clamping pour que les consumers externes
    // (ControlDragCanvasManager) puissent translater avec boundary clamping.
    _transformer._clampTranslate = _matrixTranslate;
  }

  @override
  void didUpdateWidget(InteractiveViewerVector oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newController = widget.transformationController;
    if (newController == oldWidget.transformationController) {
      return;
    }
    _transformer.removeListener(_handleTransformation);
    if (oldWidget.transformationController == null) {
      _transformer.dispose();
    }
    _transformer = newController ?? TransformationControllerVector();
    _transformer.addListener(_handleTransformation);
    // Réinjecte le callback de clamping sur le nouveau controller.
    _transformer._clampTranslate = _matrixTranslate;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scaleController.dispose();
    _transformer.removeListener(_handleTransformation);
    _transformer._clampTranslate = null;
    if (widget.transformationController == null) {
      _transformer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (widget.child != null) {
      child = _InteractiveViewerVectorBuilt(
        transformKey: _transformKey,
        childKey: _childKey,
        clipBehavior: widget.clipBehavior,
        constrained: widget.constrained,
        matrix: _transformer.value,
        alignment: widget.alignment,
        child: widget.child!,
      );
    } else {
      // When using InteractiveViewerVector.builder, then constrained is false and the
      // viewport is the size of the constraints.
      child = LayoutBuilder(
        builder: (context, constraints) {
          final matrix = _transformer.value;
          return _InteractiveViewerVectorBuilt(
            transformKey: _transformKey,
            childKey: _childKey,
            clipBehavior: widget.clipBehavior,
            constrained: widget.constrained,
            alignment: widget.alignment,
            matrix: matrix,
            child: widget.builder!(context, _transformViewport(matrix, Offset.zero & constraints.biggest)),
          );
        },
      );
    }

    return Listener(
      key: _parentKey,
      onPointerSignal: _receivedPointerSignal,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // Necessary when panning off screen.
        onScaleEnd: _onScaleEnd,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        trackpadScrollCausesScale: widget.trackpadScrollCausesScale,
        trackpadScrollToScaleFactor: Offset(0, -1 / widget.scaleFactor),
        child: child,
      ),
    );
  }
}

// This widget allows us to easily swap in and out the LayoutBuilder in
// InteractiveViewerVector's depending on if it's using a builder or a child.
class _InteractiveViewerVectorBuilt extends StatelessWidget {
  const _InteractiveViewerVectorBuilt({
    required this.child,
    required this.childKey,
    required this.transformKey,
    required this.clipBehavior,
    required this.constrained,
    required this.matrix,
    required this.alignment,
  });

  final Widget child;
  final GlobalKey childKey;
  final GlobalKey transformKey;
  final Clip clipBehavior;
  final bool constrained;
  final Matrix4 matrix;
  final Alignment? alignment;

  @override
  Widget build(BuildContext context) {
    Widget child = Transform(
      key: transformKey,
      transform: matrix,
      alignment: alignment,
      child: KeyedSubtree(key: childKey, child: this.child),
    );

    if (!constrained) {
      child = OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: 0,
        minHeight: 0,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: child,
      );
    }

    return ClipRect(clipBehavior: clipBehavior, child: child);
  }
}

/// Signature pour la fonction de translation avec clamping des boundaries.
/// Injectée par [_InteractiveViewerVectorState] via [_matrixTranslate].
typedef ClampTranslateFn = Matrix4 Function(Matrix4 matrix, Offset translation);

/// A thin wrapper on [ValueNotifier] whose value is a [Matrix4] representing a
/// transformation.
///
/// The [value] defaults to the identity matrix, which corresponds to no
/// transformation.
///
/// See also:
///
///  * [InteractiveViewerVector.transformationController] for detailed documentation
///    on how to use TransformationControllerVector with [InteractiveViewerVector].
class TransformationControllerVector extends ValueNotifier<Matrix4> {
  /// Create an instance of [TransformationControllerVector].
  ///
  /// The [value] defaults to the identity matrix, which corresponds to no
  /// transformation.
  TransformationControllerVector([Matrix4? value]) : super(value ?? Matrix4.identity());

  /// Callback de clamping injecté par [_InteractiveViewerVectorState].
  /// Quand null, [clampTranslate] fait une translation brute sans clamping.
  ClampTranslateFn? _clampTranslate;

  /// Applique une translation à la matrice avec clamping des boundaries.
  ///
  /// Délègue à [_InteractiveViewerVectorState._matrixTranslate] quand un
  /// InteractiveViewerVector est attaché, ce qui garantit que la translation
  /// reste dans les limites du [boundaryMargin] et du viewport.
  /// Sans InteractiveViewerVector attaché, translation brute (fallback).
  Matrix4 clampTranslate(Matrix4 matrix, Offset translation) {
    return _clampTranslate?.call(matrix, translation) ??
        (matrix.clone()..translateByDouble(translation.dx, translation.dy, 0, 1));
  }

  /// Return the scene point at the given viewport point.
  ///
  /// A viewport point is relative to the parent while a scene point is relative
  /// to the child, regardless of transformation. Calling toScene with a
  /// viewport point essentially returns the scene coordinate that lies
  /// underneath the viewport point given the transform.
  ///
  /// The viewport transforms as the inverse of the child (i.e. moving the child
  /// left is equivalent to moving the viewport right).
  ///
  /// This method is often useful when determining where an event on the parent
  /// occurs on the child.
  Offset toScene(Offset viewportPoint) {
    // On viewportPoint, perform the inverse transformation of the scene to get
    // where the point would be in the scene before the transformation.
    final inverseMatrix = Matrix4.inverted(value);
    final untransformed = inverseMatrix.transform3(Vector3(viewportPoint.dx, viewportPoint.dy, 0));
    return Offset(untransformed.x, untransformed.y);
  }
}

// A classification of relevant user gestures. Each contiguous user gesture is
// represented by exactly one _GestureType.
enum _GestureType { pan, scale }

// Given a velocity and drag, calculate the time at which motion will come to
// a stop, within the margin of effectivelyMotionless.
double _getFinalTime(double velocity, double drag, {double effectivelyMotionless = 10}) {
  return math.log(effectivelyMotionless / velocity) / math.log(drag / 100);
}

// Return the translation from the given Matrix4 as an Offset.
Offset _getMatrixTranslation(Matrix4 matrix) {
  final nextTranslation = matrix.getTranslation();
  return Offset(nextTranslation.x, nextTranslation.y);
}

// Transform the four corners of the viewport by the inverse of the given
// matrix. This gives the viewport after the child has been transformed by the
// given matrix. The viewport transforms as the inverse of the child (i.e.
// moving the child left is equivalent to moving the viewport right).
Quad _transformViewport(Matrix4 matrix, Rect viewport) {
  final inverseMatrix = matrix.clone()..invert();
  return Quad.points(
    inverseMatrix.transform3(Vector3(viewport.topLeft.dx, viewport.topLeft.dy, 0)),
    inverseMatrix.transform3(Vector3(viewport.topRight.dx, viewport.topRight.dy, 0)),
    inverseMatrix.transform3(Vector3(viewport.bottomRight.dx, viewport.bottomRight.dy, 0)),
    inverseMatrix.transform3(Vector3(viewport.bottomLeft.dx, viewport.bottomLeft.dy, 0)),
  );
}

// Return the amount that viewport lies outside of boundary. If the viewport
// is completely contained within the boundary (inclusively), then returns
// Offset.zero.
Offset _exceedsBy(Quad boundary, Quad viewport) {
  final viewportPoints = <Vector3>[viewport.point0, viewport.point1, viewport.point2, viewport.point3];
  var largestExcess = Offset.zero;
  for (final point in viewportPoints) {
    final pointInside = InteractiveViewerVector.getNearestPointInside(point, boundary);
    final excess = Offset(pointInside.x - point.x, pointInside.y - point.y);
    if (excess.dx.abs() > largestExcess.dx.abs()) {
      largestExcess = Offset(excess.dx, largestExcess.dy);
    }
    if (excess.dy.abs() > largestExcess.dy.abs()) {
      largestExcess = Offset(largestExcess.dx, excess.dy);
    }
  }

  return _round(largestExcess);
}

// Round the output values. This works around a precision problem where
// values that should have been zero were given as within 10^-10 of zero.
Offset _round(Offset offset) {
  return Offset(double.parse(offset.dx.toStringAsFixed(9)), double.parse(offset.dy.toStringAsFixed(9)));
}

// Align the given offset to the given axis by allowing movement only in the
// axis direction.
Offset _alignAxis(Offset offset, Axis axis) {
  return switch (axis) {
    Axis.horizontal => Offset(offset.dx, 0),
    Axis.vertical => Offset(0, offset.dy),
  };
}

// Given two points, return the axis where the distance between the points is
// greatest. If they are equal, return null.
Axis? _getPanAxis(Offset point1, Offset point2) {
  if (point1 == point2) {
    return null;
  }
  final x = point2.dx - point1.dx;
  final y = point2.dy - point1.dy;
  return x.abs() > y.abs() ? Axis.horizontal : Axis.vertical;
}

/// This enum is used to specify the behavior of the [InteractiveViewerVector] when
/// the user drags the viewport.
enum PanAxis {
  /// The user can only pan the viewport along the horizontal axis.
  horizontal,

  /// The user can only pan the viewport along the vertical axis.
  vertical,

  /// The user can pan the viewport along the horizontal and vertical axes
  /// but not diagonally.
  aligned,

  /// The user can pan the viewport freely in any direction.
  free,
}
