import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api_client.dart';
import '../data/clinic_repository.dart';
import '../data/models.dart';

// ---------------------------------------------------------------- events

sealed class AppointmentsEvent extends Equatable {
  const AppointmentsEvent();

  @override
  List<Object?> get props => [];
}

final class AppointmentsRequested extends AppointmentsEvent {
  const AppointmentsRequested();
}

final class AppointmentCancelled extends AppointmentsEvent {
  const AppointmentCancelled(this.appointmentId);

  final int appointmentId;

  @override
  List<Object?> get props => [appointmentId];
}

// ----------------------------------------------------------------- state

enum LoadStatus { initial, loading, success, failure }

class AppointmentsState extends Equatable {
  const AppointmentsState({
    this.status = LoadStatus.initial,
    this.items = const [],
    this.error,
  });

  final LoadStatus status;
  final List<Appointment> items;
  final String? error;

  AppointmentsState copyWith({LoadStatus? status, List<Appointment>? items, String? error}) =>
      AppointmentsState(
        status: status ?? this.status,
        items: items ?? this.items,
        error: error,
      );

  @override
  List<Object?> get props => [status, items, error];
}

// ------------------------------------------------------------------ bloc

class AppointmentsBloc extends Bloc<AppointmentsEvent, AppointmentsState> {
  AppointmentsBloc(this._repository) : super(const AppointmentsState()) {
    on<AppointmentsRequested>(_onRequested);
    on<AppointmentCancelled>(_onCancelled);
  }

  final ClinicRepository _repository;

  Future<void> _onRequested(AppointmentsRequested event, Emitter<AppointmentsState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      emit(state.copyWith(status: LoadStatus.success, items: await _repository.appointments()));
    } on ApiException catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, error: e.message));
    }
  }

  Future<void> _onCancelled(AppointmentCancelled event, Emitter<AppointmentsState> emit) async {
    try {
      await _repository.cancel(event.appointmentId);
      emit(state.copyWith(
        status: LoadStatus.success,
        items: state.items.where((a) => a.id != event.appointmentId).toList(),
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, error: e.message));
    }
  }
}
