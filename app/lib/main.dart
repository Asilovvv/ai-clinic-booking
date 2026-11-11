import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/appointments_bloc.dart';
import 'bloc/auth_bloc.dart';
import 'bloc/chat_bloc.dart';
import 'bloc/doctors_bloc.dart';
import 'core/api_client.dart';
import 'data/auth_repository.dart';
import 'data/clinic_repository.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/theme.dart';

void main() {
  runApp(ClinicApp(api: ApiClient()));
}

class ClinicApp extends StatelessWidget {
  const ClinicApp({super.key, required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => AuthRepository(api)),
        RepositoryProvider(create: (_) => ClinicRepository(api)),
      ],
      child: BlocProvider(
        create: (context) => AuthBloc(context.read<AuthRepository>())..add(const AuthStarted()),
        child: MaterialApp(
          title: 'Smile AI',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: const AuthGate(),
        ),
      ),
    );
  }
}

/// Shows login or the main app depending on [AuthBloc] state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      // Keep the login form on screen while a request is in flight.
      buildWhen: (prev, curr) => curr is! AuthLoading,
      builder: (context, state) {
        return switch (state) {
          AuthAuthenticated(:final user) => MultiBlocProvider(
              key: ValueKey(user.id),
              providers: [
                BlocProvider(
                  create: (context) =>
                      ChatBloc(context.read<ClinicRepository>(), userName: user.name),
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
          _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
        };
      },
    );
  }
}
