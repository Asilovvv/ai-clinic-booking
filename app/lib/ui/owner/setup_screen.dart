import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/auth_bloc.dart';
import '../../bloc/owner_cubit.dart';
import '../../bloc/settings_cubit.dart';
import '../widgets/common.dart';
import '../widgets/language_button.dart';
import 'business_form.dart';

/// First step for a new owner: describe the business.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    return BlocConsumer<OwnerCubit, OwnerState>(
      listenWhen: (prev, curr) => curr.error != null && prev.error != curr.error,
      listener: (context, state) => showMessage(context, state.error!),
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          title: const Text('Smile AI', style: TextStyle(fontWeight: FontWeight.w700)),
          actions: [
            const LanguageButton(),
            IconButton(
              tooltip: strings.logout,
              onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Text(strings.setupTitle, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              strings.setupText,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            BusinessForm(
              categories: state.categories,
              saving: state.saving,
              submitLabel: strings.createBusiness,
              onSubmit: (value) => context.read<OwnerCubit>().createBusiness(
                    category: value.category,
                    name: value.name,
                    description: value.description,
                    address: value.address,
                    phone: value.phone,
                    openHour: value.openHour,
                    closeHour: value.closeHour,
                    workingDays: value.workingDays,
                    useTemplate: value.useTemplate,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
