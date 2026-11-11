// Renders the real screens with a fake server and saves them as PNG files
// into docs/screenshots. Run from the app/ folder:
//
//   flutter test tool/screenshots --update-goldens
//
// Lives outside test/ on purpose: it produces images, it does not check them.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';

import 'package:ai_clinic/bloc/settings_cubit.dart';
import 'package:ai_clinic/main.dart';
import 'package:ai_clinic/ui/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/fakes.dart';

const _out = '../../../docs/screenshots';

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final dir = '$root/bin/cache/artifacts/material_fonts';

  Future<ByteData> read(String name) async =>
      ByteData.sublistView(await File('$dir/$name').readAsBytes());

  final roboto = FontLoader('Roboto');
  for (final name in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']) {
    if (File('$dir/$name').existsSync()) roboto.addFont(read(name));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')..addFont(read('MaterialIcons-Regular.otf'));
  await icons.load();
}

/// Starts the app on a phone-sized screen.
Future<FakeClinicRepository> _start(
  WidgetTester tester, {
  bool onboardingDone = true,
  bool signedIn = true,
  String lang = 'ru',
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'onboarding_done': onboardingDone,
    'lang': lang,
    'theme_mode': 'light',
  });
  final repo = FakeClinicRepository();
  await tester.pumpWidget(ClinicApp(
    authRepository: FakeAuthRepository(signedIn: signedIn),
    clinicRepository: repo,
  ));
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('$_out/$name.png'));
}

Future<void> _ask(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.byIcon(Icons.arrow_upward));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);
  // Draw real shadows instead of the test-mode placeholders.
  setUp(() => debugDisableShadows = false);

  testWidgets('onboarding', (tester) async {
    await _start(tester, onboardingDone: false, signedIn: false);
    await _shot(tester, '01_onboarding');
    debugDisableShadows = true;
  });

  testWidgets('login', (tester) async {
    await _start(tester, signedIn: false);
    await _shot(tester, '02_login');
    debugDisableShadows = true;
  });

  testWidgets('chat, booking, bookings list, specialists', (tester) async {
    await _start(tester);
    await _shot(tester, '03_chat_start');

    await _ask(tester, 'Болит зуб, завтра после обеда');
    await _shot(tester, '04_chat_slots');

    await tester.tap(find.text('15:00'));
    await _shot(tester, '05_chat_booked');

    await tester.tap(find.byIcon(Icons.event_note_outlined));
    await _shot(tester, '06_bookings');

    await tester.tap(find.byIcon(Icons.people_outline));
    await _shot(tester, '07_specialists');
    debugDisableShadows = true;
  });

  testWidgets('dark theme and English', (tester) async {
    await _start(tester, lang: 'en');
    final settings = tester.element(find.byType(HomeScreen)).read<SettingsCubit>();
    await settings.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Барбершоп'));
    await _ask(tester, 'Стрижка в субботу утром');
    await _shot(tester, '08_dark_english');
    debugDisableShadows = true;
  });
}
