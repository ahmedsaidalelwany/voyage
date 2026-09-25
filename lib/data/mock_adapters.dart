import 'dart:async';
import 'dart:convert';
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
  Future<bool> isAuthenticated() async {
    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    final completer = Completer<bool>();
    var done = false;

    void finish(bool value) {
      if (done || completer.isCompleted) return;
      done = true;
      completer.complete(value);
    }

    await controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (url) async => finish(await checkAuthSuccess(controller, url)),
        onWebResourceError: (_) => finish(false),
      ),
    );

    try {
      await controller.loadRequest(Uri.parse(supplier.authUrl));
      return await completer.future.timeout(const Duration(seconds: 8), onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> checkAuthSuccess(WebViewController controller, String url) async {
    try {
      final raw = await controller.runJavaScriptReturningResult('''
        (function() {
          const text = document.body ? document.body.innerText : '';
          const hasLogout = /\\bLogout\\b|\\bSign out\\b|\\bMy Account\\b|\\bLog out\\b/i.test(text);
          const hasLogin = /\\bLogin\\b|\\bSign in\\b|\\bLog in\\b/i.test(text);
          return JSON.stringify({hasLogout, hasLogin});
        })();
      ''');
      final text = raw.toString();
      final decoded = jsonDecode(
        text.length >= 2 && text.startsWith('"') && text.endsWith('"')
            ? jsonDecode(text)
            : text,
      );
      return decoded['hasLogout'] == true && decoded['hasLogin'] != true;
    } catch (_) {
      return false;
    }
  }

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
        authUrl: 'https://agents.tripovo.com/login?returnTo=%2Fhome%3Fproduct%3Dhotel',
      );
}

class EliteBookingsAdapter extends ScaffoldAdapter {
  @override
  SupplierIdentity get supplier => const SupplierIdentity(
        id: 'elite',
        name: 'Elite Bookings',
        authUrl: 'https://www.elite-bookings.com/ar/idea/64073179/755223/-',
      );
}

class MustasharAdapter extends ScaffoldAdapter {
  @override
  SupplierIdentity get supplier => const SupplierIdentity(
        id: 'mustashar',
        name: 'Mustashar Holidays',
        authUrl: 'https://www.mustasharholidays.com/index.php',
      );
}
