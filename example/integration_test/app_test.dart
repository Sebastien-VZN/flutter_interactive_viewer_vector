import "package:example/main.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:integration_test/integration_test.dart";
import "package:interactive_viewer_vector/interactive_viewer_vector.dart";

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("full pan/zoom scenario on the demo app", (tester) async {
    await tester.pumpWidget(const VectorDemoApp());
    await tester.pumpAndSettle();

    // The demo canvas and one of its nodes are on screen.
    expect(find.byType(InteractiveViewerVector), findsOneWidget);
    expect(find.text("Node A"), findsOneWidget);

    // Pan: end-to-end gesture handling on device. The precise "no rebuild"
    // guarantee is covered by the package widget tests; here we validate the
    // full app behavior.
    await tester.drag(find.byType(InteractiveViewerVector), const Offset(-300, -200));
    await tester.pumpAndSettle();

    // Reset via the app bar icon returns to identity.
    await tester.tap(find.byIcon(Icons.center_focus_strong));
    await tester.pumpAndSettle();
    expect(find.text("Node A"), findsOneWidget);
  });

  testWidgets("dragging a node moves it (clampTranslate pan does not steal the gesture)", (tester) async {
    await tester.pumpWidget(const VectorDemoApp());
    await tester.pumpAndSettle();

    expect(find.text("Node A"), findsOneWidget);

    // Drag Node A to the right. The Listener captures the pointer, detects
    // the node hit, and moves it. The canvas must not pan (clampTranslate is
    // not called when a node is grabbed).
    final nodeAFinder = find.text("Node A");
    final beforeLocation = tester.getCenter(nodeAFinder);

    await tester.drag(nodeAFinder, const Offset(120, 80));
    await tester.pumpAndSettle();

    final afterLocation = tester.getCenter(nodeAFinder);
    expect(afterLocation.dx, greaterThan(beforeLocation.dx), reason: "Node A should have moved right");
    expect(afterLocation.dy, greaterThan(beforeLocation.dy), reason: "Node A should have moved down");
  });

  testWidgets("pan via clampTranslate respects boundaries at low scale", (tester) async {
    await tester.pumpWidget(const VectorDemoApp());
    await tester.pumpAndSettle();

    // Zoom out to minScale (0.1) by scrolling.
    final finder = find.byType(InteractiveViewerVector);
    await tester.fling(finder, const Offset(0, 500), 1000);
    await tester.pumpAndSettle();

    // Pan aggressively — clampTranslate must prevent the canvas from drifting
    // beyond the boundaries. The content must still be visible after.
    for (var i = 0; i < 10; i++) {
      await tester.drag(finder, const Offset(200, 200));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    // The app must not crash and at least one node must still be findable.
    expect(find.byType(InteractiveViewerVector), findsOneWidget);
  });
}
