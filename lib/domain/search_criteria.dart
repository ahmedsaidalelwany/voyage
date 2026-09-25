import 'package:equatable/equatable.dart';
import 'destination.dart';
import 'room_occupancy.dart';

class SearchCriteria extends Equatable {
  final Destination destination;
  final DateTime checkIn;
  final DateTime checkOut;
  final List<RoomOccupancy> rooms;
  final String currency;

  const SearchCriteria({
    required this.destination,
    required this.checkIn,
    required this.checkOut,
    required this.rooms,
    required this.currency,
  });

  int get nights => checkOut.difference(checkIn).inDays;

  @override
  List<Object?> get props => [
        destination,
        checkIn,
        checkOut,
        rooms,
        currency,
      ];
}
