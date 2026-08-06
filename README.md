# interactive_viewer_vector

A drop-in replacement for Flutter's `InteractiveViewer` that eliminates widget rebuilds during pan and zoom — zero `setState`, zero rebuilds, just paint.

- **pub.dev:** https://pub.dev/packages/interactive_viewer_vector
- **Repository:** https://github.com/Sebastien-VZN/flutter_interactive_viewer_vector

## The problem

When you pan or zoom a standard `InteractiveViewer`, Flutter rebuilds the **entire widget subtree on every single frame** of the gesture. Every `CustomPaint`, every `RepaintBoundary`, every child — all of it is rebuilt and re-laid-out dozens of times per second. On a heavy canvas (a mindmap with hundreds of nodes, a complex editor, a painted dashboard) this rebuild storm shows up as **visible jank and dropped frames on mobile**.

This is a known, long-standing Flutter framework limitation ([#78543](https://github.com/flutter/flutter/issues/78543), [#72066](https://github.com/flutter/flutter/issues/72066), [#118434](https://github.com/flutter/flutter/issues/118434), [#129150](https://github.com/flutter/flutter/issues/129150), [#60550](https://github.com/flutter/flutter/issues/60550)). The stock `InteractiveViewer` subscribes to its `TransformationController` and calls `setState` on every transformation change. It has not been fixed upstream because the fix is architectural.

## The fix

A single method change: `_handleTransformation` no longer calls `setState`. It writes the matrix straight to the `RenderTransform` via a `GlobalKey`, triggering `markNeedsPaint()` only. The widget tree is untouched during interactions.

```
Stock InteractiveViewer:   matrix change -> setState -> build() whole subtree -> layout/paint
InteractiveViewerVector:   matrix change -> RenderTransform.transform = m   -> markNeedsPaint only
```

The API, gesture behavior, and constructor parameters are unchanged.

## Screenshots

| Android | Desktop |
|---|---|
| ![Android demo](https://raw.githubusercontent.com/Sebastien-VZN/flutter_interactive_viewer_vector/main/doc/screen_android.jpg) | ![Desktop demo](https://raw.githubusercontent.com/Sebastien-VZN/flutter_interactive_viewer_vector/main/doc/screen_desktop.jpg) |

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

Programmatic transforms work as usual:

```dart
_controller.value = Matrix4.identity();
```

All constructor variants are supported: `InteractiveViewerVector(...)`, `InteractiveViewerVector.builder(...)`, `panEnabled`, `scaleEnabled`, `panAxis`, `trackpadScrollCausesScale`, `scaleFactor`, `alignment`, `clipBehavior`, etc.

## Tests

Widget tests assert that a child with a build counter is built **exactly once** across 10 consecutive transformation updates. With the stock widget, each update triggers a build.

```bash
flutter test                              # unit + widget tests
cd example && flutter test integration_test  # integration (device required)
```

For the real-device performance testing protocol (DevTools profiling, frame timing), see [README_GH.md](README_GH.md).

## Platforms

Native only — CanvasKit/HTML rendering on the web has its own performance characteristics and negates the benefit.

| Platform | Status |
|---|---|
| Android | Manually validated |
| Linux | Manually validated |
| Windows | Manually validated |
| iOS | CI-compiled, no runtime tests |
| macOS | CI-compiled, no runtime tests |

## Origin & license

Forked from the Flutter SDK (`packages/flutter/lib/src/widgets/interactive_viewer.dart`, 1300+ lines) with a single behavioral change in `_handleTransformation`. BSD 3-Clause license, copyright notice of The Flutter Authors preserved inside [LICENSE](LICENSE).

---

For detailed technical notes, contribution guidelines, and the performance testing protocol, see [README_GH.md](README_GH.md).
