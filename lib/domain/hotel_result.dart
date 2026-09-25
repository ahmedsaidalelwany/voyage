class HotelResult {
  final String hotelName;
  final String? location;
  final String? roomName;
  final String? mealPlan;
  final String? cancellationPolicy;
  final double? price;
  final String? currency;
  final String supplier;

  HotelResult({
    required this.hotelName,
    this.location,
    this.roomName,
    this.mealPlan,
    this.cancellationPolicy,
    this.price,
    this.currency,
    required this.supplier,
  });
}
