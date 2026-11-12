import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/auth_bloc.dart';
import '../../bloc/load_status.dart';
import '../../bloc/owner_agenda_cubit.dart';
import '../../bloc/owner_cubit.dart';
import '../../bloc/owner_stats_cubit.dart';
import '../../bloc/settings_cubit.dart';
import '../../data/models.dart';
import '../widgets/common.dart';
import 'agenda_screen.dart';
import 'business_tab.dart';
import 'services_screen.dart';
import 'setup_screen.dart';
import 'today_screen.dart';

/// Decides what an owner sees: the setup form until a business exists, then the cabinet.
class OwnerGate extends StatelessWidget {
  const OwnerGate({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return BlocBuilder<OwnerCubit, OwnerState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status || (prev.business == null) != (curr.business == null),
      builder: (context, state) {
        if (state.business != null) return OwnerShell(user: user);
        return switch (state.status) {
          LoadStatus.success => const SetupScreen(),
          LoadStatus.failure => Scaffold(
              body: EmptyState(
                icon: Icons.cloud_off_outlined,
                title: strings.loadError,
                text: state.error,
                action: Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.tonal(
                      onPressed: () => context.read<OwnerCubit>().load(),
                      child: Text(strings.retry),
                    ),
                    TextButton(
                      onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
                      child: Text(strings.logout),
                    ),
                  ],
                ),
              ),
            ),
          _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
        };
      },
    );
  }
}

/// The owner's cabinet: dashboard, schedule, services and the business card.
class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key, required this.user});

  final User user;

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    context.read<OwnerAgendaCubit>().load();
    context.read<OwnerStatsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final businessName = context.select((OwnerCubit cubit) => cubit.state.business?.name ?? '');
    final titles = [strings.tabToday, strings.tabAppointments, strings.services, strings.tabBusiness];
    return MultiBlocListener(
      listeners: [
        // A new booking or a changed status moves the dashboard's numbers.
        BlocListener<OwnerAgendaCubit, OwnerAgendaState>(
          listenWhen: (prev, curr) => prev.revision != curr.revision,
          listener: (context, state) => context.read<OwnerStatsCubit>().load(),
        ),
        BlocListener<OwnerAgendaCubit, OwnerAgendaState>(
          listenWhen: (prev, curr) =>
              curr.error != null && prev.error != curr.error && curr.status != LoadStatus.failure,
          listener: (context, state) => showMessage(context, state.error!),
        ),
        BlocListener<OwnerCubit, OwnerState>(
          listenWhen: (prev, curr) => curr.error != null && prev.error != curr.error,
          listener: (context, state) => showMessage(context, state.error!),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titles[_index], style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(businessName, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        body: IndexedStack(
          index: _index,
          children: [
            const TodayScreen(),
            const AgendaScreen(),
            const ServicesScreen(),
            BusinessTab(user: widget.user),
          ],
        ),
        floatingActionButton: _index < 2
            ? FloatingActionButton.extended(
                onPressed: () => startManualBooking(context),
                icon: const Icon(Icons.add),
                label: Text(strings.newBooking),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) {
            hideMessage(context);
            setState(() => _index = i);
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard),
              label: strings.tabToday,
            ),
            NavigationDestination(
              icon: const Icon(Icons.event_note_outlined),
              selectedIcon: const Icon(Icons.event_note),
              label: strings.tabAppointments,
            ),
            NavigationDestination(
              icon: const Icon(Icons.design_services_outlined),
              selectedIcon: const Icon(Icons.design_services),
              label: strings.services,
            ),
            NavigationDestination(
              icon: const Icon(Icons.storefront_outlined),
              selectedIcon: const Icon(Icons.storefront),
              label: strings.tabBusiness,
            ),
          ],
        ),
      ),
    );
  }
}
