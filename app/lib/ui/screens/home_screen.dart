import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/appointments_bloc.dart';
import '../../bloc/auth_bloc.dart';
import '../../bloc/chat_bloc.dart';
import '../../bloc/settings_cubit.dart';
import '../../core/strings.dart';
import '../../data/models.dart';
import 'appointments_screen.dart';
import 'chat_screen.dart';
import 'doctors_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user, this.initialIndex = 0});

  final User user;
  final int initialIndex;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _index = widget.initialIndex;

  void _bookWithDoctor(Doctor doctor) {
    setState(() => _index = 0);
    // The server parses Russian text, so the request itself stays in Russian.
    context.read<ChatBloc>().add(
          ChatMessageSent('Хочу записаться: ${doctor.title.toLowerCase()}, ${doctor.name}',
              doctorId: doctor.id),
        );
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<SettingsCubit>()),
          BlocProvider.value(value: context.read<AuthBloc>()),
        ],
        child: const _SettingsSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final titles = [strings.titleAssistant, strings.titleAppointments, strings.tabSpecialists];
    return BlocListener<ChatBloc, ChatState>(
      // Anything booked, moved or cancelled in chat must show up in "My bookings".
      listenWhen: (prev, curr) => prev.revision != curr.revision,
      listener: (context, state) =>
          context.read<AppointmentsBloc>().add(const AppointmentsRequested()),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titles[_index], style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('Smile AI · ${widget.user.name}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          actions: [
            if (_index == 0)
              BlocBuilder<ChatBloc, ChatState>(
                buildWhen: (prev, curr) => prev.mode != curr.mode,
                builder: (context, state) => Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(state.mode == 'ai' ? Icons.bolt : Icons.offline_bolt, size: 16),
                  label: Text(state.mode == 'ai' ? 'AI' : 'Offline'),
                ),
              ),
            IconButton(
              tooltip: strings.settings,
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        body: IndexedStack(
          index: _index,
          children: [
            const ChatScreen(),
            const AppointmentsScreen(),
            DoctorsScreen(onBook: _bookWithDoctor),
          ],
        ),
        bottomNavigationBar: BlocBuilder<AppointmentsBloc, AppointmentsState>(
          buildWhen: (prev, curr) => prev.items.length != curr.items.length,
          builder: (context, state) => NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.chat_bubble_outline),
                selectedIcon: const Icon(Icons.chat_bubble),
                label: strings.tabAssistant,
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: state.items.isNotEmpty,
                  label: Text('${state.items.length}'),
                  child: const Icon(Icons.event_note_outlined),
                ),
                selectedIcon: const Icon(Icons.event_note),
                label: strings.tabAppointments,
              ),
              NavigationDestination(
                icon: const Icon(Icons.people_outline),
                selectedIcon: const Icon(Icons.people),
                label: strings.tabSpecialists,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Theme, language and sign-out.
class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state;
    final strings = settings.strings;
    final cubit = context.read<SettingsCubit>();
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(strings.settings, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Text(strings.theme, style: text.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: ThemeMode.system, label: Text(strings.themeSystem)),
                ButtonSegment(value: ThemeMode.light, label: Text(strings.themeLight)),
                ButtonSegment(value: ThemeMode.dark, label: Text(strings.themeDark)),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (value) => cubit.setThemeMode(value.first),
            ),
            const SizedBox(height: 16),
            Text(strings.language, style: text.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<AppLang>(
              showSelectedIcon: false,
              segments: [
                for (final lang in AppLang.values) ButtonSegment(value: lang, label: Text(lang.label)),
              ],
              selected: {settings.lang},
              onSelectionChanged: (value) => cubit.setLang(value.first),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                final auth = context.read<AuthBloc>();
                Navigator.pop(context);
                auth.add(const AuthLogoutRequested());
              },
              icon: const Icon(Icons.logout),
              label: Text(strings.logout),
            ),
          ],
        ),
      ),
    );
  }
}
