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

final class DoctorsRequested extends DoctorsEvent {
  const DoctorsRequested();
}

// ----------------------------------------------------------------- state

class DoctorsState extends Equatable {
  const DoctorsState({this.status = LoadStatus.initial, this.doctors = const [], this.error});

  final LoadStatus status;
  final List<Doctor> doctors;
  final String? error;

  @override
  List<Object?> get props => [status, doctors, error];
}

// ------------------------------------------------------------------ bloc

class DoctorsBloc extends Bloc<DoctorsEvent, DoctorsState> {
  DoctorsBloc(this._repository) : super(const DoctorsState()) {
    on<DoctorsRequested>(_onRequested);
  }

  final ClinicRepository _repository;

  Future<void> _onRequested(DoctorsRequested event, Emitter<DoctorsState> emit) async {
    emit(DoctorsState(status: LoadStatus.loading, doctors: state.doctors));
    try {
      emit(DoctorsState(status: LoadStatus.success, doctors: await _repository.doctors()));
    } on ApiException catch (e) {
      emit(DoctorsState(status: LoadStatus.failure, doctors: state.doctors, error: e.message));
    }
  }
}
