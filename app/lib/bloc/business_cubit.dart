import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api_client.dart';
import '../data/catalog_repository.dart';
import '../data/models.dart';
import 'load_status.dart';

class BusinessState extends Equatable {
  const BusinessState({this.status = LoadStatus.initial, this.business, this.error});

  final LoadStatus status;

  /// The catalog's summary at first, the full card once loaded.
  final Business? business;
  final String? error;

  @override
  List<Object?> get props => [status, business, error];
}

/// The page of one business: services, specialists and reviews.
class BusinessCubit extends Cubit<BusinessState> {
  BusinessCubit(this._repository, this.businessId, {Business? preview}) : super(BusinessState(business: preview));

  final CatalogRepository _repository;
  final int businessId;

  Future<void> load() async {
    emit(BusinessState(status: LoadStatus.loading, business: state.business));
    try {
      final business = await _repository.business(businessId);
      if (!isClosed) emit(BusinessState(status: LoadStatus.success, business: business));
    } on ApiException catch (e) {
      if (!isClosed) emit(BusinessState(status: LoadStatus.failure, business: state.business, error: e.message));
    }
  }
}
