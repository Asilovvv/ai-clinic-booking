import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/strings.dart';

class SettingsState extends Equatable {
  const SettingsState({
    this.loaded = false,
    this.onboardingDone = false,
    this.themeMode = ThemeMode.system,
    this.lang = AppLang.ru,
  });

  /// False until saved settings are read from the device.
  final bool loaded;
  final bool onboardingDone;
  final ThemeMode themeMode;
  final AppLang lang;

  AppStrings get strings => AppStrings(lang);

  SettingsState copyWith({bool? loaded, bool? onboardingDone, ThemeMode? themeMode, AppLang? lang}) =>
      SettingsState(
        loaded: loaded ?? this.loaded,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        themeMode: themeMode ?? this.themeMode,
        lang: lang ?? this.lang,
      );

  @override
  List<Object?> get props => [loaded, onboardingDone, themeMode, lang];
}

/// Theme, language and the "onboarding seen" flag, saved on the device.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit([super.initialState = const SettingsState()]);

  static const _themeKey = 'theme_mode';
  static const _langKey = 'lang';
  static const _onboardingKey = 'onboarding_done';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    emit(SettingsState(
      loaded: true,
      onboardingDone: prefs.getBool(_onboardingKey) ?? false,
      themeMode: ThemeMode.values.asNameMap()[prefs.getString(_themeKey)] ?? ThemeMode.system,
      lang: AppLang.values.asNameMap()[prefs.getString(_langKey)] ?? AppLang.ru,
    ));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    emit(state.copyWith(themeMode: mode));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  Future<void> setLang(AppLang lang) async {
    emit(state.copyWith(lang: lang));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, lang.name);
  }

  Future<void> completeOnboarding() async {
    emit(state.copyWith(onboardingDone: true));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }
}

/// Shortcut: `context.strings.login`. Rebuilds the widget when the language changes.
extension SettingsContext on BuildContext {
  AppStrings get strings => watch<SettingsCubit>().state.strings;
}
