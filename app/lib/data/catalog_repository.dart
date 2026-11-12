import '../core/api_client.dart';
import '../core/formatters.dart';
import 'models.dart';

/// The public catalog: niches, businesses and free time.
class CatalogRepository {
  CatalogRepository(this._api);

  final ApiClient _api;

  Future<List<Category>> categories() async {
    final data = (await _api.get('/categories')) as List;
    return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Business>> businesses({String? category}) async {
    final data = (await _api.get('/businesses', query: {if (category != null) 'category': category})) as List;
    return data.map((e) => Business.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// One business with services, specialists and reviews.
  Future<Business> business(int id) async {
    final data = await _api.get('/businesses/$id');
    return Business.fromJson(data as Map<String, dynamic>);
  }

  /// Free start times of a service on [day], every 30 minutes.
  /// [excludeAppointmentId] frees the time of a booking that is being moved.
  Future<List<Slot>> slots(
    int businessId,
    int serviceId, {
    required DateTime day,
    int? specialistId,
    int? excludeAppointmentId,
  }) async {
    final data = (await _api.get('/businesses/$businessId/slots', query: {
      'service_id': '$serviceId',
      'date': formatApiDay(day),
      if (specialistId != null) 'specialist_id': '$specialistId',
      if (excludeAppointmentId != null) 'exclude_appointment_id': '$excludeAppointmentId',
    })) as List;
    return data.map((e) => Slot.fromJson(e as Map<String, dynamic>)).toList();
  }
}
