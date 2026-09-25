import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/search_repository.dart';
import '../domain/hotel.dart';
import '../domain/result_filters.dart';
import '../domain/search_criteria.dart';
import '../domain/supplier_adapter.dart';
import '../domain/supplier_search_progress.dart';

abstract class SearchState {}
class SearchInitial extends SearchState {}
class SearchInProgress extends SearchState {
  final List<SupplierSearchProgress> progress;
  SearchInProgress(this.progress);
}
class SearchSuccess extends SearchState {
  final List<Hotel> allHotels;
  final List<Hotel> filteredHotels;
  final ResultFilters filters;
  final List<SupplierSearchProgress> progress;
  final SearchCriteria criteria;
  SearchSuccess(this.allHotels, this.filteredHotels, this.filters, this.progress, this.criteria);
}
class SearchFailure extends SearchState {
  final String error;
  SearchFailure(this.error);
}

class SearchCubit extends Cubit<SearchState> {
  final SearchRepository _repository;
  SearchCubit(this._repository) : super(SearchInitial());

  Future<void> search(SearchCriteria criteria, List<SupplierAdapter> connectedAdapters) async {
    if (criteria.checkOut.isBefore(criteria.checkIn) || criteria.nights < 1) {
      emit(SearchFailure('Check-out must be after check-in.'));
      return;
    }
    if (criteria.rooms.isEmpty ||
        criteria.rooms.any((room) => room.adults < 1 || room.childrenAges.any((age) => age < 0 || age > 17))) {
      emit(SearchFailure('Each room must contain at least one adult and valid child ages.'));
      return;
    }

    final selectedAdapters = connectedAdapters.where((adapter) {
      return criteria.supplierIds.isEmpty || criteria.supplierIds.contains(adapter.supplier.id);
    }).toList();

    if (selectedAdapters.isEmpty) {
      emit(SearchFailure('No selected connected suppliers are available.'));
      return;
    }

    final progressList = selectedAdapters.map((adapter) => SupplierSearchProgress(
      supplierId: adapter.supplier.id,
      supplierName: adapter.supplier.name,
      status: SupplierSearchStatus.searching,
    )).toList();

    emit(SearchInProgress(List.from(progressList)));

    final futures = selectedAdapters.map((adapter) async {
      try {
        developer.log(
          '[Search] ' + adapter.supplier.name +
          ': destination=' + criteria.destination.name +
          ', hotel=' + (criteria.hotelName ?? '') +
          ', currency=' + criteria.currency +
          ', checkIn=' + criteria.checkIn.toIso8601String() +
          ', checkOut=' + criteria.checkOut.toIso8601String() +
          ', rooms=' + criteria.rooms.length.toString() +
          ', stars=' + (criteria.minimumStars?.toString() ?? 'any') +
          ', maxPrice=' + (criteria.maximumPrice?.toString() ?? 'any') +
          ', meal=' + (criteria.mealPlan ?? 'any') +
          ', cancellation=' + (criteria.cancellationPreference ?? 'any'),
        );

        final rawResult = await adapter.search(criteria).timeout(const Duration(seconds: 90));
        final normalized = _repository.normalize(rawResult);

        final index = progressList.indexWhere((item) => item.supplierId == adapter.supplier.id);
        if (index != -1) {
          progressList[index] = progressList[index].copyWith(
            status: SupplierSearchStatus.success,
            resultsCount: normalized.length,
            errorMessage: null,
          );
        }
        if (!isClosed) emit(SearchInProgress(List.from(progressList)));
        return normalized;
      } on TimeoutException {
        final message = adapter.supplier.name + ' search timed out after 90 seconds.';
        _markFailure(progressList, adapter.supplier.id, message);
        if (!isClosed) emit(SearchInProgress(List.from(progressList)));
        return <Hotel>[];
      } catch (error, stackTrace) {
        final message = error.runtimeType.toString() + ': ' + error.toString();
        developer.log('[Search] ' + adapter.supplier.name + ' failed: ' + message, stackTrace: stackTrace);
        _markFailure(progressList, adapter.supplier.id, message);
        if (!isClosed) emit(SearchInProgress(List.from(progressList)));
        return <Hotel>[];
      }
    });

    try {
      final resultsPerSupplier = await Future.wait(futures);
      final allHotels = resultsPerSupplier.expand((items) => items).toList();
      final merged = _repository.matchHotels(allHotels);
      final filters = _filtersFromCriteria(criteria);
      final filtered = _repository.applyFilters(merged, criteria);

      final successful = progressList.where((p) => p.status == SupplierSearchStatus.success).toList();
      final failed = progressList.where((p) => p.status == SupplierSearchStatus.failure).toList();

      if (merged.isEmpty && successful.isEmpty) {
        final details = failed.map((p) => p.supplierName + ': ' + (p.errorMessage ?? 'unknown error')).join('\n');
        emit(SearchFailure(details.isEmpty
            ? 'All connected suppliers failed to return results.'
            : 'All connected supplier searches failed:\n' + details));
        return;
      }

      emit(SearchSuccess(merged, filtered, filters, List.from(progressList), criteria));
    } catch (error, stackTrace) {
      developer.log('[Search] orchestration failed: ' + error.toString(), stackTrace: stackTrace);
      emit(SearchFailure(error.toString()));
    }
  }

  ResultFilters _filtersFromCriteria(SearchCriteria criteria) {
    return ResultFilters(
      maxPrice: criteria.maximumPrice,
      minRating: criteria.minimumStars,
      mealPlan: criteria.mealPlan,
      cancellationPolicy: criteria.cancellationPreference,
      availableOnly: criteria.availableOnly,
    );
  }

  void _markFailure(List<SupplierSearchProgress> progress, String supplierId, String message) {
    final index = progress.indexWhere((item) => item.supplierId == supplierId);
    if (index != -1) {
      progress[index] = progress[index].copyWith(
        status: SupplierSearchStatus.failure,
        errorMessage: message,
      );
    }
  }

  void applyFilters(ResultFilters newFilters) {
    if (state is! SearchSuccess) return;
    final currentState = state as SearchSuccess;
    final filteredHotels = _repository.filterHotels(
      currentState.allHotels,
      newFilters,
      currentState.criteria,
    );
    emit(SearchSuccess(
      currentState.allHotels,
      filteredHotels,
      newFilters,
      currentState.progress,
      currentState.criteria,
    ));
  }
}
