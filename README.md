# interactive_viewer_vector

A fork of the Flutter SDK `InteractiveViewer` that updates the `RenderTransform` directly (`markNeedsPaint`) instead of calling `setState` on every pan/zoom frame — zero widget rebuilds during interactions.

## The problem

The stock `InteractiveViewer` subscribes to its `TransformationController` (a `ValueNotifier<Matrix4>`) and calls `setState(() {})` on every transformation change. During a pan or pinch zoom, this rebuilds the entire widget subtree on every frame — all `CustomPaint` widgets, `RepaintBoundary` children, and everything else in the subtree.

On heavy canvases (mindmaps, editors, dashboards with hundreds of painted elements), this causes visible jank on mobile devices.

This is a known, long-standing Flutter framework limitation (issues [#78543](https://github.com/flutter/flutter/issues/78543), [#72066](https://github.com/flutter/flutter/issues/72066), [#118434](https://github.com/flutter/flutter/issues/118434), [#129150](https://github.com/flutter/flutter/issues/129150), [#60550](https://github.com/flutter/flutter/issues/60550)). It has not been fixed upstream because the fix is architectural — the widget would need to be restructured to avoid setState.

## The fix

The fork replaces only the `_handleTransformation` method. Instead of calling `setState`, it pushes the new matrix directly to the `RenderTransform` via a `GlobalKey`. This triggers `markNeedsPaint()` only — the widget tree is never rebuilt during an interaction.

```
Stock InteractiveViewer:   matrix change -> setState -> build() whole subtree -> layout/paint
InteractiveViewerVector:   matrix change -> RenderTransform.transform = m   -> markNeedsPaint only
```

The API, gesture behavior, and constructor parameters are unchanged.

## Real-world result

Validated on an Oppo Find X2 with a complex mindmap canvas: 60fps stable during pan and zoom, matching Mindmeister's performance. The previous LOD (Level of Detail) mitigation that was used to hide jank was removed after this fork made it unnecessary.

## Rotation code removal

The stock SDK contains unfinished rotation gesture support: a hardcoded `_rotateEnabled = false`, a `_matrixRotate` method, rotation-aware boundary clamping, a `_GestureType.rotate` enum value, and two TODOs referencing [flutter/flutter#57698](https://github.com/flutter/flutter/issues/57698) (open since 2020). This was designed for geographic map use cases. It was never completed upstream and is irrelevant for this package's target use cases (mindmaps, canvases, image viewers). All of this dead code was removed from the fork to simplify the codebase.

## Platforms

Native only — CanvasKit/HTML rendering on the web has its own performance characteristics and negates the benefit:

- Android
- iOS
- macOS
- Windows
- Linux

## Usage

Replace `InteractiveViewer` with `InteractiveViewerVector` and `TransformationController` with `TransformationControllerVector` — same parameters, same callbacks:

```dart
final _controller = TransformationControllerVector();

InteractiveViewerVector(
  transformationController: _controller,
  constrained: false,
  boundaryMargin: const EdgeInsets.all(2000),
  minScale: 0.1,
  maxScale: 3,
  onInteractionEnd: (details) { /* ... */ },
  child: MyHugeCanvas(),
)
```

Programmatic transforms (e.g. reset button) work as usual:

```dart
_controller.value = Matrix4.identity();
```

All constructor variants are supported: `InteractiveViewerVector(...)`, `InteractiveViewerVector.builder(...)`, `panEnabled`, `scaleEnabled`, `panAxis`, `trackpadScrollCausesScale`, `scaleFactor`, `alignment`, `clipBehavior`, etc.

## Tests

The package widget tests assert that a child widget with a build counter is built **exactly once** across 10 consecutive transformation updates (pan and scale). With the stock widget, each update triggers a build. This test is the proof that the fork works.

```bash
flutter test
```

The `example/` app displays a live "canvas builds" counter in its app bar: it stays flat while you pan/zoom.

```bash
flutter test                              # unit + widget tests
cd example && flutter test integration_test  # integration (device required)
```

## Origin & license

Forked from the Flutter SDK (`packages/flutter/lib/src/widgets/interactive_viewer.dart`, 1300+ lines) with a single behavioral change in `_handleTransformation`. BSD 3-Clause license, copyright notice of The Flutter Authors preserved inside [LICENSE](LICENSE).