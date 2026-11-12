import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api_client.dart';
import '../data/models.dart';
import '../data/owner_repository.dart';
import 'load_status.dart';

class OwnerAgendaState extends Equatable {
  const OwnerAgendaState({
    required this.days,
    required this.today,
    required this.day,
    this.status = LoadStatus.initial,
    this.items = const [],
    this.error,
    this.revision = 0,
  });

  /// The days offered in the date strip: a few back, two weeks ahead.
  final List<DateTime> days;
  final DateTime today;

  /// The day on screen.
  final DateTime day;
  final LoadStatus status;

  /// The bookings of [day], earliest first.
  final List<Appointment> items;
  final String? error;

  /// Grows every time a booking was added or its status changed,
  /// so the dashboard knows it must reload.
  final int revision;

  OwnerAgendaState copyWith({
    DateTime? day,
    LoadStatus? status,
    List<Appointment>? items,
    String? error,
    int? revision,
  }) =>
      OwnerAgendaState(
        days: days,
        today: today,
        day: day ?? this.day,
        status: status ?? this.status,
        items: items ?? this.items,
        error: error,
        revision: revision ?? this.revision,
      );

  @override
  List<Object?> get props => [days, day, status, items, error, revision];
}

/// The owner's schedule, one day at a time.
class OwnerAgendaCubit extends Cubit<OwnerAgendaState> {
  OwnerAgendaCubit(this._repository, {DateTime? today, int daysBack = 3, int daysAhead = 14})
      : super(_initial(today ?? DateTime.now(), daysBack, daysAhead));

  final OwnerRepository _repository;

  /// Grows with every request, so a slow answer for an old day is dropped.
  int _request = 0;

  static OwnerAgendaState _initial(DateTime today, int daysBack, int daysAhead) {
    final first = DateTime(today.year, today.month, today.day);
    return OwnerAgendaState(
      days: [for (var i = -daysBack; i < daysAhead; i++) DateTime(first.year, first.month, first.day + i)],
      today: first,
      day: first,
    );
  }

  /// Loads the selected day again, or switches to [day].
  Future<void> load([DateTime? day]) async {
    final request = ++_request;
    final target = day == null ? state.day : DateTime(day.year, day.month, day.day);
    emit(state.copyWith(day: target, status: LoadStatus.loading, items: target == state.day ? null : const []));
    try {
      final items = await _repository.agenda(target);
      if (isClosed || request != _request) return;
      emit(state.copyWith(status: LoadStatus.success, items: items));
    } on ApiException catch (e) {
      if (isClosed || request != _request) return;
      emit(state.copyWith(status: LoadStatus.failure, error: e.message));
    }
  }

  /// Marks a visit as completed, missed, cancelled or active again.
  Future<bool> setStatus(int appointmentId, String status) async {
    if (state.error != null) emit(state.copyWith());
    try {
      final changed = await _repository.setStatus(appointmentId, status);
      if (isClosed) return true;
      emit(state.copyWith(
        items: [for (final item in state.items) item.id == changed.id ? changed : item],
        revision: state.revision + 1,
      ));
      return true;
    } on ApiException catch (e) {
      if (!isClosed) emit(state.copyWith(error: e.message));
      return false;
    }
  }

  /// The owner added a booking by hand: show its day.
  Future<void> added(Appointment appointment) {
    emit(state.copyWith(revision: state.revision + 1));
    return load(appointment.start);
  }
}
