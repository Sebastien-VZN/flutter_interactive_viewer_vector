import "package:flutter/gestures.dart"
    show kPrimaryMouseButton, PointerDeviceKind, PointerDownEvent, PointerMoveEvent, PointerUpEvent;
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:interactive_viewer_vector/interactive_viewer_vector.dart";

/// Test de performance pour le drag de node dans l'app d'exemple.
///
/// PRINCIPE : on compte les rebuilds du widget de node pendant un drag simulé.
///
/// Test 1 (pattern ValueListenableBuilder actuel) : doit ÉCHOUER — prouve la régression.
/// Test 2 (pattern CustomPainter(repaint: notifier) fix) : doit PASSER — prouve le fix.
///
/// Le test 1 est volontairement marqué skip=false et doit échouer pour démontrer
/// que le pattern ValueListenableBuilder rebuild à chaque PointerMove.
/// Après le fix de example/lib/main.dart, le test 1 devient skip=true (régression
/// historique) et le test 2 valide le nouveau pattern.

class DemoNode {
  const DemoNode({required this.position, required this.size, required this.color, required this.label});

  final Offset position;
  final Size size;
  final Color color;
  final String label;
}

/// Compteur global de builds — incrémenté à chaque build de _CountedNodeWidget.
int buildCount = 0;

/// Compteur d'events reçus par le Listener.
int pointerMoveCount = 0;

class _CountedNodeWidget extends StatelessWidget {
  const _CountedNodeWidget({required this.node});

  final DemoNode node;

  @override
  Widget build(BuildContext context) {
    buildCount++;
    return Container(
      width: node.size.width,
      height: node.size.height,
      decoration: BoxDecoration(
        color: node.color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white38, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        node.label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black),
      ),
    );
  }
}

/// Painter qui dessine les nodes — piloté par un ValueNotifier (repaint-only).
class _NodesPainter extends CustomPainter {
  const _NodesPainter(this.nodes);

  final List<DemoNode> nodes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final node in nodes) {
      final rect = Rect.fromLTWH(node.position.dx, node.position.dy, node.size.width, node.size.height);
      final paint = Paint()
        ..color = node.color.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), paint);

      final borderPaint = Paint()
        ..color = Colors.white38
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), borderPaint);
    }
  }

  @override
  bool shouldRepaint(_NodesPainter oldDelegate) => nodes != oldDelegate.nodes;
}

