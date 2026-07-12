import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledgetree/features/chat/presentation/screens/chat_panel.dart';

void main() {
  testWidgets('chat sheet does not overflow on a small viewport', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Stress the layout with a narrow phone viewport + status bar padding,
    // where the sheet can be at its smallest usable size.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewPadding = const FakeViewPadding(top: 44);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewPadding();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => buildChatSheet(
            ctx,
            'node1',
            'A very long node title that might cause the header row to overflow with action buttons',
            () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull,
        reason: 'Chat sheet must not overflow its layout');

    // Drag the sheet down to its minimum size and ensure it still fits.
    final handle = find.byIcon(Icons.auto_awesome);
    await tester.drag(handle, const Offset(0, 300));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull,
        reason: 'Chat sheet must not overflow at minimum size');
  });
}
