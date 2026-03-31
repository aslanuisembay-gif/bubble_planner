import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bubble_planner/app_state.dart';
import 'package:bubble_planner/main.dart';

void main() {
  testWidgets('Login then open Bubbles tab', (WidgetTester tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 900));

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const BubblePlannerApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Welcome Back'), findsOneWidget);
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Ready for tasks'), findsOneWidget);
    await tester.tap(find.text('BUBBLES'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Bubbles'), findsOneWidget);
  });
}
