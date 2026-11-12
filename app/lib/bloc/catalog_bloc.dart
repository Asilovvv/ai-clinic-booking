import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api_client.dart';
import '../data/catalog_repository.dart';
import '../data/models.dart';
import 'load_status.dart';

// ---------------------------------------------------------------- events

sealed class CatalogEvent extends Equatable {
  const CatalogEvent();

  @override
  List<Object?> get props => [];
}

/// Load niches and businesses from the server.
final class CatalogRequested extends CatalogEvent {
  const CatalogRequested();
}

/// Show one niche (null = all).
final class CatalogCategorySelected extends CatalogEvent {
  const CatalogCategorySelected(this.category);

  final String? category;

  @override
  List<Object?> get props => [category];
}

/// The text in the search field changed.
final class CatalogSearchChanged extends CatalogEvent {
  const CatalogSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

// ----------------------------------------------------------------- state

const _unset = Object();

class CatalogState extends Equatable {
  const CatalogState({
    this.status = LoadStatus.initial,
    this.categories = const [],
    this.businesses = const [],
    this.selected,
    this.query = '',
    this.error,
  });

  final LoadStatus status;
  final List<Category> categories;
  final List<Business> businesses;

  /// Selected niche id, null for all.
  final String? selected;
  final String query;
  final String? error;

  /// Businesses of the selected niche that match every word of the search.
  List<Business> get visible {
    final words = query.toLowerCase().replaceAll('ё', 'е').split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return businesses
        .where((b) => selected == null || b.category == selected)
        .where((b) => words.every(b.searchText.contains))
        .toList();
  }

  CatalogState copyWith({
    LoadStatus? status,
    List<Category>? categories,
    List<Business>? businesses,
    Object? selected = _unset,
    String? query,
    String? error,
  }) =>
      CatalogState(
        status: status ?? this.status,
        categories: categories ?? this.categories,
        businesses: businesses ?? this.businesses,
        selected: identical(selected, _unset) ? this.selected : selected as String?,
        query: query ?? this.query,
        error: error,
      );

  @override
  List<Object?> get props => [status, categories, businesses, selected, query, error];
}

// ------------------------------------------------------------------ bloc

class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  CatalogBloc(this._repository) : super(const CatalogState()) {
    on<CatalogRequested>(_onRequested);
    on<CatalogCategorySelected>((event, emit) => emit(state.copyWith(selected: event.category)));
    on<CatalogSearchChanged>((event, emit) => emit(state.copyWith(query: event.query)));
  }

  final CatalogRepository _repository;

  Future<void> _onRequested(CatalogRequested event, Emitter<CatalogState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final categories = await _repository.categories();
      final businesses = await _repository.businesses();
      emit(state.copyWith(status: LoadStatus.success, categories: categories, businesses: businesses));
    } on ApiException catch (e) {
      emit(state.copyWith(status: LoadStatus.failure, error: e.message));
    }
  }
}
