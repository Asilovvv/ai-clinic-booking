// End-to-end check of the mobile <-> server link: the real ApiClient,
// repositories, blocs and cubits talk to a running server over HTTP.
// The server must be freshly started with its demo data.
//
//   1. cd server && DB_PATH=/tmp/e2e.db uvicorn app.main:app --port 8000
//   2. cd app && flutter test tool/e2e
//
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:ai_clinic/bloc/appointments_bloc.dart';
import 'package:ai_clinic/bloc/booking_cubit.dart';
import 'package:ai_clinic/bloc/catalog_bloc.dart';
import 'package:ai_clinic/bloc/chat_bloc.dart';
import 'package:ai_clinic/bloc/load_status.dart';
import 'package:ai_clinic/bloc/owner_agenda_cubit.dart';
import 'package:ai_clinic/bloc/owner_cubit.dart';
import 'package:ai_clinic/bloc/owner_stats_cubit.dart';
import 'package:ai_clinic/core/api_client.dart';
import 'package:ai_clinic/data/auth_repository.dart';
import 'package:ai_clinic/data/booking_repository.dart';
import 'package:ai_clinic/data/catalog_repository.dart';
import 'package:ai_clinic/data/owner_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _url = String.fromEnvironment('API_URL', defaultValue: 'http://127.0.0.1:8000');

String _email(String prefix) => '${prefix}_${DateTime.now().microsecondsSinceEpoch}@test.kg';

/// The booking sheet's logic for a service, opened on the first day after
/// today that still has plenty of free time, so the test does not depend on
/// the hour it runs at.
Future<BookingCubit> _picker(
  CatalogRepository catalog,
  int businessId,
  int serviceId,
  SlotSubmit submit, {
  int? excludeAppointmentId,
  int? specialistId,
}) async {
  final cubit = BookingCubit(
    specialistId: specialistId,
    loadSlots: (day, specialist) => catalog.slots(
      businessId,
      serviceId,
      day: day,
      specialistId: specialist,
      excludeAppointmentId: excludeAppointmentId,
    ),
    submit: submit,
  );
  for (final day in cubit.state.days.skip(1)) {
    await cubit.selectDay(day);
    if (cubit.state.slots.length >= 6) return cubit;
  }
  fail('no free day in the next two weeks');
}

