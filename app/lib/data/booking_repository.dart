import '../core/api_client.dart';
import '../core/formatters.dart';
import 'models.dart';

/// The client's bookings and the AI chat.
class BookingRepository {
  BookingRepository(this._api);

  final ApiClient _api;

  /// Upcoming bookings and history, earliest first.
  Future<List<Appointment>> appointments() async {
    final data = (await _api.get('/appointments')) as List;
    return data.map((e) => Appointment.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// [source] is "app" for the catalog and "chat" for a slot offered by the assistant.
  Future<Appointment> book({
    required int serviceId,
    required DateTime start,
    int? specialistId,
    String source = 'app',
  }) async {
    final data = await _api.post('/appointments', {
      'service_id': serviceId,
      'specialist_id': specialistId,
      'start': formatApiDate(start),
      'source': source,
    });
    return Appointment.fromJson(data as Map<String, dynamic>);
  }

  /// Moves a booking to another time with the same specialist.
  Future<Appointment> reschedule(int appointmentId, DateTime start) async {
    final data = await _api.patch('/appointments/$appointmentId', {'start': formatApiDate(start)});
    return Appointment.fromJson(data as Map<String, dynamic>);
  }

  /// Returns the booking with the status "cancelled".
  Future<Appointment> cancel(int appointmentId) async {
    final data = await _api.delete('/appointments/$appointmentId');
    return Appointment.fromJson(data as Map<String, dynamic>);
  }

  /// Rates a finished visit, from 1 to 5.
  Future<Appointment> review(int appointmentId, int rating, String comment) async {
    final data = await _api.post('/appointments/$appointmentId/review', {'rating': rating, 'comment': comment});
    return Appointment.fromJson(data as Map<String, dynamic>);
  }

  /// Sends a message to the AI administrator. [businessId] keeps the answer
  /// inside one business, [category] inside one niche.
  Future<ChatReply> chat(
    String message,
    List<ChatMessage> history, {
    String? category,
    int? businessId,
    int? specialistId,
  }) async {
    final items = history
        .where((m) => !m.isError)
        .map((m) => {'role': m.role == ChatRole.user ? 'user' : 'assistant', 'text': m.text})
        .toList();
    final recent = items.length > 10 ? items.sublist(items.length - 10) : items;
    final data = await _api.post('/chat', {
      'message': message,
      'history': recent,
      'category': category,
      'business_id': businessId,
      'specialist_id': specialistId,
    });
    return ChatReply.fromJson(data as Map<String, dynamic>);
  }
}
