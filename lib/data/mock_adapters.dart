import 'package:webview_flutter/webview_flutter.dart';
import '../domain/supplier_adapter.dart';
import '../domain/supplier_identity.dart';
import '../domain/search_criteria.dart';
import '../domain/raw_supplier_search_result.dart';

class MockRawResult extends RawSupplierSearchResult {
  MockRawResult(super.supplierId);
}

abstract class ScaffoldAdapter implements SupplierAdapter {
  @override
  Future<bool> isAuthenticated() async => false;

  @override
  Future<bool> checkAuthSuccess(WebViewController controller, String url) async => false;

  @override
  Future<void> disconnect() async {}

  @override
  Future<RawSupplierSearchResult> search(SearchCriteria criteria) async {
    throw UnsupportedError('\${supplier.name} integration is currently unavailable. No documented API.');
  }
}

class TripovoAdapter extends ScaffoldAdapter {
  @override
  SupplierIdentity get supplier => const SupplierIdentity(
        id: 'tripovo',
        name: 'Tripovo Agents',
        authUrl: '', // Empty prevents connection
      );
}

class EliteBookingsAdapter extends ScaffoldAdapter {
  @override
  SupplierIdentity get supplier => const SupplierIdentity(
        id: 'elite',
        name: 'Elite Bookings',
        authUrl: '',
      );
}

class MustasharAdapter extends ScaffoldAdapter {
  @override
  SupplierIdentity get supplier => const SupplierIdentity(
        id: 'mustashar',
        name: 'Mustashar Holidays',
        authUrl: '',
      );
}
