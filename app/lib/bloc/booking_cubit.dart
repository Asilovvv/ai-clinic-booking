import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api_client.dart';
import '../data/models.dart';
import 'load_status.dart';

/// Loads the free slots of one day for the chosen specialist (null = any).
typedef SlotLoader = Future<List<Slot>> Function(DateTime day, int? specialistId);

/// Books, moves or creates a booking for the chosen slot.
typedef SlotSubmit = Future<Appointment> Function(Slot slot);

const _unset = Object();

class BookingState extends Equatable {
  const BookingState({
    required this.days,
    required this.day,
    this.specialistId,
    this.status = LoadStatus.initial,
    this.slots = const [],
    this.selected,
    this.submitting = false,
    this.error,
    this.result,
  });

  /// The days offered in the date strip.
  final List<DateTime> days;
  final DateTime day;

  /// Chosen specialist, null for "any".
  final int? specialistId;
  final LoadStatus status;
  final List<Slot> slots;
  final Slot? selected;
  final bool submitting;
  final String? error;

  /// Set when the booking went through; the sheet then closes.
  final Appointment? result;

  BookingState copyWith({
    DateTime? day,
    Object? specialistId = _unset,
    LoadStatus? status,
    List<Slot>? slots,
    Object? selected = _unset,
    bool? submitting,
    String? error,
    Appointment? result,
  }) =>
      BookingState(
        days: days,
        day: day ?? this.day,
        specialistId: identical(specialistId, _unset) ? this.specialistId : specialistId as int?,
        status: status ?? this.status,
        slots: slots ?? this.slots,
        selected: identical(selected, _unset) ? this.selected : selected as Slot?,
        submitting: submitting ?? this.submitting,
        error: error,
        result: result ?? this.result,
      );

  @override
  List<Object?> get props => [days, day, specialistId, status, slots, selected, submitting, error, result];
}

/// Picking a day, a specialist and a time. One cubit serves a client's
/// booking, moving a booking and the owner's manual entry: what differs is
/// how slots are loaded and what happens on submit.
class BookingCubit extends Cubit<BookingState> {
  BookingCubit({
    required SlotLoader loadSlots,
    required SlotSubmit submit,
    int? specialistId,
    DateTime? today,
    int daysAhead = 14,
  })  : _loadSlots = loadSlots,
        _submit = submit,
        super(_initial(today ?? DateTime.now(), daysAhead, specialistId));

  final SlotLoader _loadSlots;
  final SlotSubmit _submit;

  /// Grows with every request, so a slow answer for an old day is dropped.
  int _request = 0;

  static BookingState _initial(DateTime today, int daysAhead, int? specialistId) {
    final first = DateTime(today.year, today.month, today.day);
    final days = [for (var i = 0; i < daysAhead; i++) DateTime(first.year, first.month, first.day + i)];
    return BookingState(days: days, day: first, specialistId: specialistId);
  }

  /// First load: opens the nearest day that still has free time.
  Future<void> start() async {
    for (final day in state.days.take(7)) {
      await _load(day);
      if (isClosed || state.slots.isNotEmpty || state.status == LoadStatus.failure) return;
    }
    if (!isClosed) await _load(state.days.first);
  }

  Future<void> selectDay(DateTime day) => _load(day);

  Future<void> selectSpecialist(int? specialistId) {
    emit(state.copyWith(specialistId: specialistId));
    return _load(state.day);
  }

  void selectSlot(Slot slot) => emit(state.copyWith(selected: slot));

  Future<void> _load(DateTime day) async {
    final request = ++_request;
    emit(state.copyWith(day: day, status: LoadStatus.loading, slots: const [], selected: null));
    try {
      final slots = await _loadSlots(day, state.specialistId);
      if (isClosed || request != _request) return;
      emit(state.copyWith(status: LoadStatus.success, slots: slots));
    } on ApiException catch (e) {
      if (isClosed || request != _request) return;
      emit(state.copyWith(status: LoadStatus.failure, error: e.message));
    }
  }

  Future<void> submit() async {
    final slot = state.selected;
    if (slot == null || state.submitting) return;
    emit(state.copyWith(submitting: true));
    try {
      final appointment = await _submit(slot);
      if (!isClosed) emit(state.copyWith(submitting: false, result: appointment));
    } on ApiException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(submitting: false, error: e.message));
      // The slot may have just been taken by someone else: show what is free now.
      await _load(state.day);
    }
  }
}
