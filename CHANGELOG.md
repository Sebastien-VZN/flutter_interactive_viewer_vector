# Changelog

## 0.1.0

- Initial public release.
- Fork of the Flutter SDK `InteractiveViewer` with direct `RenderTransform` updates (`markNeedsPaint`) instead of `setState` during pan/zoom.
- Same public API as the SDK widget, renamed: `InteractiveViewerVector`, `TransformationControllerVector`, `InteractiveViewerVectorWidgetBuilder`.
- Unit tests (geometry helpers, controller, constructor assertions), widget tests (no-rebuild guarantee, gestures, builder constructor) and an example app with integration test.
- Native platforms only: Android, iOS, macOS, Windows, Linux.
