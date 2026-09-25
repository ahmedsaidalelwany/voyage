import 'package:equatable/equatable.dart';

class HotelOffer extends Equatable {
  final String supplierId;
  final String? supplierHotelId;
  final String? roomType;
  final String? roomDescription;
  final int? numberOfRooms;
  final int? adults;
  final int? children;
  final String? mealPlan;
  final String? cancellationPolicy;
  final bool? isAvailable;
  final double? price;
  final String? currency;
  final double? taxes;
  final double? totalPrice;
  final DateTime? bookingDeadline;

  const HotelOffer({
    required this.supplierId,
    this.supplierHotelId,
    this.roomType,
    this.roomDescription,
    this.numberOfRooms,
    this.adults,
    this.children,
    this.mealPlan,
    this.cancellationPolicy,
    this.isAvailable,
    this.price,
    this.currency,
    this.taxes,
    this.totalPrice,
    this.bookingDeadline,
  });

  @override
  List<Object?> get props => [
        supplierId,
        supplierHotelId,
        roomType,
        roomDescription,
        numberOfRooms,
        adults,
        children,
        mealPlan,
        cancellationPolicy,
        isAvailable,
        price,
        currency,
        taxes,
        totalPrice,
        bookingDeadline,
      ];
}
