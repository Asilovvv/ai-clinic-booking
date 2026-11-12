import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/settings_cubit.dart';
import '../../core/strings.dart';

/// Globe button with a menu of interface languages.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final current = context.watch<SettingsCubit>().state.lang;
    return PopupMenuButton<AppLang>(
      tooltip: context.strings.language,
      icon: Icon(Icons.language, color: color),
      initialValue: current,
      onSelected: (lang) => context.read<SettingsCubit>().setLang(lang),
      itemBuilder: (context) => [
        for (final lang in AppLang.values) PopupMenuItem(value: lang, child: Text(lang.label)),
      ],
    );
  }
}
