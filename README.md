# interactive_viewer_vector

A drop-in replacement for the Flutter SDK `InteractiveViewer` that updates the `RenderTransform` **directly** (`markNeedsPaint`) instead of calling `setState` on every pan/zoom frame.

## Why?

The stock `InteractiveViewer` subscribes to its `TransformationController` (a `ValueNotifier<Matrix4>`) and calls `setState(() {})` on every transformation change (see `interactive_viewer.dart` in the Flutter SDK). During a pan or pinch zoom, this rebuilds the **entire widget subtree** on every frame — including all `CustomPaint` widgets, `RepaintBoundary` children, etc.

On heavy canvases (mindmaps, editors, dashboards with hundreds of painted elements), this causes visible jank on mobile devices.

`InteractiveViewerVector` keeps the exact same API and gesture behavior, but pushes matrix updates straight to the `RenderTransform`, which only schedules a repaint — **zero widget rebuilds during interactions**.

```
Stock InteractiveViewer:   matrix change -> setState -> build() whole subtree -> layout/paint
InteractiveViewerVector:   matrix change -> RenderTransform.transform = m   -> markNeedsPaint only
```

This is a known, long-standing Flutter framework limitation (issues [#78543](https://github.com/flutter/flutter/issues/78543), [#72066](https://github.com/flutter/flutter/issues/72066), [#118434](https://github.com/flutter/flutter/issues/118434), [#129150](https://github.com/flutter/flutter/issues/129150), [#60550](https://github.com/flutter/flutter/issues/60550)) — never fixed upstream because it is architectural. This package is the fix as a fork.

## Platforms

Native only — CanvasKit/HTML rendering on the web negates the benefit and suffers from its own performance characteristics:

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

## Proving the difference

The package widget tests assert that a child widget with a build counter is built **exactly once** across 10 consecutive transformation updates (pan and scale). With the stock widget, each update triggers a build.

Run them:

```bash
flutter test
```

The `example/` app displays a live "canvas builds" counter in its app bar: it stays flat while you pan/zoom.

## Test

```bash
flutter test                              # unit + widget tests
cd example && flutter test integration_test  # integration (device required)
```

## Origin & license

Forked from the Flutter SDK (`packages/flutter/lib/src/widgets/interactive_viewer.dart`, 1300+ lines) with a single behavioral change in `_handleTransformation`. BSD 3-Clause license, copyright notice of The Flutter Authors preserved inside [LICENSE](LICENSE).
