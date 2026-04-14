// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:cbt_mobile/main.dart';
import 'package:cbt_mobile/services/sync_service.dart';

void main() {
  testWidgets('CBTApp renders', (WidgetTester tester) async {
    // No need to initialize Hive for this smoke test.
    await tester.pumpWidget(CBTApp(syncService: SyncService()));
    expect(find.text("MCP CBT Platform"), findsOneWidget);
  });
}
