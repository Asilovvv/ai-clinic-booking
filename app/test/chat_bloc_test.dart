import 'package:ai_clinic/bloc/chat_bloc.dart';
import 'package:ai_clinic/core/api_client.dart';
import 'package:ai_clinic/data/clinic_repository.dart';
import 'package:ai_clinic/data/models.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

final _slot = Slot(
  doctorId: 1,
  doctorName: 'Айгуль Садыкова',
  doctorTitle: 'Терапевт-стоматолог',
  start: DateTime(2030, 1, 4, 14),
);

class FakeClinicRepository implements ClinicRepository {
  FakeClinicRepository({this.failChat = false});

  final bool failChat;

  @override
  Future<ChatReply> chat(String message, List<ChatMessage> history) async {
    if (failChat) throw ApiException(0, 'Нет связи с сервером');
    return ChatReply(reply: 'Нашёл время', slots: [_slot], appointment: null, mode: 'rules');
  }

  @override
  Future<Appointment> book(Slot slot) async => Appointment(
        id: 7,
        doctorId: slot.doctorId,
        doctorName: slot.doctorName,
        doctorTitle: slot.doctorTitle,
        start: slot.start,
      );

  @override
  Future<List<Appointment>> appointments() async => [];

  @override
  Future<void> cancel(int appointmentId) async {}

  @override
  Future<List<Doctor>> doctors() async => [];
}

void main() {
  test('initial state greets the user', () {
    final bloc = ChatBloc(FakeClinicRepository(), userName: 'Бектур');
    expect(bloc.state.messages, hasLength(1));
    expect(bloc.state.messages.first.text, contains('Бектур'));
  });

  blocTest<ChatBloc, ChatState>(
    'message -> typing -> assistant reply with slot cards',
    build: () => ChatBloc(FakeClinicRepository()),
    act: (bloc) => bloc.add(const ChatMessageSent('болит зуб')),
    expect: () => [
      isA<ChatState>()
          .having((s) => s.isTyping, 'isTyping', true)
          .having((s) => s.messages.last.role, 'last role', ChatRole.user),
      isA<ChatState>()
          .having((s) => s.isTyping, 'isTyping', false)
          .having((s) => s.messages.last.slots, 'slots', [_slot]),
    ],
  );

  blocTest<ChatBloc, ChatState>(
    'tapping a slot books it and clears stale suggestions',
    build: () => ChatBloc(FakeClinicRepository()),
    act: (bloc) async {
      bloc.add(const ChatMessageSent('болит зуб'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(ChatSlotSelected(_slot));
    },
    wait: const Duration(milliseconds: 20),
    verify: (bloc) {
      expect(bloc.state.lastBooked?.id, 7);
      expect(bloc.state.bookingKey, isNull);
      expect(bloc.state.messages.every((m) => m.slots.isEmpty), isTrue);
      expect(bloc.state.messages.last.appointment, isNotNull);
    },
  );

  blocTest<ChatBloc, ChatState>(
    'server error becomes an error bubble',
    build: () => ChatBloc(FakeClinicRepository(failChat: true)),
    act: (bloc) => bloc.add(const ChatMessageSent('привет')),
    skip: 1,
    expect: () => [
      isA<ChatState>()
          .having((s) => s.isTyping, 'isTyping', false)
          .having((s) => s.messages.last.isError, 'isError', true),
    ],
  );

  test('ChatReply parses server JSON', () {
    final reply = ChatReply.fromJson({
      'reply': 'ok',
      'mode': 'ai',
      'appointment': null,
      'slots': [
        {'doctor_id': 3, 'doctor_name': 'Элина Ким', 'doctor_title': 'Ортодонт', 'start': '2030-01-04T09:00'},
      ],
    });
    expect(reply.mode, 'ai');
    expect(reply.slots.single.start, DateTime(2030, 1, 4, 9));
    expect(reply.slots.single.key, '3|2030-01-04T09:00');
  });
}
