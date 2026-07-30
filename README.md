# interactive_viewer_vector

[![pub package](https://img.shields.io/pub/v/interactive_viewer_vector.svg)](https://pub.dev/packages/interactive_viewer_vector)
[![pub points](https://img.shields.io/pub/points/interactive_viewer_vector.svg)](https://pub.dev/packages/interactive_viewer_vector)
[![GitHub](https://img.shields.io/badge/repo-GitHub-181717?logo=github)](https://github.com/Sebastien-VZN/flutter_interactive_viewer_vector)

A fork of the Flutter SDK `InteractiveViewer` that updates the `RenderTransform` directly (`markNeedsPaint`) instead of calling `setState` on every pan/zoom frame — zero widget rebuilds during interactions.

- **pub.dev:** https://pub.dev/packages/interactive_viewer_vector
- **Repository:** https://github.com/Sebastien-VZN/flutter_interactive_viewer_vector

## The problem

When you pan or zoom a standard `InteractiveViewer`, Flutter rebuilds the **entire widget subtree inside it on every single frame** of the gesture. Every `CustomPaint`, every `RepaintBoundary`, every child widget — all of it is rebuilt and re-laid-out, dozens of times per second, for as long as your finger is on the screen.

On a small widget this is invisible. On a heavy canvas — a mindmap with hundreds of nodes, an editor with a complex layer tree, a dashboard full of painted elements — this rebuild storm shows up as **visible jank and dropped frames on mobile devices**. The interaction feels laggy, and the bigger your canvas, the worse it gets.

### Why this happens (technical)

The stock `InteractiveViewer` subscribes to its `TransformationController` (a `ValueNotifier<Matrix4>`) and calls `setState(() {})` on every transformation change. During a pan or pinch zoom, this rebuilds the entire widget subtree on every frame — all `CustomPaint` widgets, `RepaintBoundary` children, and everything else in the subtree.

This is a known, long-standing Flutter framework limitation (issues [#78543](https://github.com/flutter/flutter/issues/78543), [#72066](https://github.com/flutter/flutter/issues/72066), [#118434](https://github.com/flutter/flutter/issues/118434), [#129150](https://github.com/flutter/flutter/issues/129150), [#60550](https://github.com/flutter/flutter/issues/60550)). It has not been fixed upstream because the fix is architectural — the widget would need to be restructured to avoid `setState`.

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

## Maintenance & contribution

I'm not a full-time maintainer. I built this fork for my own project ([Axomind](https://github.com/Sebastien-VZN)), where it drives a heavy mindmap canvas, and I publish it in case it's useful to others working on similar interactive canvases.

What that means in practice:

- **Bug reports** — welcome. Open a [GitHub Issue](https://github.com/Sebastien-VZN/flutter_interactive_viewer_vector/issues) with a repro and I'll look into it. Bugs that break the core pan/zoom behavior or regress the no-rebuild guarantee are the priority.
- **Feature requests** — I'll consider them only when they're relevant to my own use case: mindmaps, canvases, and interactive content of that kind. If a requested feature fits that scope, I'm happy to discuss it.
- **Out-of-scope features** — if you need behavior aimed at a different kind of app (geographic maps, document viewers, exotic gesture modes, etc.), the cleanest path is to fork the project. The codebase is small and the fork's single behavioral change is isolated, so adapting it to your needs should be straightforward.

This isn't a polished open-source product with a roadmap and a team behind it — it's a focused fix that I use in production, shared publicly. Clear expectations on both sides keep it sustainable.

## Origin & license

Forked from the Flutter SDK (`packages/flutter/lib/src/widgets/interactive_viewer.dart`, 1300+ lines) with a single behavioral change in `_handleTransformation`. BSD 3-Clause license, copyright notice of The Flutter Authors preserved inside [LICENSE](LICENSE).