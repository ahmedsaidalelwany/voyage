import 'package:equatable/equatable.dart';
import 'destination.dart';
import 'room_occupancy.dart';

class SearchCriteria extends Equatable {
  final Destination destination;
  final DateTime checkIn;
  final DateTime checkOut;
  final List<RoomOccupancy> rooms;
  final String currency;
  final String? hotelName;
  final int? minimumStars;
  final double? maximumPrice;
  final String? mealPlan;
  final String? cancellationPreference;
  final bool availableOnly;
  final List<String> supplierIds;

  const SearchCriteria({
    required this.destination,
    required this.checkIn,
    required this.checkOut,
    required this.rooms,
    required this.currency,
    this.hotelName,
    this.minimumStars,
    this.maximumPrice,
    this.mealPlan,
    this.cancellationPreference,
    this.availableOnly = false,
    this.supplierIds = const [],
  });

  int get nights => checkOut.difference(checkIn).inDays;

  bool get hasAdvancedFilters =>
      hotelName != null ||
      minimumStars != null ||
      maximumPrice != null ||
      mealPlan != null ||
      cancellationPreference != null ||
      availableOnly ||
      supplierIds.isNotEmpty;

  @override
  List<Object?> get props => [
        destination,
        checkIn,
        checkOut,
        rooms,
        currency,
        hotelName,
        minimumStars,
        maximumPrice,
        mealPlan,
        cancellationPreference,
        availableOnly,
        supplierIds,
      ];
}
