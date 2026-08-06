# Changelog

## 0.2.1

- Added `drag_no_rebuild_test.dart` in `example/test/` — performance regression test that counts widget rebuilds during a simulated node drag. Validates that `ValueListenableBuilder` (current pattern) rebuilds the widget tree on every `PointerMove`, while a `CustomPainter(repaint: notifier)` pattern stays at zero rebuilds. CI-compatible, deterministic.
- Reformatted source files with `dart format -l 120` for pub.dev style compliance.

## 0.2.0

- Added `clampTranslate(Matrix4 matrix, Offset translation)` on `TransformationControllerVector`. Delegates to the State's `_matrixTranslate` for full boundary clamping (viewport + boundaryMargin). Falls back to raw `translateByDouble` when no `InteractiveViewerVector` is attached. Consumers can now pan with boundary clamping without duplicating the fork's internal clamping logic.
- Injected `ClampTranslateFn` callback from `_InteractiveViewerVectorState` into the controller via `_clampTranslate` field. Wired in `initState`, re-wired in `didUpdateWidget` (controller swap), cleared in `dispose`.
- Example app rewritten: `StatelessWidget` with `ValueNotifier` for nodes + drag state (zero `setState`). Custom pan via `clampTranslate` (`panEnabled: false`), manual hit-test for node dragging, scroll-to-pan. Node "DRAG ME" (yellow) added for drag testing.
- Added 9 unit tests for `clampTranslate` (`test/clamp_translate_test.dart`): fallback mode (3), boundary clamping (6 — small translation passes, large translation clamped, scale preserved, low-scale sync, anti-drift over 50 iterations).
- Example integration tests updated: pan/zoom scenario, node drag (clampTranslate does not steal gesture), low-scale boundary respect.

## 0.1.1

- Removed all dead rotation gesture code from the SDK fork (unused `_rotateEnabled`, `_matrixRotate`, `_getAxisAlignedBoundingBoxWithRotation`, `_GestureType.rotate`, two TODOs referencing flutter/flutter#57698). Rotation was designed for geographic map use cases, never completed upstream, and irrelevant for this package's target use cases.
- CI/CD pipeline added (GitHub Actions): format check (line 120), analyze, unit + widget tests, builds for Android, Linux, Windows, macOS, iOS, and auto-release on main push.

## 0.1.0

- Initial public release.
- Fork of the Flutter SDK `InteractiveViewer` with direct `RenderTransform` updates (`markNeedsPaint`) instead of `setState` during pan/zoom.
- Same public API as the SDK widget, renamed: `InteractiveViewerVector`, `TransformationControllerVector`, `InteractiveViewerVectorWidgetBuilder`.
- Unit tests (geometry helpers, controller, constructor assertions), widget tests (no-rebuild guarantee, gestures, builder constructor) and an example app with integration test.
- Native platforms only: Android, iOS, macOS, Windows, Linux.
