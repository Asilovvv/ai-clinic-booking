import 'package:ai_clinic/core/api_client.dart';
import 'package:ai_clinic/data/auth_repository.dart';
import 'package:ai_clinic/data/clinic_repository.dart';
import 'package:ai_clinic/data/models.dart';

const testUser = User(id: 1, name: 'Бектур', email: 'demo@smile.kg');

const testCategories = [
  Category(id: 'dental', title: 'Стоматология', place: 'Клиника Smile'),
  Category(id: 'barber', title: 'Барбершоп', place: 'Барбершоп Blade'),
  Category(id: 'auto', title: 'Автосервис', place: 'Автосервис Motor'),
];

const testDoctors = [
  Doctor(id: 1, name: 'Айгуль Садыкова', specialty: 'therapist', title: 'Терапевт-стоматолог', description: 'Лечение кариеса, пломбы, боль в зубе'),
  Doctor(id: 3, name: 'Элина Ким', specialty: 'orthodontist', title: 'Ортодонт', description: 'Брекеты, элайнеры, прикус'),
  Doctor(id: 6, name: 'Азамат Жумабеков', specialty: 'haircut', title: 'Барбер', description: 'Мужские стрижки, укладка', category: 'barber'),
  Doctor(id: 7, name: 'Данияр Исаев', specialty: 'beard', title: 'Барбер-бородист', description: 'Борода, усы, бритьё', category: 'barber'),
  Doctor(id: 9, name: 'Руслан Ибраимов', specialty: 'mechanic', title: 'Автомеханик', description: 'ТО, замена масла, ходовая, тормоза', category: 'auto'),
];

Slot testSlot(int hour, {int doctor = 0}) => Slot(
      doctorId: testDoctors[doctor].id,
      doctorName: testDoctors[doctor].name,
      doctorTitle: testDoctors[doctor].title,
      category: testDoctors[doctor].category,
      start: DateTime(2030, 1, 4, hour),
    );

Appointment _appointment(int id, Slot slot) => Appointment(
      id: id,
      doctorId: slot.doctorId,
      doctorName: slot.doctorName,
      doctorTitle: slot.doctorTitle,
      category: slot.category,
      start: slot.start,
    );

/// In-memory stand-in for the server.
class FakeClinicRepository implements ClinicRepository {
  FakeClinicRepository({this.failChat = false, List<Appointment>? booked}) : booked = booked ?? [];

  final bool failChat;
  final List<Appointment> booked;

  /// Arguments of the last chat call, for assertions.
  String? lastCategory;
  int? lastDoctorId;

  @override
  Future<ChatReply> chat(String message, List<ChatMessage> history, {String? category, int? doctorId}) async {
    if (failChat) throw ApiException(0, 'Нет связи с сервером');
    lastCategory = category;
    lastDoctorId = doctorId;
    if (message.contains('перенеси') && booked.isNotEmpty) {
      return ChatReply(
        reply: 'Выберите новое время:',
        slots: [testSlot(16)],
        appointment: null,
        mode: 'rules',
        rescheduleId: booked.first.id,
      );
    }
    final doctor = message.toLowerCase().contains('стриж') ? 2 : 0;
    return ChatReply(
      reply: 'Нашёл свободное время: ${testDoctors[doctor].title.toLowerCase()}. '
          'Нажмите на удобный слот, чтобы записаться:',
      slots: [for (final hour in [14, 15, 16, 17]) testSlot(hour, doctor: doctor)],
      appointment: null,
      mode: 'rules',
    );
  }

  @override
  Future<Appointment> book(Slot slot) async {
    final appointment = _appointment(booked.length + 7, slot);
    booked.add(appointment);
    return appointment;
  }

  @override
  Future<Appointment> reschedule(int appointmentId, Slot slot) async {
    final index = booked.indexWhere((a) => a.id == appointmentId);
    booked[index] = _appointment(appointmentId, slot);
    return booked[index];
  }

  @override
  Future<List<Appointment>> appointments() async => List.of(booked);

  @override
  Future<void> cancel(int appointmentId) async => booked.removeWhere((a) => a.id == appointmentId);

  @override
  Future<List<Category>> categories() async => testCategories;

  @override
  Future<List<Doctor>> doctors() async => testDoctors;
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.signedIn = false});

  bool signedIn;

  @override
  Future<User?> restoreSession() async => signedIn ? testUser : null;

  @override
  Future<User> login(String email, String password) async {
    if (password != 'secret1') throw ApiException(401, 'Неверный email или пароль');
    signedIn = true;
    return testUser;
  }

  @override
  Future<User> register(String name, String email, String password) async {
    signedIn = true;
    return testUser;
  }

  @override
  Future<void> logout() async => signedIn = false;
}
