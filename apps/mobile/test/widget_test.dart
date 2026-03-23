import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:labguard/src/app/app.dart';

void main() {
  testWidgets('renders LabGuard shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: LabGuardApp()));
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('LabGuard'), findsWidgets);
  });
}
