import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:interactive_viewer_vector/interactive_viewer_vector.dart";

/// The core value of this package: changing the transformation must NOT
/// rebuild the child widget tree.
///
/// We count builds of the child, drive several transformation updates, and
/// assert the child was built exactly once. With the stock SDK
/// InteractiveViewer (setState in _handleTransformation), each update would
/// trigger an extra build.
class _BuildCounter extends StatefulWidget {
  const _BuildCounter({required this.onBuild});

  final VoidCallback onBuild;

  @override
  State<_BuildCounter> createState() => _BuildCounterState();
}

class _BuildCounterState extends State<_BuildCounter> {
  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    return const SizedBox(width: 500, height: 500);
  }
}

void main() {
  testWidgets("pan does not rebuild the child widget tree", (tester) async {
    var buildCount = 0;
    final controller = TransformationControllerVector();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveViewerVector(
            transformationController: controller,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            child: _BuildCounter(onBuild: () => buildCount++),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final buildsAfterInitial = buildCount;

    // Simulate a pan: 10 transformation updates like a 10-frame drag.
    for (var i = 1; i <= 10; i++) {
      controller.value = Matrix4.identity()..translateByDouble(i * 5.0, 0, 0, 1);
      await tester.pump();
    }

    expect(
      buildCount,
      buildsAfterInitial,
      reason: "the child must not be rebuilt during pan — only the RenderTransform repaints",
    );
  });

  testWidgets("scale does not rebuild the child widget tree", (tester) async {
    var buildCount = 0;
    final controller = TransformationControllerVector();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveViewerVector(
            transformationController: controller,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: 0.1,
            maxScale: 4,
            child: _BuildCounter(onBuild: () => buildCount++),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final buildsAfterInitial = buildCount;

    for (var i = 1; i <= 10; i++) {
      controller.value = Matrix4.identity()..scaleByDouble(1 + i * 0.1, 1 + i * 0.1, 1, 1);
      await tester.pump();
    }

    expect(buildCount, buildsAfterInitial);
  });

  testWidgets("a real drag gesture pans the content (RenderTransform matrix changes)", (tester) async {
    final controller = TransformationControllerVector();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveViewerVector(
            transformationController: controller,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            child: const SizedBox(width: 1000, height: 1000),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.value, Matrix4.identity());

    await tester.drag(find.byType(InteractiveViewerVector), const Offset(100, 50));
    await tester.pumpAndSettle();

    final translation = controller.value.getTranslation();
    expect(translation.x, isNot(0));
  });

  testWidgets("builder constructor works and exposes the viewport quad", (tester) async {
    var built = false;
    final controller = TransformationControllerVector();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: InteractiveViewerVector.builder(
              transformationController: controller,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              builder: (context, viewport) {
                built = true;
                expect(viewport, isNotNull);
                return const SizedBox(width: 2000, height: 2000);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(built, isTrue);
  });
}
