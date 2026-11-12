import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/owner_cubit.dart';
import '../../bloc/settings_cubit.dart';
import '../../data/models.dart';
import '../widgets/common.dart';
import '../widgets/settings_section.dart';
import 'business_form.dart';

/// The business card as clients see it, the switch that hides it, and the app settings.
class BusinessTab extends StatelessWidget {
  const BusinessTab({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final state = context.watch<OwnerCubit>().state;
    final business = state.business;
    if (business == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
      children: [
        AccountCard(user: user),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SwitchListTile(
            title: Text(strings.acceptBookings, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(strings.acceptBookingsHint, style: theme.textTheme.bodySmall),
            value: business.isActive,
            onChanged: state.saving ? null : (value) => context.read<OwnerCubit>().updateBusiness(isActive: value),
          ),
        ),
        SectionTitle(strings.tabBusiness),
        BusinessForm(
          key: ValueKey('business-${business.id}'),
          initial: business,
          saving: state.saving,
          submitLabel: strings.save,
          onSubmit: (value) async {
            final saved = await context.read<OwnerCubit>().updateBusiness(
                  name: value.name,
                  description: value.description,
                  address: value.address,
                  phone: value.phone,
                  openHour: value.openHour,
                  closeHour: value.closeHour,
                  workingDays: value.workingDays,
                );
            if (saved && context.mounted) showMessage(context, strings.saved);
          },
        ),
        SectionTitle(strings.settings),
        const SettingsSection(),
      ],
    );
  }
}
