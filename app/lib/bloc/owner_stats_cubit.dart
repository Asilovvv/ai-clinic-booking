import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api_client.dart';
import '../data/models.dart';
import '../data/owner_repository.dart';
import 'load_status.dart';

class OwnerStatsState extends Equatable {
  const OwnerStatsState({this.status = LoadStatus.initial, this.stats = const OwnerStats(), this.error});

  final LoadStatus status;
  final OwnerStats stats;
  final String? error;

  @override
  List<Object?> get props => [status, stats, error];
}

/// The numbers of the owner's dashboard.
class OwnerStatsCubit extends Cubit<OwnerStatsState> {
  OwnerStatsCubit(this._repository) : super(const OwnerStatsState());

  final OwnerRepository _repository;

  Future<void> load() async {
    emit(OwnerStatsState(status: LoadStatus.loading, stats: state.stats));
    try {
      final stats = await _repository.stats();
      if (!isClosed) emit(OwnerStatsState(status: LoadStatus.success, stats: stats));
    } on ApiException catch (e) {
      if (!isClosed) emit(OwnerStatsState(status: LoadStatus.failure, stats: state.stats, error: e.message));
    }
  }
}
