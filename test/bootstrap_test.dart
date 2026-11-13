import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyhim/features/splash/splash_screen.dart';
import 'package:holyhim/main.dart';
import 'package:holyhim/services/firebase_runtime.dart';

Widget _state(BuildContext context) => MaterialApp(
    home: Consumer(
        builder: (context, ref, _) =>
            Text('Firebase ready: ${ref.watch(firebaseReadyProvider)}')));
void main() {
  testWidgets(
      'launch leaves splash at three seconds and observes a late Firebase success',
      (tester) async {
    final initialization = Completer<void>();
    await tester.pumpWidget(Bootstrap(
        initializeCache: () async {},
        initializeFirebase: () => initialization.future,
        appBuilder: _state));
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pump();
    expect(find.text('Firebase ready: false'), findsOneWidget);
    initialization.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Firebase ready: true'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'ordinary initialization keeps the 1.2 second bloom and cancels its guard',
      (tester) async {
    await tester.pumpWidget(Bootstrap(
        initializeCache: () async {},
        initializeFirebase: () async {},
        appBuilder: _state));
    await tester.pump(const Duration(milliseconds: 1199));
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text('Firebase ready: true'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets('a late initialization failure leaves a usable recovery frame',
      (tester) async {
    final initialization = Completer<void>();
    await tester.pumpWidget(Bootstrap(
        initializeCache: () async {},
        initializeFirebase: () => initialization.future,
        appBuilder: _state));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    initialization.completeError(StateError('Native startup unavailable'));
    await tester.pump();
    expect(find.text('Firebase ready: false'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
