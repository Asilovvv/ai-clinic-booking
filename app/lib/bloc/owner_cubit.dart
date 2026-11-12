import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api_client.dart';
import '../data/catalog_repository.dart';
import '../data/models.dart';
import '../data/owner_repository.dart';
import 'load_status.dart';

class OwnerState extends Equatable {
  const OwnerState({
    this.status = LoadStatus.initial,
    this.business,
    this.categories = const [],
    this.saving = false,
    this.error,
  });

  final LoadStatus status;

  /// Null after a successful load means the owner has not created a business yet.
  final Business? business;

  /// The niches to choose from when creating the business.
  final List<Category> categories;

  /// A change is being sent to the server.
  final bool saving;
  final String? error;

  OwnerState copyWith({LoadStatus? status, Business? business, List<Category>? categories, bool? saving, String? error}) =>
      OwnerState(
        status: status ?? this.status,
        business: business ?? this.business,
        categories: categories ?? this.categories,
        saving: saving ?? this.saving,
        error: error,
      );

  @override
  List<Object?> get props => [status, business, categories, saving, error];
}

/// The owner's business with its services and staff. Every change returns
/// true on success; on failure the server's message lands in `state.error`.
class OwnerCubit extends Cubit<OwnerState> {
  OwnerCubit(this._owner, this._catalog) : super(const OwnerState());

  final OwnerRepository _owner;
  final CatalogRepository _catalog;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final business = await _owner.business();
      final categories = await _catalog.categories();
      if (!isClosed) emit(OwnerState(status: LoadStatus.success, business: business, categories: categories));
    } on ApiException catch (e) {
      if (!isClosed) emit(state.copyWith(status: LoadStatus.failure, error: e.message));
    }
  }

  Future<bool> createBusiness({
    required String category,
    required String name,
    String description = '',
    String address = '',
    String phone = '',
    int openHour = 9,
    int closeHour = 18,
    List<int> workingDays = const [0, 1, 2, 3, 4, 5],
    bool useTemplate = true,
  }) =>
      _change(() => _owner.createBusiness(
            category: category,
            name: name,
            description: description,
            address: address,
            phone: phone,
            openHour: openHour,
            closeHour: closeHour,
            workingDays: workingDays,
            useTemplate: useTemplate,
          ));

  Future<bool> updateBusiness({
    String? name,
    String? description,
    String? address,
    String? phone,
    int? openHour,
    int? closeHour,
    List<int>? workingDays,
    bool? isActive,
  }) =>
      _change(() => _owner.updateBusiness(
            name: name,
            description: description,
            address: address,
            phone: phone,
            openHour: openHour,
            closeHour: closeHour,
            workingDays: workingDays,
            isActive: isActive,
          ));

  Future<bool> saveService({
    int? id,
    required String name,
    required int durationMin,
    required int price,
    String description = '',
    List<int>? specialistIds,
  }) =>
      _change(() => _owner.saveService(
            id: id,
            name: name,
            durationMin: durationMin,
            price: price,
            description: description,
            specialistIds: specialistIds,
          ));

  Future<bool> deleteService(int id) => _change(() => _owner.deleteService(id));

  Future<bool> saveSpecialist({int? id, required String name, String title = ''}) =>
      _change(() => _owner.saveSpecialist(id: id, name: name, title: title));

  Future<bool> deleteSpecialist(int id) => _change(() => _owner.deleteSpecialist(id));

  /// Runs a request that returns the updated business.
  Future<bool> _change(Future<Business> Function() request) async {
    emit(state.copyWith(saving: true));
    try {
      final business = await request();
      if (!isClosed) emit(state.copyWith(status: LoadStatus.success, business: business, saving: false));
      return true;
    } on ApiException catch (e) {
      if (!isClosed) emit(state.copyWith(saving: false, error: e.message));
      return false;
    }
  }
}
