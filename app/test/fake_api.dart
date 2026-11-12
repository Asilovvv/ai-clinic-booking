// An in-memory stand-in for the Smile AI server.
//
// It answers the same REST calls with JSON of the same shape, so tests and the
// screenshot tool run the real repositories, blocs and screens without a network.
import 'dart:convert';

import 'package:ai_clinic/core/api_client.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// 2030-01-07T09:00, the server's time format.
String stamp(DateTime d) => '${day(d)}T${_two(d.hour)}:${_two(d.minute)}';

/// 2030-01-07
String day(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

const demoCustomerEmail = 'demo@smile.kg';
const demoOwnerEmail = 'owner@smile.kg';

const _categories = [
  ('dental', 'Стоматология', 'Стоматолог'),
  ('clinic', 'Медицинский центр', 'Врач'),
  ('barber', 'Барбершоп', 'Барбер'),
  ('beauty', 'Салон красоты', 'Мастер'),
  ('massage', 'Массаж и СПА', 'Массажист'),
  ('fitness', 'Фитнес и спорт', 'Тренер'),
  ('auto', 'Автосервис', 'Мастер'),
  ('carwash', 'Автомойка', 'Мойка'),
  ('tutor', 'Репетиторы и курсы', 'Преподаватель'),
  ('vet', 'Ветклиника', 'Ветеринар'),
];

/// category, name, address, opens, closes, rating, reviews, services (name, minutes, price), staff (name, title)
const _businesses = [
  (
    'dental', 'Стоматология Smile', 'ул. Киевская, 95', 9, 18, 4.8, 23,
    [('Консультация и осмотр', 30, 500), ('Лечение кариеса', 60, 2500), ('Профессиональная чистка зубов', 60, 2000),
      ('Отбеливание зубов', 90, 6000)],
    [('Айгуль Садыкова', 'Терапевт-стоматолог'), ('Нурлан Абдыкадыров', 'Хирург-имплантолог'),
      ('Бакыт Осмонов', 'Гигиенист')],
  ),
  (
    'barber', 'Барбершоп Blade', 'ул. Токтогула, 125', 10, 20, 4.9, 31,
    [('Мужская стрижка', 60, 600), ('Оформление бороды', 30, 400), ('Стрижка и борода', 90, 900)],
    [('Азамат Жумабеков', 'Барбер'), ('Данияр Исаев', 'Барбер-бородист')],
  ),
  (
    'beauty', 'Салон красоты Aurora', 'ул. Исанова, 42', 9, 20, 4.7, 18,
    [('Маникюр с покрытием', 90, 1200), ('Оформление бровей', 30, 500), ('Окрашивание волос', 120, 3000)],
    [('Жанара Бекова', 'Мастер маникюра'), ('Сезим Асанова', 'Бровист-лешмейкер')],
  ),
  (
    'auto', 'Автосервис Motor', 'ул. Льва Толстого, 36', 9, 18, 4.6, 12,
    [('Компьютерная диагностика', 30, 800), ('Замена масла', 30, 1000), ('Шиномонтаж', 60, 1200)],
    [('Тимур Касымов', 'Диагност-электрик'), ('Руслан Ибраимов', 'Автомеханик')],
  ),
  (
    'massage', 'Relax SPA', 'ул. Горького, 27', 10, 21, 4.9, 15,
    [('Классический массаж', 60, 1500), ('Массаж спины', 30, 800)],
    [('Гульнара Исакова', 'Массажист')],
  ),
  (
    'fitness', 'FitZone', 'ул. Байтик Баатыра, 61', 7, 22, 4.5, 9,
    [('Персональная тренировка', 60, 1000), ('Йога', 60, 600)],
    [('Эмиль Чотбаев', 'Персональный тренер'), ('Айпери Нурланова', 'Инструктор йоги')],
  ),
  (
    'carwash', 'Автомойка Aqua', 'ул. Жибек Жолу, 310', 8, 22, 4.4, 7,
    [('Комплексная мойка', 60, 700), ('Экспресс-мойка', 30, 400)],
    [('Бокс 1', 'Мойка'), ('Бокс 2', 'Мойка')],
  ),
  (
    'tutor', 'Учебный центр Bilim', 'ул. Абдрахманова, 170', 9, 20, 4.8, 11,
    [('Английский язык', 60, 700), ('Подготовка к ОРТ', 90, 900)],
    [('Айдана Осмонова', 'Преподаватель английского')],
  ),
  (
    'vet', 'Ветклиника ZooDoc', 'ул. Суюмбаева, 14', 9, 19, 4.7, 8,
    [('Приём ветеринара', 30, 700), ('Вакцинация', 30, 900), ('Груминг', 60, 1500)],
    [('Нурбек Сыдыков', 'Ветеринар')],
  ),
  (
    'clinic', 'Медцентр Vita', 'ул. Московская, 189', 8, 18, 4.6, 14,
    [('Приём терапевта', 30, 800), ('УЗИ', 30, 1200)],
    [('Гульмира Асанбекова', 'Терапевт'), ('Канат Орозбеков', 'Врач УЗИ')],
  ),
];

/// What the chat understands: word stem -> (business index, service index).
const _chatKeywords = [
  ('стриж', 1, 0), ('haircut', 1, 0), ('бород', 1, 1),
  ('маникюр', 2, 0), ('бров', 2, 1),
  ('масл', 3, 1), ('диагност', 3, 0),
  ('массаж', 4, 0),
  ('чистк', 0, 2), ('отбел', 0, 3), ('зуб', 0, 1), ('tooth', 0, 1),
];

class FakeApi extends ApiClient {
  /// [now] fixes the clock; by default the data is laid out around the real time.
  FakeApi({DateTime? now, this.offline = false, this.demo = true})
      : now = now ?? DateTime.now(),
        super(baseUrl: 'http://fake.test') {
    _seed();
  }

  final DateTime now;

  /// Every call fails as if there were no connection.
  bool offline;

  /// The server offers demo accounts.
  final bool demo;

  /// Calls made so far, as "POST /chat".
  final List<String> calls = [];

  /// Body of the latest POST or PATCH and query of the latest GET.
  Map<String, dynamic>? lastBody;
  Map<String, String>? lastQuery;

  final List<Map<String, dynamic>> users = [];
  final Map<String, String> _passwords = {};
  final Map<String, int> _tokens = {};
  final List<Map<String, dynamic>> businesses = [];
  final Map<int, int> _owners = {};
  final List<Map<String, dynamic>> appointments = [];
  int _nextId = 1000;

  DateTime get today => DateTime(now.year, now.month, now.day);

  // ------------------------------------------------------------------ seed

  void _seed() {
    _addUser('Бектур', demoOwnerEmail, 'demo1234', 'owner');
    _addUser('Айдай', demoCustomerEmail, 'demo1234', 'customer');
    var serviceId = 1;
    var specialistId = 1;
    for (final (category, name, address, open, close, rating, reviews, services, staff) in _businesses) {
      final id = businesses.length + 1;
      final staffIds = [for (final _ in staff) specialistId++];
      businesses.add({
        'id': id,
        'category': category,
        'name': name,
        'description': 'Запись онлайн и через ИИ-администратора.',
        'address': address,
        'phone': '+996 555 100 20$id',
        'open_hour': open,
        'close_hour': close,
        'working_days': [0, 1, 2, 3, 4, 5, 6],
        'is_active': true,
        'rating': rating,
        'reviews_count': reviews,
        'services': <Map<String, dynamic>>[
          for (final (i, (serviceName, minutes, price)) in services.indexed)
            {
              'id': serviceId++,
              'name': serviceName,
              'description': '',
              'duration_min': minutes,
              'price': price,
              // The first service is done by everyone, the rest take turns.
              'specialist_ids': i == 0 ? [...staffIds] : [staffIds[i % staffIds.length]],
            },
        ],
        'specialists': <Map<String, dynamic>>[
          for (final (i, (staffName, title)) in staff.indexed) {'id': staffIds[i], 'name': staffName, 'title': title},
        ],
        'reviews': <Map<String, dynamic>>[
          {'rating': 5, 'comment': 'Записалась за минуту, приняли вовремя.', 'created_at': stamp(now), 'author': 'Алина'},
          {'rating': 4, 'comment': 'Хорошо, но пришлось немного подождать.', 'created_at': stamp(now), 'author': 'Тилек'},
        ],
      });
    }
    _owners[1] = 1; // the demo owner runs the dental clinic

    // The demo client has one finished visit to rate.
    _addAppointment(businessIndex: 1, serviceIndex: 0, start: _at(-3, 12), customerId: 2, status: 'completed', source: 'chat');

    // The demo owner's clinic: a busy day around "now".
    final hour = now.hour.clamp(10, 15);
    _addAppointment(businessIndex: 0, serviceIndex: 0, start: _at(0, hour - 1), customerId: 2, status: 'completed', source: 'chat');
    _addAppointment(businessIndex: 0, serviceIndex: 1, start: _at(0, hour + 1), clientName: 'Чолпон Абдраева', source: 'chat');
    _addAppointment(businessIndex: 0, serviceIndex: 2, start: _at(0, hour + 2), clientName: 'Эрмек Турсунов', source: 'owner');
    _addAppointment(businessIndex: 0, serviceIndex: 0, start: _at(1, 10), clientName: 'Айжан Кубатова', source: 'app');
  }

  DateTime _at(int dayOffset, int hour) => DateTime(now.year, now.month, now.day + dayOffset, hour);

  Map<String, dynamic> _addUser(String name, String email, String password, String role) {
    final user = {'id': users.length + 1, 'name': name, 'email': email, 'role': role, 'phone': null};
    users.add(user);
    _passwords[email] = password;
    return user;
  }

  Map<String, dynamic> _addAppointment({
    required int businessIndex,
    required int serviceIndex,
    required DateTime start,
    int? customerId,
    int? specialistId,
    String? clientName,
    String clientPhone = '',
    String status = 'booked',
    String source = 'app',
  }) {
    final business = businesses[businessIndex];
    final service = (business['services'] as List)[serviceIndex] as Map<String, dynamic>;
    final row = {
      'id': _nextId++,
      'business_id': business['id'],
      'service_id': service['id'],
      'specialist_id': specialistId ?? (service['specialist_ids'] as List).first,
      'customer_id': customerId,
      'client_name': clientName,
      'client_phone': clientPhone,
      'start': stamp(start),
      'end': stamp(start.add(Duration(minutes: service['duration_min'] as int))),
      'duration_min': service['duration_min'],
      'price': service['price'],
      'status': status,
      'source': source,
      'review': null,
    };
    appointments.add(row);
    return row;
  }

  // ------------------------------------------------------------- transport

  @override
  Future<dynamic> get(String path, {Map<String, String>? query}) => _call('GET', path, query: query);

  @override
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _call('POST', path, body: body ?? {});

  @override
  Future<dynamic> patch(String path, Map<String, dynamic> body) => _call('PATCH', path, body: body);

  @override
  Future<dynamic> delete(String path) => _call('DELETE', path);

  Future<dynamic> _call(String method, String path, {Map<String, String>? query, Map<String, dynamic>? body}) async {
    calls.add('$method $path');
    if (query != null) lastQuery = query;
    if (body != null) lastBody = body;
    if (offline) throw ApiException(0, 'Нет связи с сервером ($baseUrl)');
    // Through JSON and back, exactly as it would arrive over the wire.
    return jsonDecode(jsonEncode(_route(method, path, query ?? const {}, body ?? const {})));
  }

  Never _fail(int status, String message) => throw ApiException(status, message);

  Map<String, dynamic> get _me {
    final id = _tokens[token];
    if (id == null) _fail(401, 'Требуется вход');
    return users.firstWhere((u) => u['id'] == id);
  }

  Map<String, dynamic> get _myBusiness {
    if (_me['role'] != 'owner') _fail(403, 'Только для владельцев бизнеса');
    final entry = _owners.entries.where((e) => e.value == _me['id']).firstOrNull;
    if (entry == null) _fail(404, 'Сначала создайте бизнес');
    return _business(entry.key);
  }

  Map<String, dynamic> _business(int id) =>
      businesses.where((b) => b['id'] == id).firstOrNull ?? _fail(404, 'Заведение не найдено');

  Map<String, dynamic> _session(Map<String, dynamic> user) {
    final value = 'token-${user['id']}-${_tokens.length}';
    _tokens[value] = user['id'] as int;
    return {'token': value, 'user': user};
  }

  dynamic _route(String method, String path, Map<String, String> query, Map<String, dynamic> body) {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    final id = parts.length > 1 ? int.tryParse(parts.last) ?? (parts.length > 2 ? int.tryParse(parts[1]) : null) : null;

    switch ((method, parts)) {
      case ('GET', ['health']):
        return {'status': 'ok'};
      case ('GET', ['config']):
        return {'name': 'Smile AI', 'version': '3.0.0', 'demo': demo, 'ai': false};

      // ---------------------------------------------------------------- auth
      case ('POST', ['auth', 'register']):
        if (users.any((u) => u['email'] == body['email'])) _fail(409, 'Пользователь с таким email уже есть');
        return _session(_addUser(
          body['name'] as String,
          body['email'] as String,
          body['password'] as String,
          body['role'] as String? ?? 'customer',
        ));
      case ('POST', ['auth', 'login']):
        final user = users.where((u) => u['email'] == body['email']).firstOrNull;
        if (user == null || _passwords[user['email']] != body['password']) _fail(401, 'Неверный email или пароль');
        return _session(user);
      case ('POST', ['auth', 'demo']):
        if (!demo) _fail(404, 'Демо-режим выключен');
        final email = body['role'] == 'owner' ? demoOwnerEmail : demoCustomerEmail;
        return _session(users.firstWhere((u) => u['email'] == email));
      case ('GET', ['me']):
        return _me;

      // ------------------------------------------------------------- catalog
      case ('GET', ['categories']):
        return [
          for (final (id, title, specialist) in _categories) {'id': id, 'title': title, 'specialist_title': specialist},
        ];
      case ('GET', ['businesses']):
        return [
          for (final b in businesses)
            if (b['is_active'] == true && (query['category'] == null || b['category'] == query['category']))
              _summary(b),
        ];
      case ('GET', ['businesses', _]):
        final business = _business(id!);
        if (business['is_active'] != true) _fail(404, 'Заведение не найдено');
        return _detail(business);
      case ('GET', ['businesses', _, 'slots']):
        return _slots(
          _business(id!),
          int.parse(query['service_id']!),
          date: query['date'] == null ? null : DateTime.parse(query['date']!),
          specialistId: query['specialist_id'] == null ? null : int.parse(query['specialist_id']!),
          excludeId: query['exclude_appointment_id'] == null ? null : int.parse(query['exclude_appointment_id']!),
        );

      // ------------------------------------------------------------ bookings
      case ('GET', ['appointments']):
        final mine = appointments.where((a) => a['customer_id'] == _me['id']).toList()
          ..sort((a, b) => (a['start'] as String).compareTo(b['start'] as String));
        return mine.map(_appointment).toList();
      case ('POST', ['appointments']):
        return _appointment(_book(
          serviceId: body['service_id'] as int,
          specialistId: body['specialist_id'] as int?,
          start: body['start'] as String,
          customerId: _me['id'] as int,
          source: body['source'] as String? ?? 'app',
        ));
      case ('PATCH', ['appointments', _]):
        final row = _mine(id!);
        if (row['status'] != 'booked') _fail(400, 'Перенести можно только активную запись');
        _checkFree(row['specialist_id'] as int, body['start'] as String, row['duration_min'] as int, excludeId: id);
        final start = DateTime.parse(body['start'] as String);
        row['start'] = stamp(start);
        row['end'] = stamp(start.add(Duration(minutes: row['duration_min'] as int)));
        return _appointment(row);
      case ('DELETE', ['appointments', _]):
        final row = _mine(id!);
        if (row['status'] != 'booked') _fail(400, 'Отменить можно только активную запись');
        row['status'] = 'cancelled';
        return _appointment(row);
      case ('POST', ['appointments', _, 'review']):
        final row = _mine(id!);
        if (_appointment(row)['can_review'] != true) _fail(400, 'Оценить можно завершённый визит, один раз');
        row['review'] = {'rating': body['rating'], 'comment': body['comment'] ?? ''};
        return _appointment(row);
      case ('POST', ['chat']):
        return _chat(body);

      // --------------------------------------------------------------- owner
      case ('GET', ['owner', 'business']):
        if (_me['role'] != 'owner') _fail(403, 'Только для владельцев бизнеса');
        final entry = _owners.entries.where((e) => e.value == _me['id']).firstOrNull;
        return entry == null ? null : _detail(_business(entry.key));
      case ('POST', ['owner', 'business']):
        if (_owners.containsValue(_me['id'])) _fail(400, 'У этого аккаунта уже есть бизнес');
        if ((body['open_hour'] as int) >= (body['close_hour'] as int)) {
          _fail(400, 'Время закрытия должно быть позже времени открытия');
        }
        final newId = businesses.length + 1;
        final specialistId = _nextId++;
        final template = body['use_template'] == true
            ? _businesses.firstWhere((b) => b.$1 == body['category'], orElse: () => _businesses.first).$8
            : const <(String, int, int)>[];
        businesses.add({
          'id': newId,
          'category': body['category'],
          'name': body['name'],
          'description': body['description'] ?? '',
          'address': body['address'] ?? '',
          'phone': body['phone'] ?? '',
          'open_hour': body['open_hour'],
          'close_hour': body['close_hour'],
          'working_days': body['working_days'],
          'is_active': true,
          'rating': null,
          'reviews_count': 0,
          'services': <Map<String, dynamic>>[
            for (final (name, minutes, price) in template)
              {'id': _nextId++, 'name': name, 'description': '', 'duration_min': minutes, 'price': price,
                'specialist_ids': [specialistId]},
          ],
          'specialists': <Map<String, dynamic>>[
            {'id': specialistId, 'name': _me['name'], 'title': 'Мастер'},
          ],
          'reviews': <Map<String, dynamic>>[],
        });
        _owners[newId] = _me['id'] as int;
        return _detail(businesses.last);
      case ('PATCH', ['owner', 'business']):
        final business = _myBusiness;
        for (final field in ['name', 'description', 'address', 'phone', 'open_hour', 'close_hour', 'working_days', 'is_active']) {
          if (body[field] != null) business[field] = body[field];
        }
        return _detail(business);
      case ('POST', ['owner', 'services']) || ('PATCH', ['owner', 'services', _]):
        final business = _myBusiness;
        final services = business['services'] as List;
        final staff = [for (final s in business['specialists'] as List) (s as Map)['id'] as int];
        final performers = (body['specialist_ids'] as List?)?.cast<int>().where(staff.contains).toList() ?? staff;
        if (performers.isEmpty) _fail(400, 'Выберите, кто выполняет услугу');
        final service = {
          'id': method == 'POST' ? _nextId++ : id,
          'name': body['name'],
          'description': body['description'] ?? '',
          'duration_min': body['duration_min'],
          'price': body['price'],
          'specialist_ids': performers,
        };
        if (method == 'POST') {
          services.add(service);
        } else {
          final index = services.indexWhere((s) => (s as Map)['id'] == id);
          if (index < 0) _fail(400, 'Услуга не найдена');
          services[index] = service;
        }
        return _detail(business);
      case ('DELETE', ['owner', 'services', _]):
        final business = _myBusiness;
        (business['services'] as List).removeWhere((s) => (s as Map)['id'] == id);
        return _detail(business);
      case ('POST', ['owner', 'specialists']):
        final business = _myBusiness;
        final specialistId = _nextId++;
        (business['specialists'] as List).add({'id': specialistId, 'name': body['name'], 'title': body['title'] ?? ''});
        for (final service in business['services'] as List) {
          ((service as Map)['specialist_ids'] as List).add(specialistId);
        }
        return _detail(business);
      case ('PATCH', ['owner', 'specialists', _]):
        final business = _myBusiness;
        final specialist = (business['specialists'] as List).firstWhere((s) => (s as Map)['id'] == id) as Map;
        specialist['name'] = body['name'];
        specialist['title'] = body['title'] ?? '';
        return _detail(business);
      case ('DELETE', ['owner', 'specialists', _]):
        final business = _myBusiness;
        final staff = business['specialists'] as List;
        if (staff.length == 1) _fail(400, 'Нельзя удалить единственного специалиста');
        staff.removeWhere((s) => (s as Map)['id'] == id);
        for (final service in business['services'] as List) {
          ((service as Map)['specialist_ids'] as List).remove(id);
        }
        return _detail(business);
      case ('GET', ['owner', 'appointments']):
        final date = query['date'] ?? day(now);
        return _agenda(_myBusiness['id'] as int, date);
      case ('POST', ['owner', 'appointments']):
        final business = _myBusiness;
        if (!(business['services'] as List).any((s) => (s as Map)['id'] == body['service_id'])) {
          _fail(400, 'Услуга не найдена');
        }
        return _appointment(_book(
          serviceId: body['service_id'] as int,
          specialistId: body['specialist_id'] as int?,
          start: body['start'] as String,
          source: 'owner',
          clientName: body['client_name'] as String,
          clientPhone: body['client_phone'] as String? ?? '',
        ));
      case ('PATCH', ['owner', 'appointments', _]):
        final business = _myBusiness;
        final row = appointments.where((a) => a['id'] == id && a['business_id'] == business['id']).firstOrNull ??
            _fail(400, 'Запись не найдена');
        row['status'] = body['status'];
        return _appointment(row);
      case ('GET', ['owner', 'stats']):
        return _stats(_myBusiness);
    }
    _fail(404, 'Not found: $method $path');
  }

  // --------------------------------------------------------------- helpers

  Map<String, dynamic> _summary(Map<String, dynamic> b) {
    final services = b['services'] as List;
    final prices = [for (final s in services) (s as Map)['price'] as int]..sort();
    final category = _categories.firstWhere((c) => c.$1 == b['category']).$2;
    return {
      for (final key in ['id', 'category', 'name', 'description', 'address', 'phone', 'open_hour', 'close_hour',
        'working_days', 'is_active', 'rating', 'reviews_count']) key: b[key],
      'price_from': prices.isEmpty ? null : prices.first,
      'services_count': services.length,
      'search_text': [b['name'], b['address'], b['description'], category, for (final s in services) (s as Map)['name']]
          .join(' ')
          .toLowerCase()
          .replaceAll('ё', 'е'),
    };
  }

  Map<String, dynamic> _detail(Map<String, dynamic> b) =>
      {..._summary(b), 'services': b['services'], 'specialists': b['specialists'], 'reviews': b['reviews']};

  (Map<String, dynamic>, Map<String, dynamic>) _findService(int serviceId) {
    for (final business in businesses) {
      for (final service in business['services'] as List) {
        if ((service as Map)['id'] == serviceId) return (business, service.cast<String, dynamic>());
      }
    }
    _fail(400, 'Услуга недоступна для записи');
  }

  bool _busy(int specialistId, DateTime start, int minutes, {int? excludeId}) {
    final end = start.add(Duration(minutes: minutes));
    return appointments.any((a) =>
        a['specialist_id'] == specialistId &&
        a['status'] != 'cancelled' &&
        a['id'] != excludeId &&
        DateTime.parse(a['start'] as String).isBefore(end) &&
        DateTime.parse(a['end'] as String).isAfter(start));
  }

  void _checkFree(int specialistId, String start, int minutes, {int? excludeId}) {
    final moment = DateTime.parse(start);
    if (!moment.isAfter(now)) _fail(400, 'Это время уже прошло');
    if (_busy(specialistId, moment, minutes, excludeId: excludeId)) _fail(400, 'Это время уже занято');
  }

  /// Free starts of a service on [date], or the nearest ones over two weeks.
  List<Map<String, dynamic>> _slots(
    Map<String, dynamic> business,
    int serviceId, {
    DateTime? date,
    int? specialistId,
    int? excludeId,
    int limit = 48,
    int fromHour = 0,
  }) {
    final service = (business['services'] as List).cast<Map>().where((s) => s['id'] == serviceId).firstOrNull;
    if (service == null || business['is_active'] != true) return [];
    final minutes = service['duration_min'] as int;
    final staff = {for (final s in business['specialists'] as List) (s as Map)['id'] as int: s};
    final performers = [
      for (final id in service['specialist_ids'] as List)
        if (specialistId == null || id == specialistId) id as int,
    ];
    final days = date == null ? [for (var i = 0; i < 14; i++) today.add(Duration(days: i))] : [date];
    final result = <Map<String, dynamic>>[];
    for (final d in days) {
      if (!(business['working_days'] as List).contains(d.weekday - 1)) continue;
      final open = (business['open_hour'] as int) * 60;
      final close = (business['close_hour'] as int) * 60;
      for (var minute = open > fromHour * 60 ? open : fromHour * 60; minute + minutes <= close; minute += 30) {
        final start = DateTime(d.year, d.month, d.day, minute ~/ 60, minute % 60);
        if (!start.isAfter(now)) continue;
        final free = performers.where((id) => !_busy(id, start, minutes, excludeId: excludeId)).firstOrNull;
        if (free == null) continue;
        result.add({
          'business_id': business['id'],
          'business_name': business['name'],
          'category': business['category'],
          'service_id': service['id'],
          'service_name': service['name'],
          'price': service['price'],
          'duration_min': minutes,
          'specialist_id': free,
          'specialist_name': staff[free]!['name'],
          'specialist_title': staff[free]!['title'],
          'start': stamp(start),
        });
        if (result.length >= limit) return result;
      }
    }
    return result;
  }

  Map<String, dynamic> _book({
    required int serviceId,
    required String start,
    int? specialistId,
    int? customerId,
    String source = 'app',
    String? clientName,
    String clientPhone = '',
  }) {
    final (business, service) = _findService(serviceId);
    final moment = DateTime.parse(start);
    final minutes = service['duration_min'] as int;
    if (!moment.isAfter(now)) _fail(400, 'Это время уже прошло');
    final performers = [
      for (final id in service['specialist_ids'] as List)
        if (specialistId == null || id == specialistId) id as int,
    ];
    final free = performers.where((id) => !_busy(id, moment, minutes)).firstOrNull;
    if (free == null) _fail(400, 'Это время уже занято');
    return _addAppointment(
      businessIndex: businesses.indexOf(business),
      serviceIndex: (business['services'] as List).indexWhere((s) => (s as Map)['id'] == serviceId),
      start: moment,
      customerId: customerId,
      specialistId: free,
      clientName: clientName,
      clientPhone: clientPhone,
      source: source,
    );
  }

  Map<String, dynamic> _mine(int id) =>
      appointments.where((a) => a['id'] == id && a['customer_id'] == _me['id']).firstOrNull ??
      _fail(400, 'Запись не найдена');

  /// The appointment as the server returns it.
  Map<String, dynamic> _appointment(Map<String, dynamic> row) {
    final business = _business(row['business_id'] as int);
    final service = (business['services'] as List).cast<Map>().where((s) => s['id'] == row['service_id']).firstOrNull;
    final specialist =
        (business['specialists'] as List).cast<Map>().where((s) => s['id'] == row['specialist_id']).firstOrNull;
    final customer = users.where((u) => u['id'] == row['customer_id']).firstOrNull;
    final ended = !DateTime.parse(row['end'] as String).isAfter(now);
    return {
      'id': row['id'],
      'business_id': business['id'],
      'business_name': business['name'],
      'category': business['category'],
      'address': business['address'],
      'service_id': row['service_id'],
      'service_name': service?['name'] ?? '',
      'price': row['price'],
      'duration_min': row['duration_min'],
      'specialist_id': row['specialist_id'],
      'specialist_name': specialist?['name'] ?? '',
      'specialist_title': specialist?['title'] ?? '',
      'start': row['start'],
      'end': row['end'],
      'status': row['status'],
      'source': row['source'],
      'note': '',
      'client_name': customer?['name'] ?? row['client_name'] ?? '',
      'client_phone': row['client_phone'] ?? '',
      'upcoming': row['status'] == 'booked' && !ended,
      'can_review': row['customer_id'] != null &&
          ended &&
          row['review'] == null &&
          (row['status'] == 'booked' || row['status'] == 'completed'),
      'review': row['review'],
    };
  }

  List<Map<String, dynamic>> _agenda(int businessId, String date) {
    final rows = appointments
        .where((a) => a['business_id'] == businessId && (a['start'] as String).startsWith(date))
        .toList()
      ..sort((a, b) => (a['start'] as String).compareTo(b['start'] as String));
    return rows.map(_appointment).toList();
  }

  Map<String, dynamic> _stats(Map<String, dynamic> business) {
    final id = business['id'] as int;
    final todayRows = _agenda(id, day(now)).where((a) => a['status'] != 'cancelled').toList();
    int revenue(Iterable<Map<String, dynamic>> rows) =>
        rows.where((a) => a['status'] != 'no_show').fold(0, (sum, a) => sum + (a['price'] as int));
    // The six days before today are fixed numbers; today is counted from the bookings.
    const earlier = [(3, 4500), (5, 9000), (2, 3000), (6, 12500), (4, 7000), (7, 15500)];
    final byDay = [
      for (final (i, (count, sum)) in earlier.indexed)
        {'date': day(today.subtract(Duration(days: 6 - i))), 'count': count, 'revenue': sum},
      {'date': day(now), 'count': todayRows.length, 'revenue': revenue(todayRows)},
    ];
    final minutes = todayRows.fold<int>(0, (sum, a) => sum + (a['duration_min'] as int));
    final capacity =
        (business['specialists'] as List).length * ((business['close_hour'] as int) - (business['open_hour'] as int)) * 60;
    final bookings = byDay.fold<int>(0, (sum, d) => sum + (d['count'] as int));
    return {
      'days': 7,
      'today_count': todayRows.length,
      'today_revenue': revenue(todayRows),
      'load_percent': capacity == 0 ? 0 : (100 * minutes / capacity).round(),
      'upcoming': appointments
          .where((a) => a['business_id'] == id && a['status'] == 'booked' && DateTime.parse(a['start'] as String).isAfter(now))
          .length,
      'bookings': bookings,
      'revenue': byDay.fold<int>(0, (sum, d) => sum + (d['revenue'] as int)),
      'completed': 21,
      'cancelled': 2,
      'no_show': 1,
      'ai_bookings': (bookings * 0.6).round(),
      'clients': 19,
      'rating': business['rating'],
      'reviews_count': business['reviews_count'],
      'by_day': byDay,
      'top_services': [
        for (final (i, s) in (business['services'] as List).take(3).indexed)
          {'name': (s as Map)['name'], 'count': 9 - 3 * i, 'revenue': (9 - 3 * i) * (s['price'] as int)},
      ],
      'today': _agenda(id, day(now)),
    };
  }

  /// A small rule-based assistant: enough to book, move and cancel by chat.
  Map<String, dynamic> _chat(Map<String, dynamic> body) {
    final user = _me;
    final text = (body['message'] as String).toLowerCase();
    final mine = appointments.where((a) => a['customer_id'] == user['id'] && _appointment(a)['upcoming'] == true).toList();
    Map<String, dynamic> reply(String text, {List<Map<String, dynamic>> slots = const [], bool changed = false, int? rescheduleId}) =>
        {'reply': text, 'slots': slots, 'appointment': null, 'reschedule_id': rescheduleId, 'changed': changed, 'mode': 'rules'};

    if (text.contains('отмен') || text.contains('cancel')) {
      if (mine.isEmpty) return reply('У вас нет активных записей.');
      mine.first['status'] = 'cancelled';
      return reply('Запись отменена.', changed: true);
    }
    if (text.contains('перенес') || text.contains('reschedul')) {
      if (mine.isEmpty) return reply('У вас нет активных записей.');
      final row = mine.first;
      final slots = _slots(_business(row['business_id'] as int), row['service_id'] as int,
          specialistId: row['specialist_id'] as int, excludeId: row['id'] as int, limit: 4);
      return reply('Выберите новое время:', slots: slots, rescheduleId: row['id'] as int);
    }
    if (text.contains('мои записи') || text.contains('my bookings')) {
      return reply(mine.isEmpty ? 'У вас нет активных записей.' : 'Ваши записи: ${mine.length}.');
    }

    final scope = body['business_id'] as int?;
    var match = _chatKeywords.where((k) => text.contains(k.$1)).firstOrNull;
    if (scope != null) {
      // Inside one business the first matching service wins, else its first service.
      match = match != null && match.$2 == scope - 1 ? match : ('', scope - 1, 0);
    } else if (body['category'] != null && match != null && businesses[match.$2]['category'] != body['category']) {
      match = null;
    }
    if (match == null) {
      return reply('Напишите, какая услуга нужна и когда вам удобно. Например: «стрижка завтра утром».');
    }
    final business = businesses[match.$2];
    final service = (business['services'] as List)[match.$3] as Map;
    final tomorrow = today.add(const Duration(days: 1));
    final slots = _slots(business, service['id'] as int,
        date: tomorrow, specialistId: body['specialist_id'] as int?, fromHour: text.contains('утр') ? 0 : 14, limit: 4);
    return reply(
      'Нашёл свободное время: ${service['name']}, «${business['name']}», ${service['price']} сом. '
      'Нажмите на удобный слот, чтобы записаться:',
      slots: slots,
    );
  }
}
