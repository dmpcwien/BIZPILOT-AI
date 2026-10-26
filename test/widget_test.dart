import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bizpilot_ai/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Dashboard displays main navigation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const BizPilotApp());
    await tester.pumpAndSettle();
    expect(find.text('Kunden'), findsWidgets);
    expect(find.text('Angebote'), findsWidgets);
    expect(find.text('Rechnungen'), findsWidgets);
  });
}
