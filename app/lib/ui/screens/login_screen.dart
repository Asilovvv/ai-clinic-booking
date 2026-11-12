import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/auth_bloc.dart';
import '../../bloc/settings_cubit.dart';
import '../../core/config.dart';
import '../../data/auth_repository.dart';
import '../theme.dart';
import '../widgets/language_button.dart';
import 'splash_screen.dart';

/// Sign-in and registration for both roles, plus one-tap demo accounts.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isRegister = false;
  String _role = 'customer';

  /// The server offers demo accounts.
  bool _demo = false;

  @override
  void initState() {
    super.initState();
    _checkDemo();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _checkDemo() async {
    final demo = await context.read<AuthRepository>().demoAvailable();
    if (mounted) setState(() => _demo = demo);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final bloc = context.read<AuthBloc>();
    if (_isRegister) {
      bloc.add(AuthRegisterRequested(_name.text.trim(), _email.text.trim(), _password.text, role: _role));
    } else {
      bloc.add(AuthLoginRequested(_email.text.trim(), _password.text));
    }
  }

  Future<void> _editServer() async {
    final settings = context.read<SettingsCubit>();
    final url = await showDialog<String>(
      context: context,
      builder: (_) => _ServerDialog(current: settings.state.serverUrl),
    );
    if (url != null) await settings.setServerUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final strings = context.strings;
    final serverUrl = context.select((SettingsCubit c) => c.state.serverUrl);
    return BlocListener<SettingsCubit, SettingsState>(
      // Another server may or may not have demo accounts.
      listenWhen: (prev, curr) => prev.serverUrl != curr.serverUrl,
      listener: (context, state) => _checkDemo(),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: brandGradient),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerRight,
                        child: LanguageButton(color: Colors.white),
                      ),
                      const BrandLogo(size: 72),
                      const SizedBox(height: 12),
                      Text(
                        'Smile AI',
                        style: text.headlineLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        strings.tagline,
                        textAlign: TextAlign.center,
                        style: text.bodyLarge?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _isRegister ? strings.registration : strings.login,
                                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 16),
                                if (_isRegister) ...[
                                  SegmentedButton<String>(
                                    showSelectedIcon: false,
                                    segments: [
                                      ButtonSegment(
                                        value: 'customer',
                                        icon: const Icon(Icons.person_outline),
                                        label: Text(strings.roleCustomer),
                                      ),
                                      ButtonSegment(
                                        value: 'owner',
                                        icon: const Icon(Icons.storefront_outlined),
                                        label: Text(strings.roleOwner),
                                      ),
                                    ],
                                    selected: {_role},
                                    onSelectionChanged: (value) => setState(() => _role = value.first),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _name,
                                    textCapitalization: TextCapitalization.words,
                                    decoration: InputDecoration(
                                      labelText: strings.name,
                                      prefixIcon: const Icon(Icons.badge_outlined),
                                    ),
                                    validator: (v) => (v == null || v.trim().length < 2) ? strings.enterName : null,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: Icon(Icons.mail_outline),
                                  ),
                                  validator: (v) => (v == null || !v.contains('@')) ? strings.enterEmail : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _password,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    labelText: strings.password,
                                    prefixIcon: const Icon(Icons.lock_outline),
                                  ),
                                  validator: (v) => (v == null || v.length < 6) ? strings.minPassword : null,
                                  onFieldSubmitted: (_) => _submit(),
                                ),
                                BlocBuilder<AuthBloc, AuthState>(
                                  builder: (context, state) {
                                    final error = state is AuthUnauthenticated ? state.error : null;
                                    final loading = state is AuthLoading;
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        if (error != null)
                                          Container(
                                            margin: const EdgeInsets.only(top: 12),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: scheme.errorContainer,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(error, style: TextStyle(color: scheme.onErrorContainer)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        const SizedBox(height: 16),
                                        FilledButton(
                                          style: FilledButton.styleFrom(
                                            minimumSize: const Size.fromHeight(52),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          ),
                                          onPressed: loading ? null : _submit,
                                          child: loading
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                )
                                              : Text(_isRegister ? strings.createAccount : strings.signIn),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 4),
                                TextButton(
                                  onPressed: () => setState(() => _isRegister = !_isRegister),
                                  child: Text(_isRegister ? strings.haveAccount : strings.noAccount),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_demo) ...[
                        const SizedBox(height: 16),
                        Text(strings.demoTitle, style: text.bodyMedium?.copyWith(color: Colors.white70)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _DemoButton(
                                key: const ValueKey('demo-customer'),
                                icon: Icons.person_outline,
                                label: strings.demoCustomer,
                                onPressed: () => context.read<AuthBloc>().add(const AuthDemoRequested('customer')),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DemoButton(
                                key: const ValueKey('demo-owner'),
                                icon: Icons.storefront_outlined,
                                label: strings.demoOwner,
                                onPressed: () => context.read<AuthBloc>().add(const AuthDemoRequested('owner')),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _editServer,
                        icon: const Icon(Icons.dns_outlined, size: 16, color: Colors.white60),
                        label: Text(
                          '${strings.server}: ${serverUrl.isEmpty ? AppConfig.defaultApiUrl : serverUrl}',
                          style: text.bodySmall?.copyWith(color: Colors.white60),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoButton extends StatelessWidget {
  const _DemoButton({super.key, required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white54),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

/// Lets the user point the app at another server, for example a laptop in the same Wi-Fi.
class _ServerDialog extends StatefulWidget {
  const _ServerDialog({required this.current});

  final String current;

  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  late final _controller = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return AlertDialog(
      title: Text(strings.serverAddress),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        autocorrect: false,
        decoration: InputDecoration(hintText: AppConfig.defaultApiUrl, helperText: strings.serverHint),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(strings.close)),
        FilledButton(onPressed: () => Navigator.pop(context, _controller.text), child: Text(strings.save)),
      ],
    );
  }
}
