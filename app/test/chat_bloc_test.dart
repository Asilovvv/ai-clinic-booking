import 'package:ai_clinic/bloc/chat_bloc.dart';
import 'package:ai_clinic/core/strings.dart';
import 'package:ai_clinic/data/models.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  test('initial state greets the user in the selected language', () {
    final ru = ChatBloc(FakeClinicRepository(), userName: 'Бектур');
    expect(ru.state.messages, hasLength(1));
    expect(ru.state.messages.first.text, contains('Здравствуйте, Бектур'));

    final en = ChatBloc(FakeClinicRepository(), userName: 'Bektur', strings: () => const AppStrings(AppLang.en));
    expect(en.state.messages.first.text, contains('Hello, Bektur'));
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
          .having((s) => s.messages.last.slots, 'slots', hasLength(4))
          .having((s) => s.revision, 'revision', 0),
    ],
  );

  blocTest<ChatBloc, ChatState>(
    'tapping a slot books it, clears stale suggestions and bumps revision',
    build: () => ChatBloc(FakeClinicRepository()),
    act: (bloc) async {
      bloc.add(const ChatMessageSent('болит зуб'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(ChatSlotSelected(testSlot(14)));
    },
    wait: const Duration(milliseconds: 20),
    verify: (bloc) {
      expect(bloc.state.revision, 1);
      expect(bloc.state.bookingKey, isNull);
      expect(bloc.state.messages.every((m) => m.slots.isEmpty), isTrue);
      expect(bloc.state.messages.last.appointment?.id, 7);
    },
  );

  test('reschedule: slot tap moves the existing appointment', () async {
    final repo = FakeClinicRepository();
    final bloc = ChatBloc(repo);
    bloc.add(ChatSlotSelected(testSlot(14)));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    bloc.add(const ChatMessageSent('перенеси запись'));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final offer = bloc.state.messages.last;
    expect(offer.rescheduleId, 7);

    bloc.add(ChatSlotSelected(offer.slots.first, rescheduleId: offer.rescheduleId));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(repo.booked, hasLength(1));
    expect(repo.booked.single.start.hour, 16);
    expect(bloc.state.revision, 2);
    expect(bloc.state.messages.last.text, contains('перенесена'));
  });

  test('selected category and specialist are sent to the server', () async {
    final repo = FakeClinicRepository();
    final bloc = ChatBloc(repo)..add(const ChatCategorySelected('barber'));
    bloc.add(const ChatMessageSent('стрижка', doctorId: 6));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(bloc.state.category, 'barber');
    expect(repo.lastCategory, 'barber');
    expect(repo.lastDoctorId, 6);

    bloc.add(const ChatCategorySelected(null));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.category, isNull);
  });

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
      'reschedule_id': 5,
      'changed': true,
      'slots': [
        {
          'doctor_id': 6,
          'doctor_name': 'Азамат Жумабеков',
          'doctor_title': 'Барбер',
          'category': 'barber',
          'start': '2030-01-04T09:00',
        },
      ],
    });
    expect(reply.mode, 'ai');
    expect(reply.rescheduleId, 5);
    expect(reply.changed, isTrue);
    expect(reply.slots.single.start, DateTime(2030, 1, 4, 9));
    expect(reply.slots.single.category, 'barber');
    expect(reply.slots.single.key, '6|2030-01-04T09:00');
  });
}
