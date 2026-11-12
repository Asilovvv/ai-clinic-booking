// Shared helpers of the widget tests and the screenshot tool.
import 'dart:io';

import 'package:ai_clinic/core/clock.dart';
import 'package:ai_clinic/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

/// Loads Roboto and the Material icons from the Flutter SDK. Without them a
/// test draws every letter as a wide box, and layouts overflow that fit on a
/// real phone.
Future<void> loadAppFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final dir = '$root/bin/cache/artifacts/material_fonts';

  Future<ByteData> read(String name) async => ByteData.sublistView(await File('$dir/$name').readAsBytes());

  final roboto = FontLoader('Roboto');
  for (final name in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']) {
    if (File('$dir/$name').existsSync()) roboto.addFont(read(name));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')..addFont(read('MaterialIcons-Regular.otf'));
  await icons.load();
}

/// Starts the app on a phone-sized screen (390 x 844) against the in-memory
/// server. [demo] signs in with one tap as the demo "customer" or "owner".
Future<FakeApi> startApp(
  WidgetTester tester, {
  required DateTime now,
  bool onboardingDone = true,
  String? demo,
  String lang = 'ru',
  String theme = 'light',
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
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
