import 'package:flutter_test/flutter_test.dart';
import 'package:midori/main.dart';

void main() {
  testWidgets('Midori app builds the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MidoriApp());

    // The app bar title contains 'Midori'
    expect(find.text('Midori'), findsOneWidget);
  });
}
