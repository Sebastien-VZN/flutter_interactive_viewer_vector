# Changelog

## 0.1.1

- Removed all dead rotation gesture code from the SDK fork (unused `_rotateEnabled`, `_matrixRotate`, `_getAxisAlignedBoundingBoxWithRotation`, `_GestureType.rotate`, two TODOs referencing flutter/flutter#57698). Rotation was designed for geographic map use cases, never completed upstream, and irrelevant for this package's target use cases.
- CI/CD pipeline added (GitHub Actions): format check (line 120), analyze, unit + widget tests, builds for Android, Linux, Windows, macOS, iOS, and auto-release on main push.

## 0.1.0

- Initial public release.
- Fork of the Flutter SDK `InteractiveViewer` with direct `RenderTransform` updates (`markNeedsPaint`) instead of `setState` during pan/zoom.
- Same public API as the SDK widget, renamed: `InteractiveViewerVector`, `TransformationControllerVector`, `InteractiveViewerVectorWidgetBuilder`.
- Unit tests (geometry helpers, controller, constructor assertions), widget tests (no-rebuild guarantee, gestures, builder constructor) and an example app with integration test.
- Native platforms only: Android, iOS, macOS, Windows, Linux.
