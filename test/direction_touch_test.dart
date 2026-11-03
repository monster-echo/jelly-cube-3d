import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelly_cube_3d/jelly_cube_3d.dart';

void main() {
  testWidgets('opposite touch drags commit opposite turns', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Future<List<String>> drag(Offset from, Offset to) async {
      final controller = JellyCubeController();
      await tester.pumpWidget(JellyCubeApp(controller: controller));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.dragFrom(from, to, touchSlopX: 0, touchSlopY: 0);
      await tester.pump(const Duration(milliseconds: 80));
      final history = List<String>.from(controller.state()['history'] as List);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      return history;
    }

    final right = await drag(const Offset(195, 420), const Offset(70, 0));
    final left = await drag(const Offset(195, 420), const Offset(-70, 0));
    expect(right, isNotEmpty);
    expect(left, isNotEmpty);
    expect(right, isNot(equals(left)), reason: 'right=$right left=$left');
  });
}
