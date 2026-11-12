import 'package:ai_clinic/bloc/appointments_bloc.dart';
import 'package:ai_clinic/bloc/booking_cubit.dart';
import 'package:ai_clinic/bloc/business_cubit.dart';
import 'package:ai_clinic/bloc/catalog_bloc.dart';
import 'package:ai_clinic/bloc/chat_bloc.dart';
import 'package:ai_clinic/bloc/load_status.dart';
import 'package:ai_clinic/data/auth_repository.dart';
import 'package:ai_clinic/data/booking_repository.dart';
import 'package:ai_clinic/data/catalog_repository.dart';
import 'package:ai_clinic/data/models.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

/// Barbershop Blade in the fake data: business 2, "Мужская стрижка" is service 5,
/// performed by specialists 4 and 5.
const _barber = 2;
const _haircut = 5;

void main() {
  final now = DateTime(2030, 1, 7, 12, 30); // Monday
  late FakeApi api;
  late CatalogRepository catalog;
  late BookingRepository booking;

  Future<void> signIn(FakeApi api) async {
    SharedPreferences.setMockInitialValues({});
    await AuthRepository(api).demoLogin('customer');
  }

  setUp(() async {
    api = FakeApi(now: now);
    catalog = CatalogRepository(api);
    booking = BookingRepository(api);
    await signIn(api);
  });

  group('CatalogBloc', () {
    blocTest<CatalogBloc, CatalogState>(
      'loads the niches and the businesses',
      build: () => CatalogBloc(catalog),
      act: (bloc) => bloc.add(const CatalogRequested()),
      expect: () => [
        isA<CatalogState>().having((s) => s.status, 'status', LoadStatus.loading),
        isA<CatalogState>()
            .having((s) => s.status, 'status', LoadStatus.success)
            .having((s) => s.categories.length, 'niches', 10)
            .having((s) => s.businesses.first.name, 'first', 'Стоматология Smile'),
      ],
    );

    test('filters by niche and finds a business by one of its services', () async {
      final bloc = CatalogBloc(catalog)..add(const CatalogRequested());
      await bloc.stream.firstWhere((s) => s.status == LoadStatus.success);

      bloc.add(const CatalogCategorySelected('barber'));
      await bloc.stream.first;
      expect(bloc.state.visible.map((b) => b.name), ['Барбершоп Blade']);

      bloc
        ..add(const CatalogCategorySelected(null))
        ..add(const CatalogSearchChanged('Замена МАСЛА'));
      await bloc.stream.firstWhere((s) => s.query.isNotEmpty);
      expect(bloc.state.visible.map((b) => b.name), ['Автосервис Motor']);
    });

    blocTest<CatalogBloc, CatalogState>(
      'no connection: a failure with the reason',
      setUp: () => api.offline = true,
      build: () => CatalogBloc(catalog),
      act: (bloc) => bloc.add(const CatalogRequested()),
      skip: 1,
      expect: () => [
        isA<CatalogState>()
            .having((s) => s.status, 'status', LoadStatus.failure)
            .having((s) => s.error, 'error', contains('Нет связи')),
      ],
    );
  });

  test('BusinessCubit shows the summary at once and then the full card', () async {
    final preview = (await catalog.businesses()).firstWhere((b) => b.id == _barber);
    final cubit = BusinessCubit(catalog, _barber, preview: preview);
    expect(cubit.state.business?.services, isEmpty);

    await cubit.load();
    expect(cubit.state.status, LoadStatus.success);
    expect(cubit.state.business?.services.map((s) => s.name), contains('Мужская стрижка'));
    expect(cubit.state.business?.specialists, hasLength(2));
  });

  group('BookingCubit', () {
    BookingCubit build({DateTime? today, int? specialistId, FakeApi? server}) {
      final repository = server == null ? catalog : CatalogRepository(server);
      final bookings = server == null ? booking : BookingRepository(server);
      return BookingCubit(
        today: today ?? now,
        specialistId: specialistId,
        loadSlots: (day, specialist) => repository.slots(_barber, _haircut, day: day, specialistId: specialist),
        submit: (slot) =>
            bookings.book(serviceId: slot.serviceId, specialistId: slot.specialistId, start: slot.start),
      );
    }

    test('opens today while it still has free time', () async {
      final cubit = build();
      expect(cubit.state.days, hasLength(14));

      await cubit.start();
      expect(cubit.state.day, DateTime(2030, 1, 7));
      expect(cubit.state.slots.first.start, DateTime(2030, 1, 7, 13));
    });

    test('skips to the next day when today is over', () async {
      final evening = DateTime(2030, 1, 7, 19, 30);
      final server = FakeApi(now: evening);
      await signIn(server);

      final cubit = build(today: evening, server: server);
      await cubit.start();
      expect(cubit.state.day, DateTime(2030, 1, 8));
      expect(cubit.state.slots.first.start, DateTime(2030, 1, 8, 10));
    });

    test('choosing a specialist asks the server for that specialist only', () async {
      final cubit = build();
      await cubit.start();
      await cubit.selectSpecialist(5);

      expect(api.lastQuery, containsPair('specialist_id', '5'));
      expect(cubit.state.slots.every((s) => s.specialistId == 5), isTrue);
    });

    test('books the chosen slot', () async {
      final cubit = build();
      await cubit.start();
      cubit.selectSlot(cubit.state.slots.firstWhere((s) => s.start.hour == 15 && s.start.minute == 0));
      await cubit.submit();

      expect(cubit.state.result?.start, DateTime(2030, 1, 7, 15));
      expect(cubit.state.result?.businessName, 'Барбершоп Blade');
    });

    test('a slot taken meanwhile gives the reason and fresh slots', () async {
      final cubit = build(specialistId: 4);
      await cubit.start();
      final slot = cubit.state.slots.firstWhere((s) => s.start.hour == 15 && s.start.minute == 0);
      cubit.selectSlot(slot);
      // Someone else is faster.
      await booking.book(serviceId: _haircut, specialistId: 4, start: slot.start);

      final errors = <String?>[];
      final subscription = cubit.stream.listen((s) => errors.add(s.error));
      await cubit.submit();
      await subscription.cancel();

      expect(errors, contains('Это время уже занято'));
      expect(cubit.state.result, isNull);
      expect(cubit.state.selected, isNull);
      expect(cubit.state.slots.any((s) => s.start == slot.start), isFalse);
    });
  });

  group('AppointmentsBloc', () {
    test('splits bookings into upcoming and history', () async {
      await booking.book(serviceId: _haircut, start: DateTime(2030, 1, 8, 10));
      final bloc = AppointmentsBloc(booking)..add(const AppointmentsRequested());
      final state = await bloc.stream.firstWhere((s) => s.status == LoadStatus.success);

      expect(state.upcoming.single.businessName, 'Барбершоп Blade');
      // Two finished visits in the fake data, the latest first.
      expect(state.history.map((a) => a.businessName), ['Стоматология Smile', 'Барбершоп Blade']);
      expect(state.history.every((a) => a.canReview), isTrue);
    });

    test('a cancelled booking moves to history', () async {
      final booked = await booking.book(serviceId: _haircut, start: DateTime(2030, 1, 8, 10));
      final bloc = AppointmentsBloc(booking)..add(const AppointmentsRequested());
      await bloc.stream.firstWhere((s) => s.status == LoadStatus.success);

      bloc.add(AppointmentCancelled(booked.id));
      final state = await bloc.stream.first;
      expect(state.upcoming, isEmpty);
      expect(state.history.first.status, 'cancelled');
    });

    test('a review is saved once; the second attempt reports the reason', () async {
      final bloc = AppointmentsBloc(booking)..add(const AppointmentsRequested());
      final loaded = await bloc.stream.firstWhere((s) => s.status == LoadStatus.success);
      final visit = loaded.history.first;

      bloc.add(AppointmentReviewed(visit.id, 4, comment: 'Спасибо'));
      final rated = await bloc.stream.first;
      expect(rated.history.first.reviewRating, 4);
      expect(rated.history.first.canReview, isFalse);
      expect(api.lastBody, {'rating': 4, 'comment': 'Спасибо'});

      bloc.add(AppointmentReviewed(visit.id, 5));
      final refused = await bloc.stream.first;
      expect(refused.error, 'Оценить можно завершённый визит, один раз');
      expect(refused.items, hasLength(2));
    });
  });

  group('ChatBloc', () {
    ChatBloc build({int? businessId, String businessName = ''}) =>
        ChatBloc(booking, userName: 'Айдай', businessId: businessId, businessName: businessName);

    test('greets the client by name, or on behalf of one business', () {
      expect(build().state.messages.single.text, contains('Здравствуйте, Айдай!'));
      expect(
        build(businessId: 1, businessName: 'Стоматология Smile').state.messages.single.text,
        contains('ИИ-администратор «Стоматология Smile»'),
      );
    });

    blocTest<ChatBloc, ChatState>(
      'a request brings an answer with free slots',
      build: build,
      act: (bloc) => bloc.add(const ChatMessageSent('Стрижка завтра утром')),
      expect: () => [
        isA<ChatState>().having((s) => s.isTyping, 'typing', isTrue),
        isA<ChatState>()
            .having((s) => s.isTyping, 'typing', isFalse)
            .having((s) => s.messages.last.slots.length, 'slots', 4)
            .having((s) => s.messages.last.slots.first.businessName, 'business', 'Барбершоп Blade')
            .having((s) => s.revision, 'revision', 0),
      ],
    );

    test('tapping a slot books it as a chat booking and tells the other screens', () async {
      final bloc = build()..add(const ChatMessageSent('Стрижка завтра утром'));
      final offered = await bloc.stream.firstWhere((s) => !s.isTyping);

      bloc.add(ChatSlotSelected(offered.messages.last.slots.first));
      final done = await bloc.stream.firstWhere((s) => s.bookingKey == null && s.revision == 1);

      expect(api.lastBody, containsPair('source', 'chat'));
      expect(done.messages.last.appointment?.start, DateTime(2030, 1, 8, 10));
      expect(done.messages.last.text, contains('Вы записаны в «Барбершоп Blade»'));
      // Suggestions of earlier answers are gone: they are stale now.
      expect(done.messages.where((m) => m.slots.isNotEmpty), isEmpty);
    });

    test('moves a booking through the chat', () async {
      final booked = await booking.book(serviceId: _haircut, specialistId: 4, start: DateTime(2030, 1, 8, 10));
      final bloc = build()..add(const ChatMessageSent('Перенеси мою запись'));
      final offered = await bloc.stream.firstWhere((s) => !s.isTyping);
      expect(offered.messages.last.rescheduleId, booked.id);

      final slot = offered.messages.last.slots.last;
      bloc.add(ChatSlotSelected(slot, rescheduleId: booked.id));
      final done = await bloc.stream.firstWhere((s) => s.revision == 1);

      expect(api.calls.last, 'PATCH /appointments/${booked.id}');
      expect(done.messages.last.appointment?.start, slot.start);
      expect(done.messages.last.text, contains('перенесена'));
    });

    test('a cancellation made by the assistant also counts as a change', () async {
      await booking.book(serviceId: _haircut, start: DateTime(2030, 1, 8, 10));
      final bloc = build()..add(const ChatMessageSent('Отмени запись'));
      final state = await bloc.stream.firstWhere((s) => !s.isTyping);
      expect(state.revision, 1);
    });

    test('sends the chosen niche, and the business when the chat belongs to one', () async {
      final city = build()
        ..add(const ChatCategorySelected('barber'))
        ..add(const ChatMessageSent('Стрижка'));
      await city.stream.firstWhere((s) => s.messages.length == 3);
      expect(api.lastBody, containsPair('category', 'barber'));
      expect(api.lastBody, containsPair('business_id', null));

      final scoped = build(businessId: 1, businessName: 'Стоматология Smile')..add(const ChatMessageSent('Чистка'));
      final answer = await scoped.stream.firstWhere((s) => s.messages.length == 3);
      expect(api.lastBody, containsPair('business_id', 1));
      expect(answer.messages.last.slots.every((s) => s.businessId == 1), isTrue);
    });

    blocTest<ChatBloc, ChatState>(
      'no connection: an error bubble instead of an answer',
      setUp: () => api.offline = true,
      build: build,
      act: (bloc) => bloc.add(const ChatMessageSent('Стрижка')),
      skip: 1,
      expect: () => [
        isA<ChatState>()
            .having((s) => s.isTyping, 'typing', isFalse)
            .having((s) => s.messages.last.isError, 'error bubble', isTrue),
      ],
    );

    test('history sent to the server skips error bubbles and keeps the last ten messages', () async {
      final history = [
        for (var i = 0; i < 12; i++) ChatMessage.user('message $i'),
        const ChatMessage.error('Нет связи'),
      ];
      await booking.chat('Стрижка', history);
      final sent = (api.lastBody!['history'] as List).cast<Map<String, dynamic>>();
      expect(sent, hasLength(10));
      expect(sent.first['text'], 'message 2');
      expect(sent.last, {'role': 'user', 'text': 'message 11'});
    });
  });
}
