import 'package:flutter_test/flutter_test.dart';
import 'package:taxnet_app/main.dart';

void main() {
  testWidgets('app boots to login', (tester) async {
    await tester.pumpWidget(const TaxNetApp());
    expect(find.text('National Tax Net'), findsOneWidget);
  });
}
