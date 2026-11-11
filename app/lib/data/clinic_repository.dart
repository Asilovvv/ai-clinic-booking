import '../core/api_client.dart';
import '../core/formatters.dart';
import 'models.dart';

/// Doctors, appointments and the AI chat endpoint.
class ClinicRepository {
  ClinicRepository(this._api);

  final ApiClient _api;

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

  Future<void> cancel(int appointmentId) async {
    await _api.delete('/appointments/$appointmentId');
  }

  Future<ChatReply> chat(String message, List<ChatMessage> history) async {
    final items = history
        .where((m) => !m.isError)
        .map((m) => {
              'role': m.role == ChatRole.user ? 'user' : 'assistant',
              'text': m.text,
            })
        .toList();
    final recent = items.length > 10 ? items.sublist(items.length - 10) : items;
    final data = await _api.post('/chat', {'message': message, 'history': recent});
    return ChatReply.fromJson(data as Map<String, dynamic>);
  }
}
