import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/appointments_bloc.dart';
import '../../bloc/chat_bloc.dart';
import '../../bloc/settings_cubit.dart';
import '../../data/models.dart';
import '../widgets/common.dart';
import 'appointments_screen.dart';
import 'catalog_screen.dart';
import 'chat_view.dart';
import 'profile_screen.dart';

/// The client's side of the app: catalog, AI administrator, bookings and profile.
class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key, required this.user});

  final User user;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final titles = ['Smile AI', strings.titleAssistant, strings.titleAppointments, strings.tabProfile];
    final subtitles = [strings.hello(widget.user.name), 'Smile AI', widget.user.name, 'Smile AI'];
    return BlocListener<ChatBloc, ChatState>(
      // Anything booked, moved or cancelled in the chat must show up in "My bookings".
      listenWhen: (prev, curr) => prev.revision != curr.revision,
      listener: (context, state) => context.read<AppointmentsBloc>().add(const AppointmentsRequested()),
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titles[_index], style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(subtitles[_index], style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          actions: [
            if (_index == 1) const AssistantModeChip(),
            const SizedBox(width: 12),
          ],
        ),
        body: IndexedStack(
          index: _index,
          children: [
            CatalogScreen(onOpenAssistant: () => setState(() => _index = 1)),
            const ChatView(),
            const AppointmentsScreen(),
            ProfileScreen(user: widget.user),
          ],
        ),
        bottomNavigationBar: BlocBuilder<AppointmentsBloc, AppointmentsState>(
          buildWhen: (prev, curr) => prev.upcoming.length != curr.upcoming.length,
          builder: (context, state) {
            final upcoming = state.upcoming.length;
            return NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) {
                hideMessage(context);
                setState(() => _index = i);
              },
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.explore_outlined),
                  selectedIcon: const Icon(Icons.explore),
                  label: strings.tabCatalog,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.auto_awesome_outlined),
                  selectedIcon: const Icon(Icons.auto_awesome),
                  label: strings.tabAssistant,
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: upcoming > 0,
                    label: Text('$upcoming'),
                    child: const Icon(Icons.event_note_outlined),
                  ),
                  selectedIcon: const Icon(Icons.event_note),
                  label: strings.tabAppointments,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person_outline),
                  selectedIcon: const Icon(Icons.person),
                  label: strings.tabProfile,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
