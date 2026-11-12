import 'package:ai_clinic/bloc/auth_bloc.dart';
import 'package:ai_clinic/bloc/settings_cubit.dart';
import 'package:ai_clinic/core/api_client.dart';
import 'package:ai_clinic/core/config.dart';
import 'package:ai_clinic/core/strings.dart';
import 'package:ai_clinic/data/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

void main() {
  late FakeApi api;
  late AuthRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = FakeApi(now: DateTime(2030, 1, 7, 12, 30));
    repository = AuthRepository(api);
  });

  group('AuthBloc', () {
    blocTest<AuthBloc, AuthState>(
      'without a saved session the app goes straight to sign-in',
      build: () => AuthBloc(repository),
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => [const AuthUnauthenticated()],
    );

    test('a saved token restores the session on the next launch', () async {
      await repository.demoLogin('customer');
      api.token = null; // a fresh start: only the device remembers the token

      final bloc = AuthBloc(AuthRepository(api))..add(const AuthStarted());
      final state = await bloc.stream.first;

      expect(state, isA<AuthAuthenticated>().having((s) => s.user.name, 'user', 'Айдай'));
      expect(api.calls.last, 'GET /me');
    });

    test('an unreachable server explains itself and keeps the token for later', () async {
      await repository.demoLogin('customer');
      api
        ..token = null
        ..offline = true;

      final bloc = AuthBloc(AuthRepository(api))..add(const AuthStarted());
      final state = await bloc.stream.first;

      expect(state, isA<AuthUnauthenticated>().having((s) => s.error, 'error', contains('Нет связи')));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNotNull);
    });

    blocTest<AuthBloc, AuthState>(
      'a wrong password ends with the server message',
      build: () => AuthBloc(repository),
      act: (bloc) => bloc.add(const AuthLoginRequested(demoCustomerEmail, 'nope')),
      expect: () => [const AuthLoading(), const AuthUnauthenticated(error: 'Неверный email или пароль')],
    );

    blocTest<AuthBloc, AuthState>(
      'registration sends the chosen role',
      build: () => AuthBloc(repository),
      act: (bloc) => bloc.add(const AuthRegisterRequested('Асель', 'asel@example.kg', 'secret1', role: 'owner')),
      expect: () => [
        const AuthLoading(),
        isA<AuthAuthenticated>().having((s) => s.user.isOwner, 'owner', isTrue),
      ],
      verify: (_) => expect(api.lastBody, containsPair('role', 'owner')),
    );

    blocTest<AuthBloc, AuthState>(
      'one tap signs in to the demo owner',
      build: () => AuthBloc(repository),
      act: (bloc) => bloc.add(const AuthDemoRequested('owner')),
      expect: () => [
        const AuthLoading(),
        isA<AuthAuthenticated>().having((s) => s.user.email, 'email', demoOwnerEmail),
      ],
    );

    test('signing out forgets the token', () async {
      await repository.demoLogin('customer');
      final bloc = AuthBloc(repository)..add(const AuthLogoutRequested());

      expect(await bloc.stream.first, const AuthUnauthenticated());
      expect(api.token, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNull);
    });
  });

  group('SettingsCubit', () {
    test('reads saved settings and points the client at the saved server', () async {
      SharedPreferences.setMockInitialValues({
        'onboarding_done': true,
        'theme_mode': 'dark',
        'lang': 'en',
        'server_url': 'https://api.example.kg',
      });
      final client = ApiClient();
      final cubit = SettingsCubit(api: client);
      await cubit.load();

      expect(cubit.state.loaded, isTrue);
      expect(cubit.state.onboardingDone, isTrue);
      expect(cubit.state.themeMode, ThemeMode.dark);
      expect(cubit.state.lang, AppLang.en);
      expect(client.baseUrl, 'https://api.example.kg');
    });

    test('a bare address gets http://, an empty one restores the built-in server', () async {
      final client = ApiClient();
      final cubit = SettingsCubit(api: client);

      await cubit.setServerUrl(' 192.168.1.5:8000/ ');
      expect(cubit.state.serverUrl, 'http://192.168.1.5:8000/');
      expect(client.baseUrl, 'http://192.168.1.5:8000');

      await cubit.setServerUrl('');
      expect(cubit.state.serverUrl, isEmpty);
      expect(client.baseUrl, AppConfig.defaultApiUrl);
    });

    test('remembers the theme, the language and that onboarding was seen', () async {
      final cubit = SettingsCubit();
      await cubit.setThemeMode(ThemeMode.light);
      await cubit.setLang(AppLang.ky);
      await cubit.completeOnboarding();

      final restored = SettingsCubit();
      await restored.load();
      expect(restored.state.themeMode, ThemeMode.light);
      expect(restored.state.lang, AppLang.ky);
      expect(restored.state.onboardingDone, isTrue);
    });
  });
}
