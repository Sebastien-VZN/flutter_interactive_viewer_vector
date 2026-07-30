import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:interactive_viewer_vector/interactive_viewer_vector.dart";

/// Tests pour la méthode [TransformationControllerVector.clampTranslate].
///
/// clampTranslate délègue au _matrixTranslate du State quand un
/// InteractiveViewerVector est attaché (boundary clamping complet), et fait
/// une translation brute sinon (fallback).
void main() {
  group("clampTranslate sans InteractiveViewerVector attaché (fallback)", () {
    test("translation brute sans clamping — identique à translateByDouble", () {
      final controller = TransformationControllerVector();
      final matrix = Matrix4.identity();
      final result = controller.clampTranslate(matrix, const Offset(100, 50));

      // La translation doit être appliquée telle quelle.
      final translation = result.getTranslation();
      expect(translation.x, closeTo(100, 1e-9));
      expect(translation.y, closeTo(50, 1e-9));
      controller.dispose();
    });

    test("translation négative brute", () {
      final controller = TransformationControllerVector();
      final matrix = Matrix4.identity();
      final result = controller.clampTranslate(matrix, const Offset(-200, -300));

      final translation = result.getTranslation();
      expect(translation.x, closeTo(-200, 1e-9));
      expect(translation.y, closeTo(-300, 1e-9));
      controller.dispose();
    });

    test("translation zero retourne une copie identique", () {
      final controller = TransformationControllerVector();
      final matrix = Matrix4.identity()..translateByDouble(50, 50, 0, 1);
      final result = controller.clampTranslate(matrix, Offset.zero);

      // _matrixTranslate retourne matrix.clone() pour Offset.zero, et le
      // fallback fait aussi un clone avec translateByDouble(0,0,0,1) qui ne
      // change rien. Les deux chemins doivent préserver la translation existante.
      final translation = result.getTranslation();
      expect(translation.x, closeTo(50, 1e-9));
      expect(translation.y, closeTo(50, 1e-9));
      controller.dispose();
    });
  });

  group("clampTranslate avec InteractiveViewerVector attaché (boundary clamping)", () {
    testWidgets("petite translation dans les boundaries passe sans clamp", (tester) async {
      final controller = TransformationControllerVector();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: InteractiveViewerVector(
                transformationController: controller,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(2000),
                minScale: 0.1,
                maxScale: 3,
                panEnabled: false,
                child: const SizedBox(width: 2000, height: 2000),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Translation modeste — doit passer entièrement.
      final matrix = Matrix4.identity();
      final result = controller.clampTranslate(matrix, const Offset(100, 80));

      final translation = result.getTranslation();
      expect(translation.x, closeTo(100, 1e-9));
      expect(translation.y, closeTo(80, 1e-9));
      controller.dispose();
    });

    testWidgets("translation énorme est clampée aux boundaries", (tester) async {
      final controller = TransformationControllerVector();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: InteractiveViewerVector(
                transformationController: controller,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(500),
                minScale: 0.1,
                maxScale: 3,
                panEnabled: false,
                child: const SizedBox(width: 2000, height: 2000),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Translation énorme qui déborde largement les boundaries.
      // _boundaryRect = childSize (2000) + boundaryMargin (500 de chaque côté) = 3000x3000.
      // Le viewport fait 800x600. Une translation de 10000 doit être clampée.
      final matrix = Matrix4.identity();
      final result = controller.clampTranslate(matrix, const Offset(100000, 100000));

      // La translation résultante doit être bien inférieure à 100000.
      final translation = result.getTranslation();
      expect(translation.x, lessThan(100000));
      expect(translation.y, lessThan(100000));

      // Le clamp garde le viewport dans les boundaries : la translation ne
      // peut pas dépasser boundaryRect.right - viewport.width = 3000 - 800 = 2200.
      expect(translation.x, lessThanOrEqualTo(2200));
      expect(translation.y, lessThanOrEqualTo(2400));
      controller.dispose();
    });

    testWidgets("clampTranslate préserve le scale de la matrice", (tester) async {
      final controller = TransformationControllerVector();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: InteractiveViewerVector(
                transformationController: controller,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(2000),
                minScale: 0.1,
                maxScale: 3,
                panEnabled: false,
                child: const SizedBox(width: 2000, height: 2000),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Matrice avec un scale de 0.5 (simule un dézoom).
      final matrix = Matrix4.identity()..scaleByDouble(0.5, 0.5, 0.5, 1);
      final result = controller.clampTranslate(matrix, const Offset(100, 100));

      // Le scale doit être préservé par la translation.
      expect(result.getMaxScaleOnAxis(), closeTo(0.5, 1e-9));
      controller.dispose();
    });

    testWidgets("clampTranslate avec scale 0.1 (minScale) ne désynchronise pas", (tester) async {
      final controller = TransformationControllerVector();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: InteractiveViewerVector(
                transformationController: controller,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(2000),
                minScale: 0.1,
                maxScale: 3,
                panEnabled: false,
                child: const SizedBox(width: 2000, height: 2000),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // À scale 0.1, un delta écran de 100px = 1000px en canvas.
      // clampTranslate doit amplifier puis clamper — pas de désynchronisation.
      final matrix = Matrix4.identity()..scaleByDouble(0.1, 0.1, 0.1, 1);
      final result = controller.clampTranslate(matrix, const Offset(1000, 1000));

      // Le scale doit rester 0.1 (la translation ne change pas le scale).
      expect(result.getMaxScaleOnAxis(), closeTo(0.1, 1e-9));

      // La translation doit être clampée (pas de drift infini).
      final translation = result.getTranslation();
      expect(translation.x.isFinite, isTrue);
      expect(translation.y.isFinite, isTrue);
      expect(translation.x.abs(), lessThan(100000));
      expect(translation.y.abs(), lessThan(100000));
      controller.dispose();
    });

    testWidgets("plusieurs clampTranslate successifs ne dérivent pas", (tester) async {
      final controller = TransformationControllerVector();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: InteractiveViewerVector(
                transformationController: controller,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(500),
                minScale: 0.1,
                maxScale: 3,
                panEnabled: false,
                child: const SizedBox(width: 2000, height: 2000),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simule 50 frames de pan à scale 0.1 avec un delta de 50px par frame.
      // Sans clamping, la matrice dériverait à 25000px de translation.
      var matrix = Matrix4.identity()..scaleByDouble(0.1, 0.1, 0.1, 1);
      for (var i = 0; i < 50; i++) {
        matrix = controller.clampTranslate(matrix, const Offset(500, 500));
      }

      final translation = matrix.getTranslation();
      // La translation cumulée doit être clampée — bien inférieure à 25000.
      expect(translation.x.abs(), lessThan(25000));
      expect(translation.y.abs(), lessThan(25000));
      // Le scale doit rester 0.1.
      expect(matrix.getMaxScaleOnAxis(), closeTo(0.1, 1e-9));
      controller.dispose();
    });
  });
}
