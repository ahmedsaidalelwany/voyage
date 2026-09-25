import 'package:equatable/equatable.dart';

class RoomOccupancy extends Equatable {
  final int adults;
  final List<int> childrenAges;

  const RoomOccupancy({
    required this.adults,
    this.childrenAges = const [],
  });

  @override
  List<Object?> get props => [adults, childrenAges];
}
