import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/appointments_bloc.dart';
import 'bloc/auth_bloc.dart';
import 'bloc/catalog_bloc.dart';
import 'bloc/chat_bloc.dart';
import 'bloc/owner_agenda_cubit.dart';
import 'bloc/owner_cubit.dart';
import 'bloc/owner_stats_cubit.dart';
import 'bloc/settings_cubit.dart';
import 'core/api_client.dart';
import 'core/clock.dart';
import 'data/auth_repository.dart';
import 'data/booking_repository.dart';
import 'data/catalog_repository.dart';
import 'data/models.dart';
import 'data/owner_repository.dart';
import 'ui/customer/customer_shell.dart';
import 'ui/owner/owner_shell.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme.dart';

void main() {
  runApp(SmileApp(api: ApiClient()));
}

/// The root of the app. Everything talks to the server through one [ApiClient].
class SmileApp extends StatefulWidget {
  const SmileApp({super.key, required this.api, this.clock = const AppClock()});

  final ApiClient api;
  final AppClock clock;

  @override
  State<SmileApp> createState() => _SmileAppState();
}

class _SmileAppState extends State<SmileApp> {
  late final _authRepository = AuthRepository(widget.api);
  late final _catalogRepository = CatalogRepository(widget.api);
  late final _bookingRepository = BookingRepository(widget.api);
  late final _ownerRepository = OwnerRepository(widget.api);
  late final _settings = SettingsCubit(api: widget.api);
  late final _auth = AuthBloc(_authRepository);

  @override
  void initState() {
    super.initState();
    // The saved server address must be in place before the session is restored.
    _settings.load().whenComplete(() => _auth.add(const AuthStarted()));
  }

  @override
  void dispose() {
    _auth.close();
    _settings.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: widget.clock),
        RepositoryProvider.value(value: _authRepository),
        RepositoryProvider.value(value: _catalogRepository),
        RepositoryProvider.value(value: _bookingRepository),
        RepositoryProvider.value(value: _ownerRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _settings),
          BlocProvider.value(value: _auth),
        ],
        child: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select((SettingsCubit cubit) => cubit.state.themeMode);
    final user = context.select<AuthBloc, User?>((bloc) {
      final state = bloc.state;
      return state is AuthAuthenticated ? state.user : null;
    });
    final app = MaterialApp(
      // A new navigator for every session: nothing of the previous account stays on screen.
      key: ValueKey('app-${user?.id}'),
      title: 'Smile AI',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      builder: (context, child) => PhoneFrame(child: child!),
      home: const AppGate(),
    );
    return user == null ? app : SessionScope(key: ValueKey('session-${user.id}'), user: user, child: app);
  }
}

/// On a wide screen (a browser on a computer, a tablet) the app keeps a
/// phone's proportions: a centred column instead of cards stretched edge to edge.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  static const double maxWidth = 480;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= 600) return child;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: dark ? Colors.black : const Color(0xFFDDE5E5),
      child: Center(
        child: SizedBox(
          width: maxWidth,
          child: ClipRect(
            // Screens ask MediaQuery for the width: tell them the column's, not the window's.
            child: MediaQuery(
              data: media.copyWith(size: Size(maxWidth, media.size.height)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// The blocs that live as long as the user is signed in. They sit above the
/// navigator, so every page, sheet and dialog can reach them.
class SessionScope extends StatelessWidget {
  const SessionScope({super.key, required this.user, required this.child});

  final User user;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsCubit>();
    if (user.isOwner) {
      return MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                OwnerCubit(context.read<OwnerRepository>(), context.read<CatalogRepository>())..load(),
          ),
          BlocProvider(
            create: (context) =>
                OwnerAgendaCubit(context.read<OwnerRepository>(), today: context.read<AppClock>().now()),
          ),
          BlocProvider(create: (context) => OwnerStatsCubit(context.read<OwnerRepository>())),
        ],
        child: child,
      );
    }
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => CatalogBloc(context.read<CatalogRepository>())..add(const CatalogRequested()),
        ),
        BlocProvider(
          create: (context) => ChatBloc(
            context.read<BookingRepository>(),
            userName: user.name,
            strings: () => settings.state.strings,
          ),
        ),
        BlocProvider(
          create: (context) =>
              AppointmentsBloc(context.read<BookingRepository>())..add(const AppointmentsRequested()),
        ),
      ],
      child: child,
    );
  }
}

/// Decides what to show: splash, onboarding, sign-in or the signed-in app.
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state;
    if (!settings.loaded) return const SplashScreen();
    if (!settings.onboardingDone) return const OnboardingScreen();

    return BlocBuilder<AuthBloc, AuthState>(
      // Keep the sign-in form on screen while a request is in flight.
      buildWhen: (prev, curr) => curr is! AuthLoading,
      builder: (context, state) => switch (state) {
        AuthAuthenticated(:final user) => user.isOwner ? OwnerGate(user: user) : CustomerShell(user: user),
        AuthUnauthenticated() => const LoginScreen(),
        _ => const SplashScreen(),
      },
    );
  }
}
