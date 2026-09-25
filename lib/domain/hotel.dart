import 'package:equatable/equatable.dart';
import 'hotel_offer.dart';

class Hotel extends Equatable {
  final String id;
  final String name;
  final String? location;
  final String? city;
  final String? country;
  final int? stars;
  final double? rating;
  final List<String> images;
  final List<HotelOffer> offers;

  const Hotel({
    required this.id,
    required this.name,
    this.location,
    this.city,
    this.country,
    this.stars,
    this.rating,
    this.images = const [],
    this.offers = const [],
  });

  Hotel copyWithOffers(List<HotelOffer> newOffers) {
    return Hotel(
      id: id,
      name: name,
      location: location,
      city: city,
      country: country,
      stars: stars,
      rating: rating,
      images: images,
      offers: newOffers,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        location,
        city,
        country,
        stars,
        rating,
        images,
        offers,
      ];
}