DateTime _dayOf(DateTime moment) => DateTime(moment.year, moment.month, moment.day);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('client: catalog, booking by chat and by calendar, moving, cancelling, rating', () async {
    final api = ApiClient(baseUrl: _url);
    final auth = AuthRepository(api);
    final catalog = CatalogRepository(api);
    final booking = BookingRepository(api);

    expect(await auth.demoAvailable(), isTrue);
    final email = _email('client');
    final user = await auth.register('E2E Client', email, 'secret1');
    expect([user.email, user.isOwner], [email, false]);

    // The catalog: ten niches, the demo businesses, filter and search.
    final catalogBloc = CatalogBloc(catalog)..add(const CatalogRequested());
    final loaded = await catalogBloc.stream.firstWhere((s) => s.status != LoadStatus.loading);
    expect(loaded.status, LoadStatus.success);
    expect(loaded.categories, hasLength(10));
    expect(loaded.businesses.length, greaterThanOrEqualTo(12));
    catalogBloc.add(const CatalogSearchChanged('маникюр'));
    final found = await catalogBloc.stream.first;
    expect(found.visible.map((b) => b.category).toSet(), {'beauty'});

    // Ask the assistant for a haircut and book the first offered slot.
    final chat = ChatBloc(booking, userName: user.name)..add(const ChatMessageSent('Стрижка завтра'));
    await chat.stream.firstWhere((s) => !s.isTyping && s.messages.length >= 3);
    final slots = chat.state.messages.last.slots;
    expect(slots, isNotEmpty);
    expect(slots.first.category, 'barber');
    chat.add(ChatSlotSelected(slots.first));
    await chat.stream.firstWhere((s) => s.revision == 1);
    final viaChat = (await booking.appointments()).single;
    expect([viaChat.source, viaChat.upcoming, viaChat.start], ['chat', true, slots.first.start]);

    // Move it through the chat, then cancel it through the chat.
    chat.add(const ChatMessageSent('перенеси мою запись'));
    await chat.stream.firstWhere((s) => !s.isTyping && s.messages.last.rescheduleId != null);
    final offer = chat.state.messages.last;
    chat.add(ChatSlotSelected(offer.slots.first, rescheduleId: offer.rescheduleId));
    await chat.stream.firstWhere((s) => s.revision == 2);
    expect((await booking.appointments()).single.start, offer.slots.first.start);
    chat.add(const ChatMessageSent('отмени запись'));
    await chat.stream.firstWhere((s) => s.revision == 3);
    expect((await booking.appointments()).single.status, 'cancelled');

    // The business page and the calendar: pick a service, a day and a time.
    final summary = loaded.businesses.firstWhere((b) => b.name == 'Стоматология Smile');
    final business = await catalog.business(summary.id);
    expect(business.services, isNotEmpty);
    expect(business.specialists, isNotEmpty);
    expect(business.reviews, isNotEmpty);
    final service = business.services.firstWhere((s) => s.durationMin == 60);
    final picker = await _picker(
      catalog,
      business.id,
      service.id,
      (slot) => booking.book(serviceId: slot.serviceId, specialistId: slot.specialistId, start: slot.start),
    );
    picker.selectSlot(picker.state.slots[2]);
    await picker.submit();
    final booked = picker.state.result!;
    expect([booked.businessName, booked.serviceName, booked.source], [business.name, service.name, 'app']);

    // "My bookings": the new one is ahead, the cancelled one is history.
    final appointments = AppointmentsBloc(booking)..add(const AppointmentsRequested());
    var mine = await appointments.stream.firstWhere((s) => s.status == LoadStatus.success);
    expect(mine.upcoming.single.id, booked.id);
    expect(mine.history.single.status, 'cancelled');

    // Move it: while it is being moved, its own time counts as free for its client.
    final mover = await _picker(
      catalog,
      booked.businessId,
      booked.serviceId,
      (slot) => booking.reschedule(booked.id, slot.start),
      excludeAppointmentId: booked.id,
      specialistId: booked.specialistId,
    );
    await mover.selectDay(_dayOf(booked.start));
    expect(mover.state.slots.map((s) => s.start), contains(booked.start));
    // Half an hour later overlaps the old time: possible only because of the rule above.
    final later = booked.start.add(const Duration(minutes: 30));
    final target = mover.state.slots.firstWhere((s) => s.start == later, orElse: () => mover.state.slots.last);
    mover.selectSlot(target);
    await mover.submit();
    expect(mover.state.result?.start, target.start);

    appointments.add(AppointmentCancelled(booked.id));
    mine = await appointments.stream.first;
    expect(mine.upcoming, isEmpty);
    expect(mine.history, hasLength(2));

    // The saved token signs the user in again after an app restart.
    final restored = await AuthRepository(ApiClient(baseUrl: _url)).restoreSession();
    expect(restored?.email, email);

    // A wrong password is rejected with the server's message.
    await expectLater(
      AuthRepository(ApiClient(baseUrl: _url)).login(email, 'wrong-password'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );

    // The demo client has a finished visit: rate it.
    final demo = await auth.demoLogin('customer');
    expect(demo.isOwner, isFalse);
    final visit = (await booking.appointments()).firstWhere((a) => a.canReview);
    final rated = await booking.review(visit.id, 5, 'E2E: всё отлично');
    expect([rated.reviewRating, rated.canReview], [5, false]);
  });

  test('owner: new business, services and staff, bookings from both sides, statistics', () async {
    final api = ApiClient(baseUrl: _url);
    final auth = AuthRepository(api);
    final catalog = CatalogRepository(api);
    final owner = OwnerRepository(api);

    final user = await auth.register('E2E Owner', _email('owner'), 'secret1', role: 'owner');
    expect(user.isOwner, isTrue);

    // No business yet, then one created from the barbershop template.
    final cubit = OwnerCubit(owner, catalog);
    await cubit.load();
    expect([cubit.state.status, cubit.state.business], [LoadStatus.success, null]);
    final name = 'E2E Barber ${DateTime.now().millisecondsSinceEpoch}';
    expect(
      await cubit.createBusiness(category: 'barber', name: name, address: 'ул. Тестовая, 1', openHour: 8, closeHour: 22,
          workingDays: [0, 1, 2, 3, 4, 5, 6]),
      isTrue,
      reason: cubit.state.error,
    );
    var business = cubit.state.business!;
    expect(business.services.map((s) => s.name), contains('Мужская стрижка'));
    expect(business.specialists.single.name, 'E2E Owner');

    // A service of its own and a second specialist.
    expect(await cubit.saveService(name: 'Королевское бритьё', durationMin: 30, price: 700), isTrue);
    expect(await cubit.saveSpecialist(name: 'Данияр', title: 'Барбер'), isTrue);
    business = cubit.state.business!;
    final shave = business.services.firstWhere((s) => s.name == 'Королевское бритьё');
    expect(business.specialists, hasLength(2));
    // A service needs at least one performer.
    expect(await cubit.saveService(id: shave.id, name: shave.name, durationMin: 30, price: 800, specialistIds: []), isFalse);
    expect(cubit.state.error, isNotNull);

    // Clients see the new business in the catalog at once.
    final listed = (await catalog.businesses(category: 'barber')).firstWhere((b) => b.name == name);
    expect([listed.priceFrom != null, listed.rating], [true, null]);

    // A client books there through the calendar.
    final clientApi = ApiClient(baseUrl: _url);
    await AuthRepository(clientApi).register('E2E Guest', _email('guest'), 'secret1');
    final clientCatalog = CatalogRepository(clientApi);
    final clientBooking = BookingRepository(clientApi);
    final haircut = business.services.firstWhere((s) => s.name == 'Мужская стрижка');
    final picker = await _picker(
      clientCatalog,
      business.id,
      haircut.id,
      (slot) => clientBooking.book(serviceId: slot.serviceId, specialistId: slot.specialistId, start: slot.start),
    );
    picker.selectSlot(picker.state.slots.last);
    await picker.submit();
    final fromClient = picker.state.result!;

    // The owner sees it and adds a walk-in client by hand on the same day.
    final agenda = OwnerAgendaCubit(owner);
    await agenda.load(fromClient.start);
    expect(agenda.state.items.single.clientName, 'E2E Guest');
    expect(agenda.state.items.single.source, 'app');

    final manual = await _picker(
      catalog,
      business.id,
      shave.id,
      (slot) => owner.book(serviceId: slot.serviceId, specialistId: slot.specialistId, start: slot.start,
          clientName: 'Гость с улицы', clientPhone: '+996 700 000 000'),
    );
    await manual.selectDay(_dayOf(fromClient.start));
    manual.selectSlot(manual.state.slots.first);
    await manual.submit();
    await agenda.added(manual.state.result!);
    expect(agenda.state.items.map((a) => a.source).toSet(), {'app', 'owner'});
    expect(agenda.state.items.firstWhere((a) => a.source == 'owner').clientPhone, '+996 700 000 000');

    // Statuses and the dashboard.
    final walkIn = agenda.state.items.firstWhere((a) => a.source == 'owner');
    expect(await agenda.setStatus(walkIn.id, 'no_show'), isTrue);
    expect(await agenda.setStatus(walkIn.id, 'booked'), isTrue);
    final stats = OwnerStatsCubit(owner);
    await stats.load();
    expect(stats.state.status, LoadStatus.success);
    expect(stats.state.stats.upcoming, 2);
    expect(stats.state.stats.byDay, hasLength(7));

    // Pausing bookings hides the business from clients.
    expect(await cubit.updateBusiness(isActive: false), isTrue);
    expect((await clientCatalog.businesses(category: 'barber')).map((b) => b.name), isNot(contains(name)));

    // The demo owner's cabinet has a week of history behind it.
    await auth.demoLogin('owner');
    final demoStats = await owner.stats();
    expect(demoStats.bookings, greaterThan(0));
    expect(demoStats.topServices, isNotEmpty);
    expect(demoStats.rating, isNotNull);
    final demoBusiness = await owner.business();
    expect(demoBusiness?.name, 'Стоматология Smile');
  });
}
