import 'package:flutter_test/flutter_test.dart';
import 'package:wireless_phone_dev/main.dart';

void main() {
  testWidgets('App loads home branding', (tester) async {
    await tester.pumpWidget(const WirelessPhoneDevApp());
    await tester.pump();
    expect(find.textContaining('Wireless Phone Dev'), findsOneWidget);
  });
}
