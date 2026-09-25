import 'package:webview_flutter/webview_flutter.dart';
import '../domain/supplier_adapter.dart';
import '../domain/supplier_identity.dart';
import '../domain/search_criteria.dart';
import '../domain/raw_supplier_search_result.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'dart:convert';

class BedzinnRawResult extends RawSupplierSearchResult {
  final List<Map<String, dynamic>> scrapedHotels;
  BedzinnRawResult(this.scrapedHotels) : super('bedzinn');
}

class BedzinnAdapter implements SupplierAdapter {
  @override
  SupplierIdentity get supplier => const SupplierIdentity(
        id: 'bedzinn',
        name: 'Bedzinn',
        authUrl: 'https://www.bedzinn.com/',
      );

  @override
  Future<bool> isAuthenticated() async {
    return false; // Skip the automatic check for now to save time in the POC, we rely on the manual auth flow.
  }

  @override
  Future<bool> checkAuthSuccess(WebViewController controller, String url) async {
    try {
      final String html = await controller.runJavaScriptReturningResult('document.body.innerHTML') as String;
      if (html.contains('my_accnt') || html.contains('Logout') || html.contains('sign_out') || url.contains('service_search.php')) {
        return true;
      }
    } catch (e) {
      developer.log('[${supplier.name}] Error checking auth: $e');
    }
    return false;
  }

  @override
  Future<void> disconnect() async {
    final cookieManager = WebViewCookieManager();
    await cookieManager.clearCookies();
  }

  @override
  Future<RawSupplierSearchResult> search(SearchCriteria criteria) async {
    developer.log('[${supplier.name}] Searching via WebViewController scraping...');
    
    // We will spin up an off-screen WebViewController to perform the search.
    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);

    // Bedzinn currency support mapping
    // If criteria.currency is not supported, we must log a limitation.
    // Bedzinn typically uses the currency of the logged-in agent, but might have a currency dropdown.
    developer.log('[${supplier.name}] Requested Currency: ${criteria.currency}. Will attempt to set if supported.');

    final completer = Completer<List<Map<String, dynamic>>>();

    controller.setNavigationDelegate(NavigationDelegate(
      onPageFinished: (url) async {
        developer.log('[${supplier.name}] Page loaded: $url');
        
        if (url.contains('service_search.php') || url == 'https://www.bedzinn.com/') {
          try {
            // Attempt to inject search criteria into the DOM and submit
            // This is a generic heuristic scraper since we lack the exact DOM structure
            final jsCode = '''
              try {
                // 1. Fill Destination
                const destInput = document.querySelector('input[name="destination"], input[name="city"], input[placeholder*="Destination"], #search_destination');
                if (destInput) {
                   destInput.value = "${criteria.destination.name}";
                }
                
                // 2. Fill Dates
                const checkInInput = document.querySelector('input[name="checkin"], input[name="fromDate"], #checkin');
                if (checkInInput) {
                   checkInInput.value = "${criteria.checkIn.toIso8601String().split('T')[0]}";
                }
                const checkOutInput = document.querySelector('input[name="checkout"], input[name="toDate"], #checkout');
                if (checkOutInput) {
                   checkOutInput.value = "${criteria.checkOut.toIso8601String().split('T')[0]}";
                }

                // 3. Set Currency if possible
                const currSelect = document.querySelector('select[name="currency"]');
                if (currSelect) {
                   currSelect.value = "${criteria.currency}";
                }
                
                // 4. Click Search
                const searchBtn = document.querySelector('button[type="submit"], input[type="submit"], #btnSearch, .SearchBtn3');
                if (searchBtn) {
                   searchBtn.click();
                } else {
                   // Fallback submit form
                   document.forms[0].submit();
                }
              } catch(e) {
                console.log(e);
              }
            ''';
            
            await controller.runJavaScript(jsCode);
            
            // Wait a few seconds for ajax/results
            await Future.delayed(const Duration(seconds: 4));
            
            // Extract results
            final extractJs = '''
              (function() {
                const hotels = [];
                // Look for common hotel card classes
                const cards = document.querySelectorAll('.hotel-item, .result-card, .property-card, .hotel_list');
                cards.forEach(card => {
                   const title = card.querySelector('.hotel-title, .hotel-name, h3, h4')?.innerText || 'Unknown Hotel';
                   const priceText = card.querySelector('.price, .amount, .room-price')?.innerText || '';
                   // Extract numbers from price
                   const priceMatch = priceText.replace(/,/g, '').match(/\\d+(\\.\\d+)?/);
                   const price = priceMatch ? parseFloat(priceMatch[0]) : null;
                   
                   hotels.push({
                     name: title,
                     price: price,
                     rawPriceString: priceText,
                     currency: "${criteria.currency}", // Assuming it reflects our requested currency
                     roomType: card.querySelector('.room-type, .room-name')?.innerText || 'Standard Room',
                     mealPlan: card.querySelector('.meal-plan, .board-type')?.innerText || 'Room Only',
                   });
                });
                return JSON.stringify(hotels);
              })();
            ''';
            
            final Object rawResult = await controller.runJavaScriptReturningResult(extractJs);
            final String jsonString = rawResult as String;
            final dynamic firstDecode = jsonDecode(jsonString);
            
            final List<dynamic> parsed;
            if (firstDecode is String) {
              parsed = jsonDecode(firstDecode) as List<dynamic>;
            } else {
              parsed = firstDecode as List<dynamic>;
            }
            
            final List<Map<String, dynamic>> results = parsed.map((e) => e as Map<String, dynamic>).toList();
            
            if (!completer.isCompleted) {
               completer.complete(results);
            }
          } catch (e) {
            developer.log('[${supplier.name}] Error scraping: $e');
            if (!completer.isCompleted) completer.complete([]);
          }
        }
      },
    ));

    await controller.loadRequest(Uri.parse('https://www.bedzinn.com/service_search.php'));

    // Wait for the scraping flow to finish or timeout
    try {
      final results = await completer.future.timeout(const Duration(seconds: 15));
      return BedzinnRawResult(results);
    } catch (e) {
      developer.log('[${supplier.name}] Scraping timeout or error: $e');
      throw Exception('Bedzinn scraping failed or timed out: $e');
    }
  }
}
