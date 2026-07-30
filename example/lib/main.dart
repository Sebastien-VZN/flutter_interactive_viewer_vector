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

class VectorDemoPage extends StatefulWidget {
  const VectorDemoPage({super.key});

  @override
  State<VectorDemoPage> createState() => _VectorDemoPageState();
}

class _VectorDemoPageState extends State<VectorDemoPage> {
  final TransformationControllerVector _controller = TransformationControllerVector();

  /// Number of times the canvas content is built. With the stock
  /// InteractiveViewer this counter explodes during pan/zoom (setState on
  /// every frame). With InteractiveViewerVector it stays flat: the
  /// transformation is pushed straight to the RenderTransform.
  int _buildCount = 0;

  static const double _canvasSize = 2000;

  static const List<DemoNode> _nodes = [
    DemoNode(position: Offset(300, 250), size: Size(180, 100), color: Colors.teal, label: "Node A"),
    DemoNode(position: Offset(900, 200), size: Size(220, 120), color: Colors.deepOrange, label: "Node B"),
    DemoNode(position: Offset(600, 700), size: Size(200, 140), color: Colors.indigo, label: "Node C"),
    DemoNode(position: Offset(1300, 500), size: Size(160, 160), color: Colors.purple, label: "Node D"),
    DemoNode(position: Offset(1100, 1100), size: Size(240, 100), color: Colors.green, label: "Node E"),
    DemoNode(position: Offset(250, 1200), size: Size(200, 180), color: Colors.redAccent, label: "Node F"),
    DemoNode(position: Offset(1500, 1400), size: Size(180, 140), color: Colors.amber, label: "Node G"),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _resetTransform() {
    _controller.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("InteractiveViewerVector"),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text("canvas builds: $_buildCount"),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            tooltip: "Reset transform",
            onPressed: _resetTransform,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return InteractiveViewerVector(
            transformationController: _controller,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(_canvasSize),
            minScale: 0.1,
            maxScale: 3,
            onInteractionEnd: (_) => setState(() {}),
            child: _buildCanvasContent(),
          );
        },
      ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          "Drag to pan — pinch / scroll to zoom — double-tap the app bar icon to reset.\n"
          "The 'canvas builds' counter stays flat during pan/zoom: no setState, only markNeedsPaint.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildCanvasContent() {
    _buildCount++;
    return SizedBox(
      width: _canvasSize,
      height: _canvasSize,
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          const CustomPaint(size: Size(_canvasSize, _canvasSize), painter: _LinksPainter(_nodes)),
          for (final node in _nodes)
            Positioned(
              left: node.position.dx,
              top: node.position.dy,
              child: _DemoNodeWidget(node: node),
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
      child: Text(node.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
  bool shouldRepaint(_LinksPainter oldDelegate) => false;
}
