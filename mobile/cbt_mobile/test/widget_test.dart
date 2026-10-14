import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cbt_mobile/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // flutter_secure_storage's platform channel is unavailable in tests;
  // mock it so the app's session check resolves (logged-out state).
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'read') return null;
    return null;
  });

  testWidgets('CBTApp renders', (WidgetTester tester) async {
    await tester.pumpWidget(CBTApp());
    // First frame: loading spinner while the LMS session check resolves.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    // Session check completes (logged out) → mode-select screen appears.
    expect(find.text("MCP Platform"), findsOneWidget);
    expect(find.text("Student Portal (LMS)"), findsOneWidget);
  });
}
