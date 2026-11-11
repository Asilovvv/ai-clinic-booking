// End-to-end check of the mobile <-> server link: the real ApiClient,
// repositories and ChatBloc talk to a running FastAPI server over HTTP.
//
//   1. cd server && uvicorn app.main:app --port 8000
//   2. cd app && flutter test tool/e2e
//
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:ai_clinic/bloc/chat_bloc.dart';
import 'package:ai_clinic/core/api_client.dart';
import 'package:ai_clinic/data/auth_repository.dart';
import 'package:ai_clinic/data/clinic_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _url = String.fromEnvironment('API_URL', defaultValue: 'http://127.0.0.1:8000');

void main() {
  test('register, book by chat, reschedule, cancel, restore session', () async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiClient(baseUrl: _url);
    final auth = AuthRepository(api);
    final clinic = ClinicRepository(api);

    final email = 'e2e_${DateTime.now().microsecondsSinceEpoch}@test.kg';
    final user = await auth.register('E2E', email, 'secret1');
    expect(user.email, email);
    expect(await clinic.categories(), hasLength(3));
    expect(await clinic.doctors(), hasLength(11));

    // Ask the assistant for a haircut and book the first offered slot.
    final bloc = ChatBloc(clinic, userName: user.name);
    bloc.add(const ChatMessageSent('Стрижка завтра'));
    await bloc.stream.firstWhere((s) => !s.isTyping && s.messages.length >= 3);
    final slots = bloc.state.messages.last.slots;
    expect(slots, isNotEmpty);
    expect(slots.first.category, 'barber');

    bloc.add(ChatSlotSelected(slots.first));
    await bloc.stream.firstWhere((s) => s.revision == 1);
    expect(await clinic.appointments(), hasLength(1));

    // Move it through the chat.
    bloc.add(const ChatMessageSent('перенеси мою запись'));
    await bloc.stream.firstWhere((s) => !s.isTyping && s.messages.last.rescheduleId != null);
    final offer = bloc.state.messages.last;
    bloc.add(ChatSlotSelected(offer.slots.first, rescheduleId: offer.rescheduleId));
    await bloc.stream.firstWhere((s) => s.revision == 2);
    expect((await clinic.appointments()).single.start, offer.slots.first.start);

    // Cancel it through the chat.
    bloc.add(const ChatMessageSent('отмени запись'));
    await bloc.stream.firstWhere((s) => s.revision == 3);
    expect(await clinic.appointments(), isEmpty);

    // The saved token signs the user in again after an app restart.
    final restored = await AuthRepository(ApiClient(baseUrl: _url)).restoreSession();
    expect(restored?.email, email);

    // A wrong password is rejected with the server's message.
    await expectLater(
      auth.login(email, 'wrong-password'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
    );
  });
}
