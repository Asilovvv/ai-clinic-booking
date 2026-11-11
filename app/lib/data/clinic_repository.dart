import '../core/api_client.dart';
import '../core/formatters.dart';
import 'models.dart';

/// Categories, specialists, appointments and the AI chat endpoint.
class ClinicRepository {
  ClinicRepository(this._api);

  final ApiClient _api;

  Future<List<Category>> categories() async {
    final data = (await _api.get('/categories')) as List;
    return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Doctor>> doctors() async {
    final data = (await _api.get('/doctors')) as List;
    return data.map((e) => Doctor.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Appointment>> appointments() async {
    final data = (await _api.get('/appointments')) as List;
    return data.map((e) => Appointment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Appointment> book(Slot slot) async {
    final data = await _api.post('/appointments', {
      'doctor_id': slot.doctorId,
      'start': formatApiDate(slot.start),
    });
    return Appointment.fromJson(data as Map<String, dynamic>);
  }

  /// Moves an appointment to the time of [slot] (same specialist).
  Future<Appointment> reschedule(int appointmentId, Slot slot) async {
    final data = await _api.patch('/appointments/$appointmentId', {'start': formatApiDate(slot.start)});
    return Appointment.fromJson(data as Map<String, dynamic>);
  }

  Future<void> cancel(int appointmentId) async {
    await _api.delete('/appointments/$appointmentId');
  }

  Future<ChatReply> chat(
    String message,
    List<ChatMessage> history, {
    String? category,
    int? doctorId,
  }) async {
    final items = history
        .where((m) => !m.isError)
        .map((m) => {
              'role': m.role == ChatRole.user ? 'user' : 'assistant',
              'text': m.text,
            })
        .toList();
    final recent = items.length > 10 ? items.sublist(items.length - 10) : items;
    final data = await _api.post('/chat', {
      'message': message,
      'history': recent,
      'category': category,
      'doctor_id': doctorId,
    });
    return ChatReply.fromJson(data as Map<String, dynamic>);
  }
}
