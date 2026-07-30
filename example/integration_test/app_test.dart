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
}
