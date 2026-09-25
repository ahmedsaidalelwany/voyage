import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/search_criteria.dart';
import '../domain/hotel.dart';
import '../domain/supplier_adapter.dart';
import '../data/search_repository.dart';
import '../domain/result_filters.dart';
import '../domain/supplier_search_progress.dart';
import 'dart:developer' as developer;

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
    if (connectedAdapters.isEmpty) {
      emit(SearchFailure('No connected suppliers available for search.'));
      return;
    }

    List<SupplierSearchProgress> progressList = connectedAdapters.map((a) => SupplierSearchProgress(
      supplierId: a.supplier.id,
      supplierName: a.supplier.name,
      status: SupplierSearchStatus.searching,
    )).toList();
    
    emit(SearchInProgress(List.from(progressList)));

    try {
      final futures = connectedAdapters.map((adapter) async {
        try {
          developer.log('''
[SUPPLIER DEBUG]
supplier = \${adapter.supplier.name}
destination = \${criteria.destination.name}
currency = \${criteria.currency}
checkIn = \${criteria.checkIn}
checkOut = \${criteria.checkOut}
occupancy = \${criteria.rooms.map((r) => '\${r.adults}A, \${r.childrenAges.length}C').join(' | ')}
''');
          final rawResult = await adapter.search(criteria).timeout(const Duration(seconds: 15));
          final normalized = _repository.normalize(rawResult);
          
          final idx = progressList.indexWhere((p) => p.supplierId == adapter.supplier.id);
          if (idx != -1) {
            progressList[idx] = progressList[idx].copyWith(
              status: SupplierSearchStatus.success,
              resultsCount: normalized.length,
            );
            // Don't emit here because we are in a tight loop of futures, but we could if we wanted UI updates per supplier.
            if (!isClosed && state is SearchInProgress) {
               emit(SearchInProgress(List.from(progressList)));
            }
          }
          return normalized;
        } catch (e) {
          developer.log('[SearchCubit] Supplier ${adapter.supplier.name} failed: $e');
          final idx = progressList.indexWhere((p) => p.supplierId == adapter.supplier.id);
          if (idx != -1) {
            progressList[idx] = progressList[idx].copyWith(
              status: SupplierSearchStatus.failure,
              errorMessage: e.toString(),
            );
            if (!isClosed && state is SearchInProgress) {
               emit(SearchInProgress(List.from(progressList)));
            }
          }
          return <Hotel>[];
        }
      });

      final List<List<Hotel>> resultsPerSupplier = await Future.wait(futures);
      final List<Hotel> allHotels = resultsPerSupplier.expand((h) => h).toList();
      final merged = _repository.matchHotels(allHotels);

      emit(SearchSuccess(merged, merged, const ResultFilters(), progressList, criteria));
    } catch (e) {
      emit(SearchFailure(e.toString()));
    }
  }

  void applyFilters(ResultFilters newFilters) {
    if (state is SearchSuccess) {
      final currentState = state as SearchSuccess;
      final allHotels = currentState.allHotels;
      
      final filteredHotels = allHotels.where((hotel) {
        if (newFilters.minRating != null && (hotel.stars ?? 0) < newFilters.minRating!) return false;
        
        final matchingOffers = hotel.offers.where((offer) {
          if (newFilters.supplierId != null && newFilters.supplierId != 'All' && offer.supplierId != newFilters.supplierId) return false;
          if (newFilters.availableOnly && (offer.isAvailable == false)) return false;
          if (newFilters.maxPrice != null && offer.price != null) {
            if (offer.currency != currentState.criteria.currency) {
              // We cannot safely compare mismatched currencies without conversion.
              // So if the currency doesn't match the requested currency, we must drop it 
              // or handle it safely (for now, drop from results if we are filtering by price).
              return false;
            }
            if (offer.price! > newFilters.maxPrice!) return false;
          }
          return true;
        }).toList();

        return matchingOffers.isNotEmpty;
      }).map((hotel) {
        final matchingOffers = hotel.offers.where((offer) {
          if (newFilters.supplierId != null && newFilters.supplierId != 'All' && offer.supplierId != newFilters.supplierId) return false;
          if (newFilters.availableOnly && (offer.isAvailable == false)) return false;
          if (newFilters.maxPrice != null && offer.price != null) {
            if (offer.currency != currentState.criteria.currency) return false;
            if (offer.price! > newFilters.maxPrice!) return false;
          }
          return true;
        }).toList();
        return hotel.copyWithOffers(matchingOffers);
      }).toList();

      emit(SearchSuccess(allHotels, filteredHotels, newFilters, currentState.progress, currentState.criteria));
    }
  }
}
