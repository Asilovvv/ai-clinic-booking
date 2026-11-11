import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/appointments_bloc.dart';
import 'bloc/auth_bloc.dart';
import 'bloc/chat_bloc.dart';
import 'bloc/doctors_bloc.dart';
import 'bloc/settings_cubit.dart';
import 'core/api_client.dart';
import 'data/auth_repository.dart';
import 'data/clinic_repository.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme.dart';

void main() {
  final api = ApiClient();
  runApp(ClinicApp(
    authRepository: AuthRepository(api),
    clinicRepository: ClinicRepository(api),
  ));
}

class ClinicApp extends StatelessWidget {
  const ClinicApp({super.key, required this.authRepository, required this.clinicRepository});

  final AuthRepository authRepository;
  final ClinicRepository clinicRepository;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: clinicRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => SettingsCubit()..load()),
          BlocProvider(create: (_) => AuthBloc(authRepository)..add(const AuthStarted())),
        ],
        child: BlocBuilder<SettingsCubit, SettingsState>(
          buildWhen: (prev, curr) => prev.themeMode != curr.themeMode,
          builder: (context, settings) => MaterialApp(
            title: 'Smile AI',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            themeMode: settings.themeMode,
            home: const AppGate(),
          ),
        ),
      ),
    );
  }
}

/// Decides what to show: splash, onboarding, login or the main app.
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state;
    if (!settings.loaded) return const SplashScreen();
    if (!settings.onboardingDone) return const OnboardingScreen();
    final settingsCubit = context.read<SettingsCubit>();

    return BlocBuilder<AuthBloc, AuthState>(
      // Keep the login form on screen while a request is in flight.
      buildWhen: (prev, curr) => curr is! AuthLoading,
      builder: (context, state) {
        return switch (state) {
          AuthAuthenticated(:final user) => MultiBlocProvider(
              key: ValueKey(user.id),
              providers: [
                BlocProvider(
                  create: (context) => ChatBloc(
                    context.read<ClinicRepository>(),
                    userName: user.name,
                    strings: () => settingsCubit.state.strings,
                  ),
                ),
                BlocProvider(
                  create: (context) =>
                      AppointmentsBloc(context.read<ClinicRepository>())..add(const AppointmentsRequested()),
                ),
                BlocProvider(
                  create: (context) =>
                      DoctorsBloc(context.read<ClinicRepository>())..add(const DoctorsRequested()),
                ),
              ],
              child: HomeScreen(user: user),
            ),
          AuthUnauthenticated() => const LoginScreen(),
          _ => const SplashScreen(),
        };
      },
    );
  }
}
