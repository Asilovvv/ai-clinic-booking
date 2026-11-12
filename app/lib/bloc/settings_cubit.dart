import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/strings.dart';

class SettingsState extends Equatable {
  const SettingsState({
    this.loaded = false,
    this.onboardingDone = false,
    this.themeMode = ThemeMode.system,
    this.lang = AppLang.ru,
    this.serverUrl = '',
  });

  /// False until saved settings are read from the device.
  final bool loaded;
  final bool onboardingDone;
  final ThemeMode themeMode;
  final AppLang lang;

  /// Server address typed by the user; empty means the built-in one.
  final String serverUrl;

  AppStrings get strings => AppStrings(lang);

  SettingsState copyWith({
    bool? loaded,
    bool? onboardingDone,
    ThemeMode? themeMode,
    AppLang? lang,
    String? serverUrl,
  }) =>
      SettingsState(
        loaded: loaded ?? this.loaded,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        themeMode: themeMode ?? this.themeMode,
        lang: lang ?? this.lang,
        serverUrl: serverUrl ?? this.serverUrl,
      );

  @override
  List<Object?> get props => [loaded, onboardingDone, themeMode, lang, serverUrl];
}

/// Theme, language, the "onboarding seen" flag and the server address, saved on the device.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({ApiClient? api, SettingsState initialState = const SettingsState()})
      : _api = api,
        super(initialState);

  /// The client whose address follows the setting.
  final ApiClient? _api;

  static const _themeKey = 'theme_mode';
  static const _langKey = 'lang';
  static const _onboardingKey = 'onboarding_done';
  static const _serverKey = 'server_url';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString(_serverKey) ?? '';
    if (serverUrl.isNotEmpty) _api?.baseUrl = serverUrl;
    emit(SettingsState(
      loaded: true,
      onboardingDone: prefs.getBool(_onboardingKey) ?? false,
      themeMode: ThemeMode.values.asNameMap()[prefs.getString(_themeKey)] ?? ThemeMode.system,
      lang: AppLang.values.asNameMap()[prefs.getString(_langKey)] ?? AppLang.ru,
      serverUrl: serverUrl,
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

  /// Points the app at another server. An empty value restores the built-in
  /// address; "192.168.1.5:8000" is read as "http://192.168.1.5:8000".
  Future<void> setServerUrl(String value) async {
    var url = value.trim();
    if (url.isNotEmpty && !url.contains('://')) url = 'http://$url';
    _api?.baseUrl = url;
    emit(state.copyWith(serverUrl: url));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverKey, url);
  }
}

/// Shortcut: `context.strings.login`. Rebuilds the widget when the language
/// changes, so it may only be used inside `build`; callbacks read
/// `context.read<SettingsCubit>().state.strings`.
extension SettingsContext on BuildContext {
  AppStrings get strings => watch<SettingsCubit>().state.strings;
}
