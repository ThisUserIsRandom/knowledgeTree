import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledgetree/features/chat/domain/models/chat_message.dart';
import 'package:knowledgetree/features/chat/domain/models/chat_note.dart';
import 'package:knowledgetree/features/chat/presentation/widgets/message_bubble.dart';

void main() {
  Widget host(ChatMessage msg) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MessageBubble(
              message: msg,
              onCopy: () {},
              onDelete: () {},
              onEditNote: () {},
            ),
          ),
        ),
      );

  testWidgets('short assistant bubble with 3 actions must not overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(host(
      ChatMessage(id: 'a1', role: MessageRole.assistant, content: 'Ok.'),
    ));

    expect(tester.takeException(), isNull,
        reason: 'short assistant bubble with note/copy/delete must not overflow');
  });

  testWidgets('assistant bubble with a note renders it', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(host(
      ChatMessage(
        id: 'a2',
        role: MessageRole.assistant,
        content: 'Hello there',
        note: const ChatNote(text: 'my personal note'),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.text('Your note'), findsOneWidget);
    expect(find.text('my personal note'), findsOneWidget);
  });
}
