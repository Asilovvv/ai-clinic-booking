import 'package:ai_clinic/bloc/load_status.dart';
import 'package:ai_clinic/bloc/owner_agenda_cubit.dart';
import 'package:ai_clinic/bloc/owner_cubit.dart';
import 'package:ai_clinic/bloc/owner_stats_cubit.dart';
import 'package:ai_clinic/data/auth_repository.dart';
import 'package:ai_clinic/data/catalog_repository.dart';
import 'package:ai_clinic/data/owner_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

void main() {
  final now = DateTime(2030, 1, 7, 12, 30); // Monday
  late FakeApi api;
  late OwnerRepository owner;
  late CatalogRepository catalog;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = FakeApi(now: now);
    owner = OwnerRepository(api);
    catalog = CatalogRepository(api);
    await AuthRepository(api).demoLogin('owner');
  });

  group('OwnerCubit', () {
    test('loads the business together with the niches', () async {
      final cubit = OwnerCubit(owner, catalog);
      await cubit.load();

      expect(cubit.state.status, LoadStatus.success);
      expect(cubit.state.business?.name, 'Стоматология Smile');
      expect(cubit.state.business?.services, hasLength(4));
      expect(cubit.state.categories, hasLength(10));
    });

    test('a new owner has no business until they create one from a niche template', () async {
      await AuthRepository(api).register('Асель', 'asel@example.kg', 'secret1', role: 'owner');
      final cubit = OwnerCubit(owner, catalog);
      await cubit.load();
      expect(cubit.state.status, LoadStatus.success);
      expect(cubit.state.business, isNull);

      final created = await cubit.createBusiness(category: 'barber', name: 'Barber Asel', openHour: 10, closeHour: 20);
      expect(created, isTrue);
      expect(cubit.state.business?.name, 'Barber Asel');
      expect(cubit.state.business?.services.map((s) => s.name), contains('Мужская стрижка'));
      // The owner is the first specialist.
      expect(cubit.state.business?.specialists.single.name, 'Асель');
    });

    test('adds, changes and removes a service', () async {
      final cubit = OwnerCubit(owner, catalog);
      await cubit.load();

      expect(await cubit.saveService(name: 'Имплантация', durationMin: 120, price: 25000), isTrue);
      final added = cubit.state.business!.services.last;
      expect(added.name, 'Имплантация');
      expect(added.specialistIds, hasLength(3)); // everyone, until the owner narrows it down

      expect(
        await cubit.saveService(id: added.id, name: 'Имплантация зуба', durationMin: 150, price: 30000, specialistIds: [2]),
        isTrue,
      );
      final changed = cubit.state.business!.services.last;
      expect([changed.name, changed.durationMin, changed.price, changed.specialistIds], ['Имплантация зуба', 150, 30000, [2]]);

      expect(await cubit.deleteService(added.id), isTrue);
      expect(cubit.state.business!.services, hasLength(4));
    });

    test('a refused change leaves the business as it was and reports why', () async {
      await AuthRepository(api).register('Асель', 'asel@example.kg', 'secret1', role: 'owner');
      final cubit = OwnerCubit(owner, catalog);
      await cubit.load();
      await cubit.createBusiness(category: 'barber', name: 'Barber Asel');
      final only = cubit.state.business!.specialists.single;

      expect(await cubit.deleteSpecialist(only.id), isFalse);
      expect(cubit.state.error, 'Нельзя удалить единственного специалиста');
      expect(cubit.state.saving, isFalse);
      expect(cubit.state.business!.specialists, hasLength(1));
    });

    test('pausing bookings hides the business from the catalog', () async {
      final cubit = OwnerCubit(owner, catalog);
      await cubit.load();

      expect(await cubit.updateBusiness(isActive: false), isTrue);
      expect(cubit.state.business?.isActive, isFalse);
      expect((await catalog.businesses()).map((b) => b.name), isNot(contains('Стоматология Smile')));
    });
  });

  group('OwnerAgendaCubit', () {
    test('offers a few days back and two weeks ahead, starting on today', () {
      final cubit = OwnerAgendaCubit(owner, today: now);
      expect(cubit.state.days.first, DateTime(2030, 1, 4));
      expect(cubit.state.days.last, DateTime(2030, 1, 20));
      expect(cubit.state.day, DateTime(2030, 1, 7));
      expect(cubit.state.today, DateTime(2030, 1, 7));
    });

    test('loads a day and switches to another one', () async {
      final cubit = OwnerAgendaCubit(owner, today: now);
      await cubit.load();
      expect(cubit.state.items.map((a) => a.clientName), ['Айдай', 'Чолпон Абдраева', 'Эрмек Турсунов']);

      await cubit.load(DateTime(2030, 1, 8));
      expect(api.lastQuery, {'date': '2030-01-08'});
      expect(cubit.state.items.single.clientName, 'Айжан Кубатова');
    });

    test('a status change updates the list and bumps the revision', () async {
      final cubit = OwnerAgendaCubit(owner, today: now);
      await cubit.load();
      final visit = cubit.state.items[1];

      expect(await cubit.setStatus(visit.id, 'no_show'), isTrue);
      expect(cubit.state.items[1].status, 'no_show');
      expect(cubit.state.revision, 1);
    });

    test('a manual booking opens its day', () async {
      final cubit = OwnerAgendaCubit(owner, today: now);
      await cubit.load();

      final booked = await owner.book(serviceId: 1, start: DateTime(2030, 1, 9, 11), clientName: 'Марат', clientPhone: '0700');
      await cubit.added(booked);

      expect(cubit.state.day, DateTime(2030, 1, 9));
      expect(cubit.state.items.single.clientName, 'Марат');
      expect(cubit.state.items.single.source, 'owner');
      expect(cubit.state.revision, 1);
    });
  });

  test('OwnerStatsCubit loads the numbers of the dashboard', () async {
    final cubit = OwnerStatsCubit(owner);
    await cubit.load();

    final stats = cubit.state.stats;
    expect(cubit.state.status, LoadStatus.success);
    expect(stats.todayCount, 3);
    expect(stats.todayRevenue, 5000);
    expect(stats.byDay, hasLength(7));
    expect(stats.byDay.last.date, DateTime(2030, 1, 7));
    expect(stats.today.map((a) => a.status), ['completed', 'booked', 'booked']);
    expect(stats.aiPercent, 60);
  });
}
