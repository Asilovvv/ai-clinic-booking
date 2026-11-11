import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/auth_bloc.dart';
import '../../core/config.dart';
import '../theme.dart';

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

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final bloc = context.read<AuthBloc>();
    if (_isRegister) {
      bloc.add(AuthRegisterRequested(_name.text.trim(), _email.text.trim(), _password.text));
    } else {
      bloc.add(AuthLoginRequested(_email.text.trim(), _password.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated && state.error != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.error!)));
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [brandColor, brandDark],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 44),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Smile AI',
                        style: text.headlineLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ИИ-администратор стоматологии.\nЗапись к врачу одной фразой.',
                        textAlign: TextAlign.center,
                        style: text.bodyLarge?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 28),
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
                                  _isRegister ? 'Регистрация' : 'Вход',
                                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 16),
                                if (_isRegister) ...[
                                  TextFormField(
                                    controller: _name,
                                    textCapitalization: TextCapitalization.words,
                                    decoration: const InputDecoration(
                                      labelText: 'Имя',
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                    validator: (v) =>
                                        (v == null || v.trim().length < 2) ? 'Введите имя' : null,
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
                                  validator: (v) =>
                                      (v == null || !v.contains('@')) ? 'Введите email' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _password,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Пароль',
                                    prefixIcon: Icon(Icons.lock_outline),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.length < 6) ? 'Минимум 6 символов' : null,
                                  onFieldSubmitted: (_) => _submit(),
                                ),
                                const SizedBox(height: 20),
                                BlocBuilder<AuthBloc, AuthState>(
                                  builder: (context, state) {
                                    final loading = state is AuthLoading;
                                    return FilledButton(
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size.fromHeight(52),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      onPressed: loading ? null : _submit,
                                      child: loading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : Text(_isRegister ? 'Создать аккаунт' : 'Войти'),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => setState(() => _isRegister = !_isRegister),
                                  child: Text(_isRegister
                                      ? 'Уже есть аккаунт? Войти'
                                      : 'Нет аккаунта? Зарегистрироваться'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Сервер: ${AppConfig.apiUrl}',
                        style: text.bodySmall?.copyWith(color: Colors.white60),
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
