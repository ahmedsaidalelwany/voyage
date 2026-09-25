import 'package:webview_flutter/webview_flutter.dart';
import 'supplier_identity.dart';
import 'search_criteria.dart';
import 'raw_supplier_search_result.dart';

abstract class SupplierAdapter {
  SupplierIdentity get supplier;

  /// Returns true if an authenticated session currently exists.
  Future<bool> isAuthenticated();

  /// Analyzes the WebView to determine if authentication succeeded.
  Future<bool> checkAuthSuccess(WebViewController controller, String url);

  /// Clears the session for this supplier.
  Future<void> disconnect();

  /// Searches for hotels using the supplier's specific integration method.
  Future<RawSupplierSearchResult> search(SearchCriteria criteria);
}
