import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bubble_planner/app_state.dart';
import 'package:bubble_planner/main.dart';

void main() {
  testWidgets('offline login screen builds', (WidgetTester tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 900));

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const BubblePlannerApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    // No CONVEX_URL in tests → offline copy (translations `loginTitleOffline` / `loginActionOffline`).
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
