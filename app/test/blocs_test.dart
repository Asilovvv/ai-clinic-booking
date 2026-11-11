import 'package:ai_clinic/bloc/appointments_bloc.dart';
import 'package:ai_clinic/bloc/auth_bloc.dart';
import 'package:ai_clinic/bloc/doctors_bloc.dart';
import 'package:ai_clinic/bloc/settings_cubit.dart';
import 'package:ai_clinic/core/strings.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  blocTest<AuthBloc, AuthState>(
    'login: wrong password -> error, right password -> authenticated',
    build: () => AuthBloc(FakeAuthRepository()),
    act: (bloc) async {
      bloc.add(const AuthLoginRequested('demo@smile.kg', 'wrong'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const AuthLoginRequested('demo@smile.kg', 'secret1'));
    },
    expect: () => [
      const AuthLoading(),
      const AuthUnauthenticated(error: 'Неверный email или пароль'),
      const AuthLoading(),
      const AuthAuthenticated(testUser),
    ],
  );

  blocTest<DoctorsBloc, DoctorsState>(
    'specialists load and filter by category',
    build: () => DoctorsBloc(FakeClinicRepository()),
    act: (bloc) async {
      bloc.add(const DoctorsRequested());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const DoctorsCategorySelected('barber'));
    },
    verify: (bloc) {
      expect(bloc.state.categories, hasLength(3));
      expect(bloc.state.doctors, hasLength(5));
      expect(bloc.state.visible.map((d) => d.id), [6, 7]);
    },
  );

  blocTest<AppointmentsBloc, AppointmentsState>(
    'appointments load and cancel',
    build: () {
      final repo = FakeClinicRepository();
      repo.book(testSlot(14));
      repo.book(testSlot(15, doctor: 2));
      return AppointmentsBloc(repo);
    },
    act: (bloc) async {
      bloc.add(const AppointmentsRequested());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const AppointmentCancelled(7));
    },
    verify: (bloc) {
      expect(bloc.state.status, LoadStatus.success);
      expect(bloc.state.items.map((a) => a.id), [8]);
    },
  );

  test('settings are saved and restored', () async {
    SharedPreferences.setMockInitialValues({});
    final cubit = SettingsCubit();
    await cubit.load();
    expect(cubit.state.loaded, isTrue);
    expect(cubit.state.onboardingDone, isFalse);

    await cubit.setLang(AppLang.en);
    await cubit.setThemeMode(ThemeMode.dark);
    await cubit.completeOnboarding();

    final restored = SettingsCubit();
    await restored.load();
    expect(restored.state.lang, AppLang.en);
    expect(restored.state.themeMode, ThemeMode.dark);
    expect(restored.state.onboardingDone, isTrue);
    expect(restored.state.strings.login, 'Sign in');
  });
}
