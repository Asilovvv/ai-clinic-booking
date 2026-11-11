import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api_client.dart';
import '../data/clinic_repository.dart';
import '../data/models.dart';
import 'appointments_bloc.dart' show LoadStatus;

// ---------------------------------------------------------------- events

sealed class DoctorsEvent extends Equatable {
  const DoctorsEvent();

  @override
  List<Object?> get props => [];
}

/// Load categories and specialists from the server.
final class DoctorsRequested extends DoctorsEvent {
  const DoctorsRequested();
}

/// Filter the list by a business category (null = all).
final class DoctorsCategorySelected extends DoctorsEvent {
  const DoctorsCategorySelected(this.category);

  final String? category;

  @override
  List<Object?> get props => [category];
}

// ----------------------------------------------------------------- state

class DoctorsState extends Equatable {
  const DoctorsState({
    this.status = LoadStatus.initial,
    this.categories = const [],
    this.doctors = const [],
    this.selected,
    this.error,
  });

  final LoadStatus status;
  final List<Category> categories;
  final List<Doctor> doctors;

  /// Selected category id, null for all.
  final String? selected;
  final String? error;

  /// Specialists of the selected category.
  List<Doctor> get visible =>
      selected == null ? doctors : doctors.where((d) => d.category == selected).toList();

  DoctorsState copyWith({
    LoadStatus? status,
    List<Category>? categories,
    List<Doctor>? doctors,
    String? Function()? selected,
    String? error,
  }) =>
      DoctorsState(
        status: status ?? this.status,
        categories: categories ?? this.categories,
        doctors: doctors ?? this.doctors,
        selected: selected == null ? this.selected : selected(),
        error: error,
      );

  @override
  List<Object?> get props => [status, categories, doctors, selected, error];
}

// ------------------------------------------------------------------ bloc

class DoctorsBloc extends Bloc<DoctorsEvent, DoctorsState> {
  DoctorsBloc(this._repository) : super(const DoctorsState()) {
    on<DoctorsRequested>(_onRequested);
    on<DoctorsCategorySelected>(
      (event, emit) => emit(state.copyWith(selected: () => event.category)),
    );
  }

  final ClinicRepository _repository;

  Future<void> _onRequested(DoctorsRequested event, Emitter<DoctorsState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final categories = await _repository.categories();
      final doctors = await _repository.doctors();
      emit(state.copyWith(status: LoadStatus.success, categories: categories, doctors: doctors));
    } on ApiException catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, error: e.message));
    }
  }
}
