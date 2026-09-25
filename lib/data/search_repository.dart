import '../domain/hotel.dart';
import '../domain/hotel_offer.dart';
import '../domain/raw_supplier_search_result.dart';
import 'bedzinn_adapter.dart';

class SearchRepository {
  List<Hotel> normalize(RawSupplierSearchResult rawResult) {
    if (rawResult is BedzinnRawResult) {
      return rawResult.scrapedHotels
          .where((data) => data['name']?.toString().trim().isNotEmpty ?? false)
          .map((data) {
        final name = data['name'].toString().trim();
        return Hotel(
          id: _stableHotelId(
            name: name,
            city: data['city']?.toString(),
            country: data['country']?.toString(),
            supplierHotelId: data['supplierHotelId']?.toString(),
          ),
          name: name,
          location: data['location']?.toString(),
          city: data['city']?.toString(),
          country: data['country']?.toString(),
          stars: _toInt(data['stars']),
          rating: _toDouble(data['rating']),
          images: _stringList(data['images']),
          offers: [
            HotelOffer(
              supplierId: rawResult.supplierId,
              supplierHotelId: data['supplierHotelId']?.toString(),
              roomType: data['roomType']?.toString(),
              roomDescription: data['roomDescription']?.toString(),
              numberOfRooms: _toInt(data['numberOfRooms']),
              adults: _toInt(data['adults']),
              children: _toInt(data['children']),
              mealPlan: data['mealPlan']?.toString(),
              cancellationPolicy: data['cancellationPolicy']?.toString(),
              isAvailable: data['isAvailable'] as bool?,
              price: _toDouble(data['price']),
              currency: data['currency']?.toString(),
              taxes: _toDouble(data['taxes']),
              totalPrice: _toDouble(data['totalPrice']),
            ),
          ],
        );
      }).toList();
    }
    return [];
  }

  List<Hotel> matchHotels(List<Hotel> rawHotels) {
    final grouped = <String, Hotel>{};
    for (final hotel in rawHotels) {
      final key = _matchKey(hotel);
      if (!grouped.containsKey(key)) {
        grouped[key] = hotel;
        continue;
      }
      final existing = grouped[key]!;
      grouped[key] = Hotel(
        id: existing.id,
        name: existing.name,
        location: existing.location ?? hotel.location,
        city: existing.city ?? hotel.city,
        country: existing.country ?? hotel.country,
        stars: existing.stars ?? hotel.stars,
        rating: existing.rating ?? hotel.rating,
        images: existing.images.isNotEmpty ? existing.images : hotel.images,
        offers: [...existing.offers, ...hotel.offers],
      );
    }
    return grouped.values.toList();
  }

  String _matchKey(Hotel hotel) =>
      _normalizeText(hotel.name) + '|' +
      _normalizeText(hotel.city ?? '') + '|' +
      _normalizeText(hotel.country ?? '');

  String _stableHotelId({
    required String name,
    String? city,
    String? country,
    String? supplierHotelId,
  }) {
    if (supplierHotelId != null && supplierHotelId.isNotEmpty) {
      return supplierHotelId.trim() + '|' + _normalizeText(name);
    }
    return _normalizeText(name) + '|' +
        _normalizeText(city ?? '') + '|' +
        _normalizeText(country ?? '');
  }

  String _normalizeText(String value) {
    return value.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06ff]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final text = value.toString().replaceAll(',', '');
    final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(text);
    return match == null ? null : double.tryParse(match.group(0)!);
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return [];
    return value.map((item) => item.toString()).where((value) => value.isNotEmpty).toList();
  }
}
