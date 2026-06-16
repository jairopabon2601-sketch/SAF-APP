import 'package:flutter_test/flutter_test.dart';

import 'package:saf_app/main.dart';

void main() {
  testWidgets('SAF app renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SafApp(initialRoute: '/login'));
    await tester.pumpAndSettle();

    expect(find.text('SAF'), findsOneWidget);
    expect(find.text('Iniciar Sesión'), findsOneWidget);
  });
}
