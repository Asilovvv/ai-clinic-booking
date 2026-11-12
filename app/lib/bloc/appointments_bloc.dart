import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api_client.dart';
import '../data/booking_repository.dart';
import '../data/models.dart';
import 'load_status.dart';

// ---------------------------------------------------------------- events

sealed class AppointmentsEvent extends Equatable {
  const AppointmentsEvent();

  @override
  List<Object?> get props => [];
}

/// Load the client's bookings from the server.
final class AppointmentsRequested extends AppointmentsEvent {
  const AppointmentsRequested();
}

final class AppointmentCancelled extends AppointmentsEvent {
  const AppointmentCancelled(this.appointmentId);

  final int appointmentId;

  @override
  List<Object?> get props => [appointmentId];
}

/// The client rated a finished visit.
final class AppointmentReviewed extends AppointmentsEvent {
  const AppointmentReviewed(this.appointmentId, this.rating, {this.comment = ''});

  final int appointmentId;
  final int rating;
  final String comment;

  @override
  List<Object?> get props => [appointmentId, rating, comment];
}

// ----------------------------------------------------------------- state

class AppointmentsState extends Equatable {
  const AppointmentsState({
    this.status = LoadStatus.initial,
    this.items = const [],
    this.error,
  });

  final LoadStatus status;
  final List<Appointment> items;
  final String? error;

  /// Active bookings that are still ahead, the nearest first.
  List<Appointment> get upcoming =>
      items.where((a) => a.upcoming).toList()..sort((a, b) => a.start.compareTo(b.start));

  /// Finished, missed and cancelled bookings, the latest first.
  List<Appointment> get history =>
      items.where((a) => !a.upcoming).toList()..sort((a, b) => b.start.compareTo(a.start));

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
    on<AppointmentCancelled>((event, emit) => _change(emit, () => _repository.cancel(event.appointmentId)));
    on<AppointmentReviewed>((event, emit) =>
        _change(emit, () => _repository.review(event.appointmentId, event.rating, event.comment)));
  }

  final BookingRepository _repository;

  Future<void> _onRequested(AppointmentsRequested event, Emitter<AppointmentsState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      emit(state.copyWith(status: LoadStatus.success, items: await _repository.appointments()));
    } on ApiException catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, error: e.message));
    }
  }

  /// Runs a request that returns the changed booking and puts it into the list.
  Future<void> _change(Emitter<AppointmentsState> emit, Future<Appointment> Function() request) async {
    // Drop the previous error first, so the same failure is reported again.
    if (state.error != null) emit(state.copyWith());
    try {
      final changed = await request();
      emit(state.copyWith(
        status: LoadStatus.success,
        items: [for (final item in state.items) item.id == changed.id ? changed : item],
      ));
    } on ApiException catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, error: e.message));
    }
  }
}
