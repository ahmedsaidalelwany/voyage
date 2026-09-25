import 'package:equatable/equatable.dart';

class Destination extends Equatable {
  final String name;
  final String type; // 'city', 'country', 'region', 'hotel', 'airport'
  final String? countryCode;
  final String? cityCode;
  final String? regionId;
  final Map<String, String> supplierDestinationIds;

  const Destination({
    required this.name,
    this.type = 'city',
    this.countryCode,
    this.cityCode,
    this.regionId,
    this.supplierDestinationIds = const {},
  });

  @override
  List<Object?> get props => [
        name,
        type,
        countryCode,
        cityCode,
        regionId,
        supplierDestinationIds,
      ];
}
