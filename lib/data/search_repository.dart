import '../domain/hotel.dart';
import '../domain/hotel_offer.dart';
import '../domain/raw_supplier_search_result.dart';
import 'bedzinn_adapter.dart'; 

class SearchRepository {
  List<Hotel> normalize(RawSupplierSearchResult rawResult) {
    if (rawResult is BedzinnRawResult) {
      if (rawResult.scrapedHotels.isEmpty) {
        // No results found from scraping.
        return [];
      }
      
      return rawResult.scrapedHotels.map((data) {
        return Hotel(
          id: data['name'].toString().toLowerCase().replaceAll(' ', '_'),
          name: data['name'],
          stars: 4, 
          offers: [
            HotelOffer(
              supplierId: 'bedzinn',
              roomType: data['roomType'],
              mealPlan: data['mealPlan'],
              isAvailable: true,
              price: data['price']?.toDouble() ?? 0.0,
              currency: data['currency'],
            )
          ],
        );
      }).toList();
    } else {
      // For any other unimplemented/mock raw result type, return nothing.
      return [];
    }
  }

  List<Hotel> matchHotels(List<Hotel> rawHotels) {
    // Basic grouping by name and city for the POC
    final Map<String, Hotel> grouped = {};
    
    for (var hotel in rawHotels) {
      final String matchKey = '${hotel.name.toLowerCase()}_${hotel.city?.toLowerCase()}';
      
      if (grouped.containsKey(matchKey)) {
        final existing = grouped[matchKey]!;
        grouped[matchKey] = existing.copyWithOffers([...existing.offers, ...hotel.offers]);
      } else {
        grouped[matchKey] = hotel;
      }
    }
    
    return grouped.values.toList();
  }
}
