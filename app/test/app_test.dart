// The whole app on a phone-sized screen against the in-memory server:
// what a client and an owner actually tap through.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_api.dart';
import 'support.dart';

/// A Monday at 12:30, so every business is open and the day still has free time.
final _now = DateTime(2030, 1, 7, 12, 30);

Future<FakeApi> _start(WidgetTester tester, {bool onboardingDone = true, String? demo}) =>
    startApp(tester, now: _now, onboardingDone: onboardingDone, demo: demo);

/// Taps a widget, scrolling to it first when it is outside the screen, then
/// waits for the app to settle.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  final target = finder.first;
  final screen = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
  if (!screen.contains(tester.getCenter(target))) {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// A destination of the bottom navigation bar.
Finder _tab(String label) => find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<void> _ask(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).last, text);
  await _tap(tester, find.byIcon(Icons.arrow_upward));
}

void main() {
  setUpAll(loadAppFonts);

  group('sign-in', () {
    testWidgets('first launch shows onboarding, then sign-in with demo accounts', (tester) async {
      await _start(tester, onboardingDone: false);
      expect(find.text('Запись одной фразой'), findsOneWidget);

      await _tap(tester, find.text('Пропустить'));
      expect(find.text('Вход'), findsOneWidget);
      expect(find.text('Быстрый вход для демо'), findsOneWidget);
    });

    testWidgets('a wrong password shows the server message and keeps the form', (tester) async {
      await _start(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), demoCustomerEmail);
      await tester.enterText(find.widgetWithText(TextFormField, 'Пароль'), 'wrong-password');
      await _tap(tester, find.text('Войти'));

      expect(find.text('Неверный email или пароль'), findsOneWidget);
      expect(find.text('Вход'), findsOneWidget);
    });

    testWidgets('signing out and in as the other role swaps the whole app', (tester) async {
      await _start(tester, demo: 'customer');
      expect(_tab('Каталог'), findsOneWidget);

      await _tap(tester, _tab('Профиль'));
      await _tap(tester, find.text('Выйти'));
      expect(find.text('Вход'), findsOneWidget);

      await _tap(tester, find.byKey(const ValueKey('demo-owner')));
      expect(_tab('Сегодня'), findsOneWidget);
      expect(_tab('Каталог'), findsNothing);
    });
  });

  group('client', () {
    testWidgets('catalog: niche filter and search by service', (tester) async {
      await _start(tester, demo: 'customer');
      expect(find.text('Здравствуйте, Айдай'), findsOneWidget);
      expect(find.text('Стоматология Smile'), findsOneWidget);
      expect(find.text('Барбершоп Blade'), findsOneWidget);

      await _tap(tester, find.widgetWithText(ChoiceChip, 'Барбершоп'));
      expect(find.text('Барбершоп Blade'), findsOneWidget);
      expect(find.text('Стоматология Smile'), findsNothing);

      // The row of niches was scrolled to reach the chip; bring "All" back.
      await tester.drag(find.widgetWithText(ChoiceChip, 'Барбершоп'), const Offset(600, 0));
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(ChoiceChip, 'Все'));
      await tester.enterText(find.byType(TextField).first, 'маникюр');
      await tester.pumpAndSettle();
      expect(find.text('Салон красоты Aurora'), findsOneWidget);
      expect(find.text('Барбершоп Blade'), findsNothing);
    });

    testWidgets('books from the business page, then moves and cancels the booking', (tester) async {
      final api = await _start(tester, demo: 'customer');

      await _tap(tester, find.text('Барбершоп Blade'));
      expect(find.text('Оформление бороды'), findsOneWidget);
      expect(find.text('Азамат Жумабеков'), findsOneWidget);

      // The sheet: any specialist, today, 15:00.
      await _tap(tester, find.widgetWithText(FilledButton, 'Записаться'));
      expect(find.text('Выберите время'), findsOneWidget);
      await _tap(tester, find.widgetWithText(ChoiceChip, '15:00'));
      await _tap(tester, find.text('Записаться на 15:00'));
      expect(find.textContaining('Вы записаны!'), findsOneWidget);
      expect(api.lastBody, containsPair('start', '2030-01-07T15:00'));
      expect(api.lastBody, containsPair('source', 'app'));

      await tester.pageBack();
      await tester.pumpAndSettle();
      await _tap(tester, _tab('Записи'));
      expect(find.text('Предстоящие · 1'), findsOneWidget);
      expect(find.textContaining('15:00 · 600'), findsOneWidget);

      // Move it an hour later; its own time counts as free.
      await _tap(tester, find.text('Перенести'));
      await _tap(tester, find.widgetWithText(ChoiceChip, '16:00'));
      await _tap(tester, find.text('Перенести на 16:00'));
      expect(find.textContaining('Запись перенесена'), findsOneWidget);
      expect(api.calls.last, 'GET /appointments');

      await _tap(tester, find.widgetWithText(TextButton, 'Отменить'));
      expect(find.text('Отменить запись?'), findsOneWidget);
      await _tap(tester, find.widgetWithText(FilledButton, 'Отменить'));
      expect(find.text('Нет предстоящих записей'), findsOneWidget);

      await _tap(tester, find.text('История'));
      expect(find.text('Отменена'), findsOneWidget);
    });

    testWidgets('books through the AI chat and sees the booking in the list', (tester) async {
      final api = await _start(tester, demo: 'customer');
      await _tap(tester, _tab('Ассистент'));
      expect(find.textContaining('Я ИИ-администратор Smile AI'), findsOneWidget);

      await _ask(tester, 'Стрижка завтра утром');
      expect(find.textContaining('Мужская стрижка, «Барбершоп Blade»'), findsOneWidget);

      await _tap(tester, find.text('10:00'));
      expect(find.text('Запись подтверждена'), findsOneWidget);
      expect(api.calls, contains('POST /appointments'));
      expect(api.lastBody, containsPair('source', 'chat'));

      await _tap(tester, _tab('Записи'));
      expect(find.text('Предстоящие · 1'), findsOneWidget);
      expect(find.text('Барбершоп Blade'), findsOneWidget);
    });

    testWidgets('the chat of one business stays inside that business', (tester) async {
      final api = await _start(tester, demo: 'customer');
      await _tap(tester, find.text('Стоматология Smile'));
      await _tap(tester, find.text('Спросить ИИ-администратора'));
      expect(find.textContaining('Я ИИ-администратор «Стоматология Smile»'), findsOneWidget);

      await _ask(tester, 'Хочу чистку зубов');
      expect(api.lastBody, containsPair('business_id', 1));
      expect(find.textContaining('Профессиональная чистка зубов'), findsWidgets);
    });

    testWidgets('rates a finished visit', (tester) async {
      final api = await _start(tester, demo: 'customer');
      await _tap(tester, _tab('Записи'));
      await _tap(tester, find.text('История'));
      expect(find.text('Оценить'), findsNWidgets(2));

      await _tap(tester, find.text('Оценить'));
      expect(find.text('Как всё прошло?'), findsOneWidget);
      await _tap(tester, find.text('Отправить'));

      expect(api.lastBody, containsPair('rating', 5));
      expect(find.text('Оценить'), findsOneWidget);
    });

    testWidgets('on a wide screen the app stays a phone-sized column', (tester) async {
      await startApp(tester, now: _now, demo: 'customer', screen: const Size(1440, 900));
      expect(tester.getSize(find.byType(Scaffold).first).width, 480);
      expect(tester.getCenter(find.byType(Scaffold).first).dx, 720);

      // Pages and sheets opened from it stay inside the column too.
      await _tap(tester, find.text('Барбершоп Blade'));
      await _tap(tester, find.widgetWithText(FilledButton, 'Записаться'));
      expect(tester.getSize(find.byType(BottomSheet)).width, 480);
    });

    testWidgets('switches the interface to English', (tester) async {
      await _start(tester, demo: 'customer');
      await _tap(tester, _tab('Профиль'));
      await _tap(tester, find.text('English'));
      expect(_tab('Explore'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });
  });

  group('owner', () {
    testWidgets('dashboard shows the day and lets the owner complete a visit', (tester) async {
      final api = await _start(tester, demo: 'owner');
      expect(find.text('Стоматология Smile'), findsOneWidget);
      expect(find.text('Записей сегодня'), findsOneWidget);
      expect(find.text('Чолпон Абдраева'), findsOneWidget);

      // The menu of the 13:00 visit.
      final tile = find.ancestor(of: find.text('Чолпон Абдраева'), matching: find.byType(Material)).first;
      await _tap(tester, find.descendant(of: tile, matching: find.byType(PopupMenuButton<String>)));
      await _tap(tester, find.text('Завершить'));

      expect(api.lastBody, containsPair('status', 'completed'));
      // The dashboard reloaded: two visits of the day are completed now.
      expect(find.text('Завершена'), findsNWidgets(2));
    });

    testWidgets('books a walk-in client by hand', (tester) async {
      final api = await _start(tester, demo: 'owner');
      await _tap(tester, find.text('Новая запись'));
      expect(find.text('Выберите услугу'), findsOneWidget);

      await _tap(tester, find.widgetWithText(ListTile, 'Консультация и осмотр'));
      await tester.enterText(find.widgetWithText(TextField, 'Имя клиента'), 'Марат Исаков');
      await tester.enterText(find.widgetWithText(TextField, 'Телефон'), '+996 700 123 456');
      await _tap(tester, find.widgetWithText(ChoiceChip, '16:00'));
      await _tap(tester, find.text('Записать на 16:00'));

      expect(api.lastBody, containsPair('client_name', 'Марат Исаков'));
      expect(find.textContaining('Запись создана'), findsOneWidget);

      await _tap(tester, _tab('Записи'));
      expect(find.text('Марат Исаков'), findsOneWidget);
      expect(find.text('Вручную'), findsWidgets);
    });

    testWidgets('adds a service and hides the business from the catalog', (tester) async {
      final api = await _start(tester, demo: 'owner');
      await _tap(tester, _tab('Услуги'));
      await _tap(tester, find.text('Добавить услугу'));
      await tester.enterText(find.widgetWithText(TextFormField, 'Название услуги'), 'Имплантация');
      await tester.enterText(find.widgetWithText(TextFormField, 'Цена, сом'), '25000');
      await _tap(tester, find.text('Сохранить'));

      expect(api.calls, contains('POST /owner/services'));
      expect(find.text('Имплантация'), findsOneWidget);

      await _tap(tester, _tab('Бизнес'));
      await _tap(tester, find.byType(Switch));
      expect(api.lastBody, containsPair('is_active', false));

      await _tap(tester, _tab('Сегодня'));
      expect(find.textContaining('Бизнес скрыт из каталога'), findsOneWidget);
    });

    testWidgets('a new owner registers, describes the business and gets the cabinet', (tester) async {
      final api = await _start(tester);
      await _tap(tester, find.textContaining('Зарегистрироваться'));
      await _tap(tester, find.text('Я владелец'));
      await tester.enterText(find.widgetWithText(TextFormField, 'Имя'), 'Асель');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'asel@example.kg');
      await tester.enterText(find.widgetWithText(TextFormField, 'Пароль'), 'secret123');
      await _tap(tester, find.text('Создать аккаунт'));
      expect(find.text('Расскажите о бизнесе'), findsOneWidget);

      await _tap(tester, find.widgetWithText(ChoiceChip, 'Барбершоп'));
      await tester.enterText(find.widgetWithText(TextFormField, 'Название'), 'Barber Asel');
      await _tap(tester, find.text('Создать бизнес'));

      expect(api.lastBody, containsPair('category', 'barber'));
      expect(_tab('Сегодня'), findsOneWidget);
      expect(find.text('Barber Asel'), findsOneWidget);

      await _tap(tester, _tab('Услуги'));
      expect(find.text('Мужская стрижка'), findsOneWidget);
    });
  });
}
