/// Fork of the Flutter SDK InteractiveViewer that updates the
/// RenderTransform directly (markNeedsPaint) instead of calling setState
/// on every pan/zoom frame — no widget tree rebuild during interactions.
library;

export "src/interactive_viewer_vector.dart";
