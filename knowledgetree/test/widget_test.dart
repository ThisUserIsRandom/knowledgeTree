import 'package:flutter_test/flutter_test.dart';
import 'package:knowledgetree/app.dart';

void main() {
  testWidgets('App shows connector screen on launch', (tester) async {
    await tester.pumpWidget(const KnowledgeTreeApp());
    expect(find.text('Knowledge Tree AI'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });
}
