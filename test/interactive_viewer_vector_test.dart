import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:interactive_viewer_vector/interactive_viewer_vector.dart";
import "package:vector_math/vector_math_64.dart" show Quad, Vector3;

void main() {
  group("Geometry helpers", () {
    test("getAxisAlignedBoundingBox returns the axis aligned bounding box of a quad", () {
      final quad = Quad.points(Vector3(1, 2, 0), Vector3(5, 1, 0), Vector3(6, 8, 0), Vector3(0, 6, 0));
      final aabb = InteractiveViewerVector.getAxisAlignedBoundingBox(quad);
      expect(aabb.point0.x, 0);
      expect(aabb.point0.y, 1);
      expect(aabb.point2.x, 6);
      expect(aabb.point2.y, 8);
    });

    test("pointIsInside is true for an interior point, false outside", () {
      final quad = Quad.points(Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(10, 10, 0), Vector3(0, 10, 0));
      expect(InteractiveViewerVector.pointIsInside(Vector3(5, 5, 0), quad), isTrue);
      expect(InteractiveViewerVector.pointIsInside(Vector3(15, 5, 0), quad), isFalse);
    });

    test("getNearestPointOnLine clamps to the segment", () {
      final closest = InteractiveViewerVector.getNearestPointOnLine(
        Vector3(15, 0, 0),
        Vector3(0, 0, 0),
        Vector3(10, 0, 0),
      );
      expect(closest.x, 10);
    });

    test("getNearestPointInside returns the point itself when inside", () {
      final quad = Quad.points(Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(10, 10, 0), Vector3(0, 10, 0));
      final point = Vector3(5, 5, 0);
      final result = InteractiveViewerVector.getNearestPointInside(point, quad);
      expect(result.x, point.x);
      expect(result.y, point.y);
    });
  });

  group("TransformationControllerVector", () {
    test("defaults to the identity matrix", () {
      final controller = TransformationControllerVector();
      expect(controller.value, Matrix4.identity());
      controller.dispose();
    });

    test("toScene maps a viewport point through the inverse transform", () {
      final controller = TransformationControllerVector(Matrix4.identity()..translateByDouble(10, 20, 0, 1));
      final scene = controller.toScene(const Offset(10, 20));
      expect(scene.dx, closeTo(0, 1e-9));
      expect(scene.dy, closeTo(0, 1e-9));
      controller.dispose();
    });
  });
}
