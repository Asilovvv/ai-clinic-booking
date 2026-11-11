import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/appointments_bloc.dart';
import '../../bloc/auth_bloc.dart';
import '../../bloc/chat_bloc.dart';
import '../../data/models.dart';
import 'appointments_screen.dart';
import 'chat_screen.dart';
import 'doctors_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user});

  final User user;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _titles = ['ИИ-администратор', 'Мои записи', 'Врачи'];

  void _bookWithDoctor(Doctor doctor) {
    setState(() => _index = 0);
    context
        .read<ChatBloc>()
        .add(ChatMessageSent('Хочу записаться: ${doctor.title.toLowerCase()}, ${doctor.name}'));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatBloc, ChatState>(
      // A booking made in chat must show up in "My appointments".
      listenWhen: (prev, curr) => prev.lastBooked != curr.lastBooked && curr.lastBooked != null,
      listener: (context, state) =>
          context.read<AppointmentsBloc>().add(const AppointmentsRequested()),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_titles[_index], style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                'Клиника Smile · ${widget.user.name}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
              tooltip: 'Выйти',
              onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
              icon: const Icon(Icons.logout),
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
              const NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: 'Ассистент',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: state.items.isNotEmpty,
                  label: Text('${state.items.length}'),
                  child: const Icon(Icons.event_note_outlined),
                ),
                selectedIcon: const Icon(Icons.event_note),
                label: 'Записи',
              ),
              const NavigationDestination(
                icon: Icon(Icons.medical_services_outlined),
                selectedIcon: Icon(Icons.medical_services),
                label: 'Врачи',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
