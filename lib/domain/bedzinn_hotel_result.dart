class BedzinnHotelResult {
  final String hotelName;
  final String? location;
  final String? stars;
  final String? roomName;
  final String? mealPlan;
  final String? cancellationPolicy;
  final double? price;
  final String? currency;
  final bool? available;

  BedzinnHotelResult({
    required this.hotelName,
    this.location,
    this.stars,
    this.roomName,
    this.mealPlan,
    this.cancellationPolicy,
    this.price,
    this.currency,
    this.available,
  });
}
