import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midori/main.dart';

void main() {
  testWidgets('Midori app builds the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MidoriApp()));

    // Verify the production home app bar title is present.
    expect(find.text('Plant Disease Detector'), findsOneWidget);
  });
}
