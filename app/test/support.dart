// Shared helpers of the widget tests and the screenshot tool.
import 'dart:io';

import 'package:ai_clinic/core/clock.dart';
import 'package:ai_clinic/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

/// Loads the app's font and the Material icons. Without them a test draws
/// every letter as a wide box, and layouts overflow that fit on a real phone.
/// Tests run from the app/ folder, so the font files are read from assets/.
Future<void> loadAppFonts() async {
  Future<ByteData> read(String path) async => ByteData.sublistView(await File(path).readAsBytes());

  final roboto = FontLoader('Roboto');
  for (final weight in ['Regular', 'Medium', 'Bold', 'Black']) {
    roboto.addFont(read('assets/fonts/Roboto-$weight.ttf'));
  }
  await roboto.load();

  // The icon font ships with the Flutter SDK, next to the test runner.
  final root = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final icons = FontLoader('MaterialIcons')
    ..addFont(read('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

/// Starts the app against the in-memory server, on a phone-sized screen unless
/// [screen] says otherwise. [demo] signs in with one tap as the demo "customer" or "owner".
Future<FakeApi> startApp(
  WidgetTester tester, {
  required DateTime now,
  bool onboardingDone = true,
  String? demo,
  String lang = 'ru',
  String theme = 'light',
  Size screen = const Size(390, 844),
}) async {
  tester.view.physicalSize = screen * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'onboarding_done': onboardingDone, 'lang': lang, 'theme_mode': theme});
  final api = FakeApi(now: now);
  await tester.pumpWidget(SmileApp(api: api, clock: AppClock(() => now)));
  await tester.pumpAndSettle();
  if (demo != null) {
    await tester.tap(find.byKey(ValueKey('demo-$demo')));
    await tester.pumpAndSettle();
  }
  return api;
}
