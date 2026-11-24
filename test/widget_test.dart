// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_app/main.dart';

void main() {
  testWidgets('Shop app opens', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ShopApp());
    await tester.pump();

    // Bottom navigation ke tabs dikhne chahiye.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Wishlist'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Cart'), findsOneWidget);
  });
}
