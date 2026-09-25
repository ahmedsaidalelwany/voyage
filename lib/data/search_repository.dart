import '../domain/hotel.dart';
import '../domain/hotel_offer.dart';
import '../domain/raw_supplier_search_result.dart';
import '../domain/result_filters.dart';
import '../domain/search_criteria.dart';
import 'bedzinn_adapter.dart';
import 'mock_adapters.dart';

class SearchRepository {
  List<Hotel> normalize(RawSupplierSearchResult rawResult) {
    if (rawResult is PortalRawResult) {
      return _normalizeHotels(
        rawResult.supplierId,
        rawResult.hotels,
      );
    }

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

  List<Hotel> _normalizeHotels(
    String supplierId,
    List<Map<String, dynamic>> dataList,
  ) {
    return dataList
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
                supplierId: supplierId,
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
        })
        .toList();
  }

  List<Hotel> applyFilters(List<Hotel> hotels, SearchCriteria criteria) {
    return filterHotels(
      hotels,
      ResultFilters(
        maxPrice: criteria.maximumPrice,
        minRating: criteria.minimumStars,
        mealPlan: criteria.mealPlan,
        cancellationPolicy: criteria.cancellationPreference,
        availableOnly: criteria.availableOnly,
      ),
      criteria,
    );
  }

  List<Hotel> filterHotels(
    List<Hotel> hotels,
    ResultFilters filters,
    SearchCriteria criteria,
  ) {
    return hotels.map((hotel) {
      final query = criteria.hotelName?.trim().toLowerCase();
      if (query != null && query.isNotEmpty && !hotel.name.toLowerCase().contains(query)) {
        return null;
      }

      if (filters.minRating != null && (hotel.stars ?? 0) < filters.minRating!) {
        return null;
      }

      final offers = hotel.offers.where((offer) {
        if (filters.supplierId != null && filters.supplierId != 'All' && offer.supplierId != filters.supplierId) {
          return false;
        }
        if (filters.availableOnly && offer.isAvailable != true) return false;
        if (filters.mealPlan != null &&
            filters.mealPlan!.isNotEmpty &&
            !(offer.mealPlan ?? '').toLowerCase().contains(filters.mealPlan!.toLowerCase())) {
          return false;
        }
        if (filters.cancellationPolicy != null &&
            filters.cancellationPolicy!.isNotEmpty &&
            !(offer.cancellationPolicy ?? '').toLowerCase().contains(filters.cancellationPolicy!.toLowerCase())) {
          return false;
        }
        if (filters.maxPrice != null && offer.price != null) {
          if (offer.currency != criteria.currency) return false;
          if (offer.price! > filters.maxPrice!) return false;
        }
        return true;
      }).toList();

      if (offers.isEmpty) return null;
      return hotel.copyWithOffers(offers);
    }).whereType<Hotel>().toList();
  }

  List<Hotel> matchHotels(List<Hotel> rawHotels) {
    final grouped = <String, Hotel>{};

    for (final hotel in rawHotels) {
      final key = _matchKey(hotel);
      final existing = grouped[key];

      if (existing == null) {
        grouped[key] = hotel;
        continue;
      }

      final existingIds = existing.offers.map((offer) => offer.supplierHotelId)
          .whereType<String>().where((id) => id.isNotEmpty).toSet();
      final incomingIds = hotel.offers.map((offer) => offer.supplierHotelId)
          .whereType<String>().where((id) => id.isNotEmpty).toSet();

      if (existingIds.isNotEmpty &&
          incomingIds.isNotEmpty &&
          existingIds.intersection(incomingIds).isNotEmpty) {
        grouped[key] = _merge(existing, hotel);
      } else {
        final uniqueKey = key + '|' + hotel.offers.first.supplierId + '|' + hotel.id;
        grouped[uniqueKey] = hotel;
      }
    }

    return grouped.values.toList();
  }

  Hotel _merge(Hotel a, Hotel b) {
    return Hotel(
      id: a.id,
      name: a.name,
      location: a.location ?? b.location,
      city: a.city ?? b.city,
      country: a.country ?? b.country,
      stars: a.stars ?? b.stars,
      rating: a.rating ?? b.rating,
      images: a.images.isNotEmpty ? a.images : b.images,
      offers: [...a.offers, ...b.offers],
    );
  }

  String _matchKey(Hotel hotel) {
    final id = hotel.offers.map((offer) => offer.supplierHotelId)
        .whereType<String>().where((id) => id.isNotEmpty).join('|');
    if (id.isNotEmpty) return 'supplier-id:' + id;
    return 'hotel:' + _normalizeText(hotel.name) + '|' +
        _normalizeText(hotel.city ?? '') + '|' +
        _normalizeText(hotel.country ?? '') + '|' +
        (hotel.stars ?? 0).toString();
  }

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
