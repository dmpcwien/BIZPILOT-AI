import 'package:flutter_test/flutter_test.dart';
import 'package:bizpilot_ai/main.dart';

void main() {
  testWidgets('Dashboard displays main navigation', (tester) async {
    await tester.pumpWidget(const BizPilotApp());
    expect(find.text('Kunden'), findsWidgets);
    expect(find.text('Angebote'), findsWidgets);
    expect(find.text('Rechnungen'), findsWidgets);
  });
}
