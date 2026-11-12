import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api_client.dart';
import '../data/auth_repository.dart';
import '../data/models.dart';

// ---------------------------------------------------------------- events

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// The app started: try to restore the saved session.
final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

final class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested(this.email, this.password);

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

final class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested(this.name, this.email, this.password, {this.role = 'customer'});

  final String name;
  final String email;
  final String password;

  /// "customer" or "owner".
  final String role;

  @override
  List<Object?> get props => [name, email, password, role];
}

/// One-tap sign-in to a demo account.
final class AuthDemoRequested extends AuthEvent {
  const AuthDemoRequested(this.role);

  final String role;

  @override
  List<Object?> get props => [role];
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

// ---------------------------------------------------------------- states

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// The saved session has not been checked yet.
final class AuthInitial extends AuthState {
  const AuthInitial();
}

/// A sign-in request is in flight.
final class AuthLoading extends AuthState {
  const AuthLoading();
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  final User user;

  @override
  List<Object?> get props => [user];
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.error});

  final String? error;

  @override
  List<Object?> get props => [error];
}

// ------------------------------------------------------------------ bloc

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repository) : super(const AuthInitial()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>((event, emit) => _signIn(emit, () => _repository.login(event.email, event.password)));
    on<AuthRegisterRequested>((event, emit) => _signIn(
        emit, () => _repository.register(event.name, event.email, event.password, role: event.role)));
    on<AuthDemoRequested>((event, emit) => _signIn(emit, () => _repository.demoLogin(event.role)));
    on<AuthLogoutRequested>(_onLogout);
  }

  final AuthRepository _repository;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    try {
      final user = await _repository.restoreSession();
      emit(user == null ? const AuthUnauthenticated() : AuthAuthenticated(user));
    } on ApiException catch (e) {
      emit(AuthUnauthenticated(error: e.message));
    }
  }

  Future<void> _signIn(Emitter<AuthState> emit, Future<User> Function() request) async {
    emit(const AuthLoading());
    try {
      emit(AuthAuthenticated(await request()));
    } on ApiException catch (e) {
      emit(AuthUnauthenticated(error: e.message));
    }
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _repository.logout();
    emit(const AuthUnauthenticated());
  }
}
