import '../core/api_client.dart';
import '../core/formatters.dart';
import 'models.dart';

/// The owner's cabinet: the business, its services and staff, the schedule and statistics.
class OwnerRepository {
  OwnerRepository(this._api);

  final ApiClient _api;

  static Business _business(dynamic data) => Business.fromJson(data as Map<String, dynamic>);

  /// The owner's business, or null when it has not been created yet.
  Future<Business?> business() async {
    final data = await _api.get('/owner/business');
    return data == null ? null : _business(data);
  }

  /// With [useTemplate] the typical services of the niche are added at once.
  Future<Business> createBusiness({
    required String category,
    required String name,
    String description = '',
    String address = '',
    String phone = '',
    int openHour = 9,
    int closeHour = 18,
    List<int> workingDays = const [0, 1, 2, 3, 4, 5],
    bool useTemplate = true,
  }) async =>
      _business(await _api.post('/owner/business', {
        'category': category,
        'name': name,
        'description': description,
        'address': address,
        'phone': phone,
        'open_hour': openHour,
        'close_hour': closeHour,
        'working_days': workingDays,
        'use_template': useTemplate,
      }));

  /// Changes only the fields that are given.
  Future<Business> updateBusiness({
    String? name,
    String? description,
    String? address,
    String? phone,
    int? openHour,
    int? closeHour,
    List<int>? workingDays,
    bool? isActive,
  }) async =>
      _business(await _api.patch('/owner/business', {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (address != null) 'address': address,
        if (phone != null) 'phone': phone,
        if (openHour != null) 'open_hour': openHour,
        if (closeHour != null) 'close_hour': closeHour,
        if (workingDays != null) 'working_days': workingDays,
        if (isActive != null) 'is_active': isActive,
      }));

  /// Adds a service, or changes the one with [id]. Every call returns the updated business.
  Future<Business> saveService({
    int? id,
    required String name,
    required int durationMin,
    required int price,
    String description = '',
    List<int>? specialistIds,
  }) async {
    final body = {
      'name': name,
      'description': description,
      'duration_min': durationMin,
      'price': price,
      'specialist_ids': specialistIds,
    };
    return _business(
        id == null ? await _api.post('/owner/services', body) : await _api.patch('/owner/services/$id', body));
  }

  Future<Business> deleteService(int id) async => _business(await _api.delete('/owner/services/$id'));

  /// Adds a specialist, or renames the one with [id].
  Future<Business> saveSpecialist({int? id, required String name, String title = '', List<int>? serviceIds}) async {
    final body = {'name': name, 'title': title, 'service_ids': serviceIds};
    return _business(id == null
        ? await _api.post('/owner/specialists', body)
        : await _api.patch('/owner/specialists/$id', body));
  }

  Future<Business> deleteSpecialist(int id) async => _business(await _api.delete('/owner/specialists/$id'));

  /// The schedule of one day.
  Future<List<Appointment>> agenda(DateTime day) async {
    final data = (await _api.get('/owner/appointments', query: {'date': formatApiDay(day)})) as List;
    return data.map((e) => Appointment.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// [status] is booked, completed, no_show or cancelled.
  Future<Appointment> setStatus(int appointmentId, String status) async {
    final data = await _api.patch('/owner/appointments/$appointmentId', {'status': status});
    return Appointment.fromJson(data as Map<String, dynamic>);
  }

  /// Books a client who called or walked in.
  Future<Appointment> book({
    required int serviceId,
    required DateTime start,
    required String clientName,
    int? specialistId,
    String clientPhone = '',
  }) async {
    final data = await _api.post('/owner/appointments', {
      'service_id': serviceId,
      'specialist_id': specialistId,
      'start': formatApiDate(start),
      'client_name': clientName,
      'client_phone': clientPhone,
    });
    return Appointment.fromJson(data as Map<String, dynamic>);
  }

  Future<OwnerStats> stats({int days = 7}) async {
    final data = await _api.get('/owner/stats', query: {'days': '$days'});
    return OwnerStats.fromJson(data as Map<String, dynamic>);
  }
}
