// Renders the real screens against the in-memory server and saves them as PNG
// files into docs/screenshots. Run from the app/ folder:
//
//   flutter test tool/screenshots --update-goldens
//
// Lives outside test/ on purpose: it produces images, it does not check them.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:ai_clinic/bloc/settings_cubit.dart';
import 'package:ai_clinic/ui/customer/customer_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support.dart';

const _out = '../../../docs/screenshots';

/// Today at 12:30: the day has both finished and upcoming visits.
DateTime get _now {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 12, 30);
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('$_out/$name.png'));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Finder _tab(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<void> _ask(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).last, text);
  await _tap(tester, find.byIcon(Icons.arrow_upward));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  // Draw real shadows instead of the test-mode placeholders.
  setUp(() => debugDisableShadows = false);

  testWidgets('onboarding and sign-in', (tester) async {
    await startApp(tester, now: _now, onboardingDone: false);
    await _shot(tester, '01_onboarding');

    await _tap(tester, find.text('Пропустить'));
    await _shot(tester, '02_login');
    debugDisableShadows = true;
  });

  testWidgets('client: catalog, business, booking', (tester) async {
    await startApp(tester, now: _now, demo: 'customer');
    await _shot(tester, '03_catalog');

    await _tap(tester, find.text('Барбершоп Blade'));
    await _shot(tester, '04_business');

    await _tap(tester, find.widgetWithText(FilledButton, 'Записаться'));
    await _tap(tester, find.widgetWithText(ChoiceChip, '15:00'));
    await _shot(tester, '05_booking');

    await _tap(tester, find.text('Записаться на 15:00'));
    await _tap(tester, find.text('Спросить ИИ-администратора'));
    await _ask(tester, 'Борода завтра после обеда');
    await _shot(tester, '06_business_chat');
    debugDisableShadows = true;
  });

  testWidgets('client: AI chat and bookings', (tester) async {
    await startApp(tester, now: _now, demo: 'customer');
    await _tap(tester, _tab('Ассистент'));
    await _ask(tester, 'Стрижка завтра утром');
    await _shot(tester, '07_chat_slots');

    await _tap(tester, find.text('10:00'));
    await _shot(tester, '08_chat_booked');

    await _tap(tester, _tab('Записи'));
    await _shot(tester, '09_bookings');

    await _tap(tester, find.text('История'));
    await _shot(tester, '10_history');

    await _tap(tester, find.text('Оценить'));
    await _shot(tester, '11_review');
    await _tap(tester, find.text('Отправить'));

    await _tap(tester, _tab('Профиль'));
    await _shot(tester, '12_profile');
    debugDisableShadows = true;
  });

  testWidgets('owner: dashboard, schedule, services, business', (tester) async {
    await startApp(tester, now: _now, demo: 'owner');
    await _shot(tester, '13_owner_today');

    await _tap(tester, _tab('Записи'));
    await _shot(tester, '14_owner_schedule');

    await _tap(tester, find.text('Новая запись'));
    await _tap(tester, find.widgetWithText(ListTile, 'Консультация и осмотр'));
    await tester.enterText(find.widgetWithText(TextField, 'Имя клиента'), 'Марат Исаков');
    await _tap(tester, find.widgetWithText(ChoiceChip, '16:00'));
    await _shot(tester, '15_owner_manual_booking');
    await _tap(tester, find.text('Записать на 16:00'));

    await _tap(tester, _tab('Услуги'));
    await _shot(tester, '16_owner_services');

    await _tap(tester, find.text('Добавить услугу'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Название услуги'), 'Имплантация');
    await tester.enterText(find.widgetWithText(TextFormField, 'Цена, сом'), '25000');
    await _shot(tester, '17_owner_service_dialog');
    await _tap(tester, find.text('Сохранить'));

    await _tap(tester, _tab('Бизнес'));
    await _shot(tester, '18_owner_business');
    debugDisableShadows = true;
  });

  testWidgets('new owner: describing the business', (tester) async {
    await startApp(tester, now: _now);
    await _tap(tester, find.textContaining('Зарегистрироваться'));
    await _tap(tester, find.text('Я владелец'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Имя'), 'Асель');
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'asel@example.kg');
    await tester.enterText(find.widgetWithText(TextFormField, 'Пароль'), 'secret123');
    await _shot(tester, '19_register_owner');

    await _tap(tester, find.text('Создать аккаунт'));
    await _tap(tester, find.widgetWithText(ChoiceChip, 'Барбершоп'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Название'), 'Barber Asel');
    await _shot(tester, '20_owner_setup');
    debugDisableShadows = true;
  });

  testWidgets('dark theme and English', (tester) async {
    await startApp(tester, now: _now, demo: 'customer', lang: 'en');
    final settings = tester.element(find.byType(CustomerShell)).read<SettingsCubit>();
    await settings.setThemeMode(ThemeMode.dark);
    await _shot(tester, '21_dark_english');
    debugDisableShadows = true;
  });
}