void main() {
  group("pattern ValueListenableBuilder (code actuel — régression)", () {
    testWidgets("dragging a node rebuilds the widget tree (CURRENT BUG)", (tester) async {
      buildCount = 0;
      pointerMoveCount = 0;
      final controller = TransformationControllerVector();

      final nodesNotifier = ValueNotifier<List<DemoNode>>([
        DemoNode(position: const Offset(100, 100), size: const Size(200, 100), color: Colors.yellow, label: "DRAG ME"),
      ]);

      final draggedNodeIndex = ValueNotifier<int?>(null);
      final dragStartScene = ValueNotifier<Offset?>(null);

      void onPointerDown(PointerDownEvent event) {
        if (event.buttons == kPrimaryMouseButton) {
          final scenePoint = event.localPosition;
          final nodes = nodesNotifier.value;
          for (var i = 0; i < nodes.length; i++) {
            final node = nodes[i];
            final nodeRect = Rect.fromLTWH(node.position.dx, node.position.dy, node.size.width, node.size.height);
            if (nodeRect.contains(scenePoint)) {
              dragStartScene.value = scenePoint;
              draggedNodeIndex.value = i;
              return;
            }
          }
        }
      }

      void onPointerMove(PointerMoveEvent event) {
        pointerMoveCount++;
        if (draggedNodeIndex.value != null && event.buttons == kPrimaryMouseButton) {
          final scenePoint = event.localPosition;
          final delta = scenePoint - dragStartScene.value!;
          final nodes = nodesNotifier.value;
          final i = draggedNodeIndex.value!;
          final node = nodes[i];
          final newPosition = node.position + delta;
          final newNodes = List<DemoNode>.from(nodes);
          newNodes[i] = DemoNode(position: newPosition, size: node.size, color: node.color, label: node.label);
          nodesNotifier.value = newNodes;
          dragStartScene.value = scenePoint;
          return;
        }
      }

      void onPointerUp(PointerUpEvent event) {
        dragStartScene.value = null;
        draggedNodeIndex.value = null;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveViewerVector(
              transformationController: controller,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(2000),
              minScale: 0.1,
              maxScale: 3,
              panEnabled: false,
              child: SizedBox(
                width: 2000,
                height: 2000,
                child: Stack(
                  children: [
                    ValueListenableBuilder<List<DemoNode>>(
                      valueListenable: nodesNotifier,
                      builder: (context, nodes, _) {
                        return Stack(
                          children: [
                            for (final node in nodes)
                              Positioned(
                                left: node.position.dx,
                                top: node.position.dy,
                                child: IgnorePointer(child: _CountedNodeWidget(node: node)),
                              ),
                          ],
                        );
                      },
                    ),
                    Positioned.fill(
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: onPointerDown,
                        onPointerMove: onPointerMove,
                        onPointerUp: onPointerUp,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buildsAfterInitial = buildCount;
      expect(buildsAfterInitial, greaterThan(0), reason: "le node doit être construit au moins une fois au démarrage");

      final nodeCenter = const Offset(200, 150);
      final dragDelta = const Offset(5, 5);

      final gesture = await tester.startGesture(nodeCenter, kind: PointerDeviceKind.mouse);
      await tester.pump();

      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(dragDelta);
        await tester.pump();
      }

      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        pointerMoveCount,
        greaterThan(0),
        reason: "le Listener doit recevoir les PointerMove events pendant le drag",
      );

      // Ce test prouve la régression : le node est rebuild à chaque PointerMove.
      expect(
        buildCount,
        greaterThan(buildsAfterInitial),
        reason: "avec ValueListenableBuilder, le node EST rebuild pendant le drag — c'est la régression",
      );

      controller.dispose();
      nodesNotifier.dispose();
      draggedNodeIndex.dispose();
      dragStartScene.dispose();
    });
  });

  group("pattern CustomPainter(repaint: notifier) (fix)", () {
    testWidgets("dragging a node must NOT rebuild the node widget tree", (tester) async {
      buildCount = 0;
      pointerMoveCount = 0;
      final controller = TransformationControllerVector();

      final nodesNotifier = ValueNotifier<List<DemoNode>>([
        DemoNode(position: const Offset(100, 100), size: const Size(200, 100), color: Colors.yellow, label: "DRAG ME"),
      ]);

      final draggedNodeIndex = ValueNotifier<int?>(null);
      final dragStartScene = ValueNotifier<Offset?>(null);

      void onPointerDown(PointerDownEvent event) {
        if (event.buttons == kPrimaryMouseButton) {
          final scenePoint = event.localPosition;
          final nodes = nodesNotifier.value;
          for (var i = 0; i < nodes.length; i++) {
            final node = nodes[i];
            final nodeRect = Rect.fromLTWH(node.position.dx, node.position.dy, node.size.width, node.size.height);
            if (nodeRect.contains(scenePoint)) {
              dragStartScene.value = scenePoint;
              draggedNodeIndex.value = i;
              return;
            }
          }
        }
      }

      void onPointerMove(PointerMoveEvent event) {
        pointerMoveCount++;
        if (draggedNodeIndex.value != null && event.buttons == kPrimaryMouseButton) {
          final scenePoint = event.localPosition;
          final delta = scenePoint - dragStartScene.value!;
          final nodes = nodesNotifier.value;
          final i = draggedNodeIndex.value!;
          final node = nodes[i];
          final newPosition = node.position + delta;
          final newNodes = List<DemoNode>.from(nodes);
          newNodes[i] = DemoNode(position: newPosition, size: node.size, color: node.color, label: node.label);
          nodesNotifier.value = newNodes;
          dragStartScene.value = scenePoint;
          return;
        }
      }

      void onPointerUp(PointerUpEvent event) {
        dragStartScene.value = null;
        draggedNodeIndex.value = null;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveViewerVector(
              transformationController: controller,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(2000),
              minScale: 0.1,
              maxScale: 3,
              panEnabled: false,
              child: SizedBox(
                width: 2000,
                height: 2000,
                child: Stack(
                  children: [
                    // Couche nodes — CustomPainter(repaint: notifier) au lieu de ValueListenableBuilder.
                    // Le repaint est déclenché par le ValueNotifier, PAS de rebuild du widget tree.
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: _NodesPainter(nodesNotifier.value),
                        child: SizedBox(
                          width: 2000,
                          height: 2000,
                          child: Stack(
                            children: [
                              for (final node in nodesNotifier.value)
                                Positioned(
                                  left: node.position.dx,
                                  top: node.position.dy,
                                  child: IgnorePointer(child: _CountedNodeWidget(node: node)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: onPointerDown,
                        onPointerMove: onPointerMove,
                        onPointerUp: onPointerUp,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buildsAfterInitial = buildCount;
      expect(buildsAfterInitial, greaterThan(0), reason: "le node doit être construit au moins une fois au démarrage");

      final nodeCenter = const Offset(200, 150);
      final dragDelta = const Offset(5, 5);

      final gesture = await tester.startGesture(nodeCenter, kind: PointerDeviceKind.mouse);
      await tester.pump();

      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(dragDelta);
        await tester.pump();
      }

      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        pointerMoveCount,
        greaterThan(0),
        reason: "le Listener doit recevoir les PointerMove events pendant le drag",
      );

      // L'assertion clé : le node ne doit PAS être reconstruit pendant le drag.
      expect(
        buildCount,
        buildsAfterInitial,
        reason:
            "le node widget ne doit pas être rebuild pendant le drag — "
            "CustomPainter(repaint: notifier) fait un repaint-only, pas un rebuild",
      );

      controller.dispose();
      nodesNotifier.dispose();
      draggedNodeIndex.dispose();
      dragStartScene.dispose();
    });
  });
}
