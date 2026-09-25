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
        criteria.rooms.any((room) =>
            room.adults < 1 ||
            room.childrenAges.any((age) => age < 0 || age > 17))) {
      emit(SearchFailure('Each room must contain at least one adult and valid child ages.'));
      return;
    }
    if (connectedAdapters.isEmpty) {
      emit(SearchFailure('No connected suppliers available for search.'));
      return;
    }

    final progressList = connectedAdapters.map((adapter) => SupplierSearchProgress(
      supplierId: adapter.supplier.id,
      supplierName: adapter.supplier.name,
      status: SupplierSearchStatus.searching,
    )).toList();

    emit(SearchInProgress(List.from(progressList)));

    final futures = connectedAdapters.map((adapter) async {
      try {
        developer.log(
          '[Search] Starting ' + adapter.supplier.name +
          ': destination=' + criteria.destination.name +
          ', currency=' + criteria.currency +
          ', checkIn=' + criteria.checkIn.toIso8601String() +
          ', checkOut=' + criteria.checkOut.toIso8601String() +
          ', rooms=' + criteria.rooms.length.toString(),
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

        developer.log('[Search] ' + adapter.supplier.name + ' completed: ' + normalized.length.toString() + ' normalized hotels');
        if (!isClosed) emit(SearchInProgress(List.from(progressList)));
        return normalized;
      } on TimeoutException {
        final message = adapter.supplier.name + ' search timed out after 30 seconds.';
        developer.log('[Search] ' + message);
        final index = progressList.indexWhere((item) => item.supplierId == adapter.supplier.id);
        if (index != -1) {
          progressList[index] = progressList[index].copyWith(
            status: SupplierSearchStatus.failure,
            errorMessage: message,
          );
        }
        if (!isClosed) emit(SearchInProgress(List.from(progressList)));
        return <Hotel>[];
      } catch (error, stackTrace) {
        final message = error.runtimeType.toString() + ': ' + error.toString();
        developer.log('[Search] ' + adapter.supplier.name + ' failed: ' + message, stackTrace: stackTrace);
        final index = progressList.indexWhere((item) => item.supplierId == adapter.supplier.id);
        if (index != -1) {
          progressList[index] = progressList[index].copyWith(
            status: SupplierSearchStatus.failure,
            errorMessage: message,
          );
        }
        if (!isClosed) emit(SearchInProgress(List.from(progressList)));
        return <Hotel>[];
      }
    });

    try {
      final resultsPerSupplier = await Future.wait(futures);
      final allHotels = resultsPerSupplier.expand((items) => items).toList();
      final merged = _repository.matchHotels(allHotels);

      final successful = progressList.where((p) => p.status == SupplierSearchStatus.success).toList();
      final failed = progressList.where((p) => p.status == SupplierSearchStatus.failure).toList();

      if (merged.isEmpty && successful.isEmpty) {
        final details = failed.map((p) => p.supplierName + ': ' + (p.errorMessage ?? 'unknown error')).join('\n');
        emit(SearchFailure(details.isEmpty ? 'All connected suppliers failed to return results.' : 'All connected supplier searches failed:\n' + details));
        return;
      }

      emit(SearchSuccess(merged, merged, const ResultFilters(), List.from(progressList), criteria));
    } catch (error, stackTrace) {
      developer.log('[Search] orchestration failed: ' + error.toString(), stackTrace: stackTrace);
      emit(SearchFailure(error.toString()));
    }
  }

  void applyFilters(ResultFilters newFilters) {
    if (state is! SearchSuccess) return;
    final currentState = state as SearchSuccess;

    final filteredHotels = currentState.allHotels.where((hotel) {
      if (newFilters.minRating != null && (hotel.stars ?? 0) < newFilters.minRating!) return false;
      final matchingOffers = hotel.offers.where((offer) {
        if (newFilters.supplierId != null && newFilters.supplierId != 'All' && offer.supplierId != newFilters.supplierId) return false;
        if (newFilters.availableOnly && offer.isAvailable == false) return false;
        if (newFilters.mealPlan != null &&
            newFilters.mealPlan!.isNotEmpty &&
            !(offer.mealPlan ?? '').toLowerCase().contains(newFilters.mealPlan!.toLowerCase())) {
          return false;
        }
        if (newFilters.cancellationPolicy != null &&
            newFilters.cancellationPolicy!.isNotEmpty &&
            !(offer.cancellationPolicy ?? '').toLowerCase().contains(newFilters.cancellationPolicy!.toLowerCase())) {
          return false;
        }
        if (newFilters.maxPrice != null && offer.price != null) {
          if (offer.currency != currentState.criteria.currency) return false;
          if (offer.price! > newFilters.maxPrice!) return false;
        }
        return true;
      }).toList();
      return matchingOffers.isNotEmpty;
    }).map((hotel) {
      final matchingOffers = hotel.offers.where((offer) {
        if (newFilters.supplierId != null && newFilters.supplierId != 'All' && offer.supplierId != newFilters.supplierId) return false;
        if (newFilters.availableOnly && offer.isAvailable == false) return false;
        if (newFilters.maxPrice != null && offer.price != null) {
          if (offer.currency != currentState.criteria.currency) return false;
          if (offer.price! > newFilters.maxPrice!) return false;
        }
        return true;
      }).toList();
      return hotel.copyWithOffers(matchingOffers);
    }).toList();

    emit(SearchSuccess(currentState.allHotels, filteredHotels, newFilters, currentState.progress, currentState.criteria));
  }
}
