import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:interactive_viewer_vector/interactive_viewer_vector.dart";

void main() {
  runApp(const VectorDemoApp());
}

class VectorDemoApp extends StatelessWidget {
  const VectorDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "InteractiveViewerVector Demo",
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const VectorDemoPage(),
    );
  }
}

/// Simple node placed on the demo canvas.
class DemoNode {
  const DemoNode({required this.position, required this.size, required this.color, required this.label});

  final Offset position;
  final Size size;
  final Color color;
  final String label;
}

class VectorDemoPage extends StatelessWidget {
  const VectorDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _VectorDemoBody();
  }
}

class _VectorDemoBody extends StatelessWidget {
  _VectorDemoBody();

  static const double _canvasSize = 2000;

  final TransformationControllerVector _controller = TransformationControllerVector();

  /// Nodes — ValueNotifier pour déclencher le rebuild des nodes + lignes sans setState.
  final ValueNotifier<List<DemoNode>> _nodesNotifier = ValueNotifier<List<DemoNode>>([
    DemoNode(position: const Offset(300, 250), size: const Size(180, 100), color: Colors.teal, label: "Node A"),
    DemoNode(position: const Offset(900, 200), size: const Size(220, 120), color: Colors.deepOrange, label: "Node B"),
    DemoNode(position: const Offset(600, 700), size: const Size(200, 140), color: Colors.indigo, label: "Node C"),
    DemoNode(position: const Offset(1300, 500), size: const Size(160, 160), color: Colors.purple, label: "Node D"),
    DemoNode(position: const Offset(1100, 1100), size: const Size(240, 100), color: Colors.green, label: "Node E"),
    DemoNode(position: const Offset(250, 1200), size: const Size(200, 180), color: Colors.redAccent, label: "Node F"),
    DemoNode(position: const Offset(1500, 1400), size: const Size(180, 140), color: Colors.amber, label: "Node G"),
    // Node de test — visuellement distinct pour tester le drag.
    DemoNode(position: const Offset(850, 600), size: const Size(200, 100), color: Colors.yellow, label: "DRAG ME"),
  ]);

  /// État de drag — ValueNotifier pour éviter tout setState.
  final ValueNotifier<int?> _draggedNodeIndex = ValueNotifier<int?>(null);

  /// Position de départ du drag (coordonnées canvas) — ValueNotifier pour rester immutable.
  final ValueNotifier<Offset?> _dragStartScene = ValueNotifier<Offset?>(null);

  void _resetTransform() {
    _controller.value = Matrix4.identity();
  }

  /// Pan custom via clampTranslate — reproduit le pattern d'Axomind.
  /// panEnabled: false sur l'InteractiveViewerVector, on gère le pan nous-mêmes
  /// avec clampTranslate pour bénéficier du boundary clamping du fork.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final scale = _controller.value.getMaxScaleOnAxis();
      final translation = Offset(-event.scrollDelta.dx / scale, -event.scrollDelta.dy / scale);
      _controller.value = _controller.clampTranslate(_controller.value, translation);
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons == kPrimaryMouseButton) {
      // event.localPosition est déjà en coordonnées canvas car le Listener
      // est à l'intérieur du Transform de l'InteractiveViewerVector.
      final scenePoint = event.localPosition;
      final nodes = _nodesNotifier.value;
      for (var i = 0; i < nodes.length; i++) {
        final node = nodes[i];
        final nodeRect = Rect.fromLTWH(node.position.dx, node.position.dy, node.size.width, node.size.height);
        if (nodeRect.contains(scenePoint)) {
          _dragStartScene.value = scenePoint;
          _draggedNodeIndex.value = i;
          return;
        }
      }
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_draggedNodeIndex.value != null && event.buttons == kPrimaryMouseButton) {
      final scenePoint = event.localPosition;
      final delta = scenePoint - _dragStartScene.value!;
      final nodes = _nodesNotifier.value;
      final i = _draggedNodeIndex.value!;
      final node = nodes[i];
      final newPosition = node.position + delta;
      final newNodes = List<DemoNode>.from(nodes);
      newNodes[i] = DemoNode(position: newPosition, size: node.size, color: node.color, label: node.label);
      _nodesNotifier.value = newNodes;
      _dragStartScene.value = scenePoint;
      return;
    }

    // Pan du canvas via clampTranslate (clic gauche hors node).
    if (event.buttons == kPrimaryMouseButton && _draggedNodeIndex.value == null) {
      final scale = _controller.value.getMaxScaleOnAxis();
      final translation = Offset(event.delta.dx / scale, event.delta.dy / scale);
      _controller.value = _controller.clampTranslate(_controller.value, translation);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _dragStartScene.value = null;
    _draggedNodeIndex.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("InteractiveViewerVector"),
        actions: [IconButton(icon: const Icon(Icons.center_focus_strong), tooltip: "Reset transform", onPressed: _resetTransform)],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return InteractiveViewerVector(
            transformationController: _controller,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(_canvasSize),
            minScale: 0.1,
            maxScale: 3,
            // Pan natif désactivé — on gère le pan via clampTranslate dans le
            // Listener ci-dessous, pour reproduire le pattern d'Axomind.
            panEnabled: false,
            child: _buildCanvasContent(),
          );
        },
      ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          "Drag a node to move it — drag empty space to pan (clampTranslate) — scroll to zoom.\n"
          "No setState: nodes + lines are driven by ValueNotifiers.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildCanvasContent() {
    return SizedBox(
      width: _canvasSize,
      height: _canvasSize,
      child: Stack(
        children: [
          // Couche 1 : grille
          const Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          // Couche 2 : lignes de connexion + nodes — rebuild via ValueNotifier, pas de setState.
          ValueListenableBuilder<List<DemoNode>>(
            valueListenable: _nodesNotifier,
            builder: (context, nodes, _) {
              return Stack(
                children: [
                  CustomPaint(size: const Size(_canvasSize, _canvasSize), painter: _LinksPainter(nodes)),
                  for (final node in nodes)
                    Positioned(
                      left: node.position.dx,
                      top: node.position.dy,
                      child: IgnorePointer(child: _DemoNodeWidget(node: node)),
                    ),
                ],
              );
            },
          ),
          // Couche 3 : layer interactive (pan + drag nodes)
          // Placée AU-DESSUS des nodes pour capter tous les pointers.
          // Le hit-test des nodes est fait manuellement dans _onPointerDown.
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerSignal: _onPointerSignal,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoNodeWidget extends StatelessWidget {
  const _DemoNodeWidget({required this.node});

  final DemoNode node;

  @override
  Widget build(BuildContext context) {
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

class _GridPainter extends CustomPainter {
  const _GridPainter();

  static const double _step = 100;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += _step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += _step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

class _LinksPainter extends CustomPainter {
  const _LinksPainter(this.nodes);

  final List<DemoNode> nodes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < nodes.length - 1; i++) {
      final a = nodes[i].position + nodes[i].size.center(Offset.zero);
      final b = nodes[i + 1].position + nodes[i + 1].size.center(Offset.zero);
      canvas.drawLine(a, b, paint);
    }
  }

  @override
  bool shouldRepaint(_LinksPainter oldDelegate) => nodes != oldDelegate.nodes;
}
