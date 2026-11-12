import 'package:flutter/material.dart';

import '../../bloc/settings_cubit.dart';
import '../../data/models.dart';
import '../widgets/common.dart';
import '../widgets/settings_section.dart';

/// The client's account and the app settings.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        AccountCard(user: user),
        SectionTitle(context.strings.settings),
        const SettingsSection(),
      ],
    );
  }
}
