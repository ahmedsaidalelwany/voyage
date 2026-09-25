import 'package:flutter_test/flutter_test.dart';
import 'package:voyage/domain/search_criteria.dart';
import 'package:voyage/domain/destination.dart';
import 'package:voyage/domain/room_occupancy.dart';
import 'package:voyage/domain/hotel.dart';
import 'package:voyage/domain/raw_supplier_search_result.dart';
import 'package:voyage/domain/supplier_adapter.dart';
import 'package:voyage/domain/supplier_identity.dart';
import 'package:voyage/logic/search_cubit.dart';
import 'package:voyage/data/search_repository.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TestRawResult extends RawSupplierSearchResult {
  TestRawResult() : super('test_supplier');
}

class FakeSupplierAdapter implements SupplierAdapter {
  SearchCriteria? receivedCriteria;

  @override
  SupplierIdentity get supplier => const SupplierIdentity(id: 'test', name: 'Test', authUrl: '');

  @override
  Future<bool> checkAuthSuccess(WebViewController controller, String url) async => true;

  @override
  Future<void> disconnect() async {}

  @override
  Future<bool> isAuthenticated() async => true;

  @override
  Future<RawSupplierSearchResult> search(SearchCriteria criteria) async {
    receivedCriteria = criteria;
    return TestRawResult();
  }
}

class FakeSearchRepository extends SearchRepository {
  @override
  List<Hotel> normalize(RawSupplierSearchResult rawResult) {
    return [];
  }
}

void main() {
  test('SearchCubit passes correct SearchCriteria to adapter', () async {
    final adapter = FakeSupplierAdapter();
    final repo = FakeSearchRepository();
    final cubit = SearchCubit(repo);

    final criteria = SearchCriteria(
      destination: const Destination(name: 'Cairo', type: 'City'),
      checkIn: DateTime(2026, 11, 10),
      checkOut: DateTime(2026, 11, 17),
      rooms: const [
        RoomOccupancy(adults: 2, childrenAges: [7]),
        RoomOccupancy(adults: 1),
      ],
      currency: 'EGP',
    );

    await cubit.search(criteria, [adapter]);

    // Verify adapter received exact criteria
    expect(adapter.receivedCriteria, isNotNull);
    expect(adapter.receivedCriteria!.destination.name, 'Cairo');
    expect(adapter.receivedCriteria!.currency, 'EGP');
    expect(adapter.receivedCriteria!.checkIn.year, 2026);
    expect(adapter.receivedCriteria!.checkIn.month, 11);
    expect(adapter.receivedCriteria!.checkIn.day, 10);
    expect(adapter.receivedCriteria!.rooms.length, 2);
    expect(adapter.receivedCriteria!.rooms[0].adults, 2);
    expect(adapter.receivedCriteria!.rooms[0].childrenAges.length, 1);
    expect(adapter.receivedCriteria!.rooms[0].childrenAges[0], 7);
    expect(adapter.receivedCriteria!.rooms[1].adults, 1);
  });
}
