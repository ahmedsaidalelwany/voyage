import '../domain/destination.dart';

class DestinationService {
  Future<List<Destination>> getSuggestions(String query) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));
    
    final allDestinations = [
      const Destination(
        name: 'Dubai',
        type: 'City',
        countryCode: 'AE',
        supplierDestinationIds: {'bedzinn': 'DXB', 'tripovo': '1234', 'elite': '5678'},
      ),
      const Destination(
        name: 'United Arab Emirates',
        type: 'Country',
        countryCode: 'AE',
        supplierDestinationIds: {'bedzinn': 'AE', 'tripovo': 'AE', 'elite': 'AE'},
      ),
      const Destination(
        name: 'New York',
        type: 'City',
        countryCode: 'US',
        supplierDestinationIds: {'bedzinn': 'NYC', 'tripovo': '2345', 'elite': '6789'},
      ),
      const Destination(
        name: 'Maldives',
        type: 'Country',
        countryCode: 'MV',
        supplierDestinationIds: {'bedzinn': 'MV', 'tripovo': 'MV', 'elite': 'MV'},
      ),
      const Destination(
        name: 'Egypt',
        type: 'Country',
        countryCode: 'EG',
        supplierDestinationIds: {'bedzinn': 'EG', 'tripovo': 'EG', 'elite': 'EG'},
      ),
      const Destination(
        name: 'Cairo',
        type: 'City',
        countryCode: 'EG',
        supplierDestinationIds: {'bedzinn': 'CAI', 'tripovo': '3456', 'elite': '7890'},
      ),
      const Destination(
        name: 'London',
        type: 'City',
        countryCode: 'GB',
        supplierDestinationIds: {'bedzinn': 'LON', 'tripovo': '4567', 'elite': '8901'},
      ),
    ];

    if (query.isEmpty) return [];

    return allDestinations
        .where((d) => d.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
}
