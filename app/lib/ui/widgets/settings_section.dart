import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/auth_bloc.dart';
import '../../bloc/settings_cubit.dart';
import '../../core/config.dart';
import '../../core/strings.dart';
import '../../data/models.dart';
import 'common.dart';

/// Who is signed in.
class AccountCard extends StatelessWidget {
  const AccountCard({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final initial = user.name.isEmpty ? '?' : user.name.characters.first.toUpperCase();
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: scheme.primary,
            child: Text(initial, style: TextStyle(color: scheme.onPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                Text(user.email, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(
                  user.isOwner ? strings.accountOwner : strings.accountClient,
                  style: text.labelMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Theme, language, the server in use and sign-out.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state;
    final strings = settings.strings;
    final cubit = context.read<SettingsCubit>();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.dns_outlined, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${strings.server}: ${settings.serverUrl.isEmpty ? AppConfig.defaultApiUrl : settings.serverUrl}',
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
          icon: const Icon(Icons.logout),
          label: Text(strings.logout),
        ),
        const SizedBox(height: 16),
        Text(
          strings.about,
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
