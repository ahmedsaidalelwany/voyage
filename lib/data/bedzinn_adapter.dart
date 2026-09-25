import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:webview_flutter/webview_flutter.dart';
import '../domain/raw_supplier_search_result.dart';
import '../domain/search_criteria.dart';
import '../domain/supplier_adapter.dart';
import '../domain/supplier_identity.dart';

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
        onPageFinished: (url) async {
          try {
            finish(await checkAuthSuccess(controller, url));
          } catch (_) {
            finish(false);
          }
        },
        onWebResourceError: (_) => finish(false),
      ),
    );

    try {
      await controller.loadRequest(Uri.parse(supplier.authUrl));
      return await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> checkAuthSuccess(WebViewController controller, String url) async {
    try {
      final result = await controller.runJavaScriptReturningResult('''
        (function() {
          const text = document.body ? document.body.innerText : '';
          return JSON.stringify({
            hasLogout: /\\bLogout\\b|\\bSign out\\b|\\bMy Account\\b/i.test(text),
            hasLogin: /\\bLogin\\b|\\bSign in\\b/i.test(text)
          });
        })();
      ''');
      final decoded = jsonDecode(_unwrapJsString(result));
      return decoded['hasLogout'] == true && decoded['hasLogin'] != true;
    } catch (error) {
      developer.log('[Bedzinn] Auth check failed: $error');
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    await WebViewCookieManager().clearCookies();
  }

  @override
  Future<RawSupplierSearchResult> search(SearchCriteria criteria) async {
    developer.log(
      '[Bedzinn] Search started: destination=' + criteria.destination.name +
      ', checkIn=' + criteria.checkIn.toIso8601String() +
      ', checkOut=' + criteria.checkOut.toIso8601String() +
      ', rooms=' + criteria.rooms.length.toString() +
      ', currency=' + criteria.currency,
    );

    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);

    final completer = Completer<List<Map<String, dynamic>>>();
    var submitted = false;
    var extractionStarted = false;

    Future<void> extractResults() async {
      if (extractionStarted || completer.isCompleted) return;
      extractionStarted = true;
      try {
        final raw = await controller.runJavaScriptReturningResult('''
          (function() {
            const selectors = [
              '[data-hotel-id]','[data-property-id]','article','table tbody tr',
              '.hotel-item','.hotel-card','.result-card','.property-card','.hotel_list',
              '[class*="hotel-item"]','[class*="hotel-card"]',
              '[class*="hotel-list"]','[class*="property-card"]',
              '[class*="result-card"]','[class*="hotel_row"]'
            ];
            let cards = [];
            for (const selector of selectors) {
              const found = Array.from(document.querySelectorAll(selector));
              if (found.length > cards.length) cards = found;
            }
            return JSON.stringify(cards.map(card => {
              const titleNode = card.querySelector(
                '[data-hotel-name],.hotel-title,.hotel-name,.property-name,h1,h2,h3,h4,h5,' +
                '[class*="hotel-name"],[class*="property-name"],[class*="name"]'
              );
              const priceNode = card.querySelector(
                '.price,.amount,.room-price,[class*="price"],[class*="amount"]'
              );
              const roomNode = card.querySelector(
                '.room-type,.room-name,[class*="room-type"],[class*="room-name"]'
              );
              const mealNode = card.querySelector(
                '.meal-plan,.board-type,[class*="meal"],[class*="board"]'
              );
              const title = titleNode?.innerText?.trim() || '';
              const priceText = priceNode?.innerText?.trim() || '';
              const priceMatch = priceText.replace(/,/g, '').match(/-?\\d+(?:\\.\\d+)?/);
              const currencyMatch = priceText.match(/\b(AED|USD|EUR|GBP|EGP|SAR|QAR|KWD|BHD|OMR)\b/i);
              const images = Array.from(card.querySelectorAll('img'))
                .map(img => img.currentSrc || img.src || '')
                .filter(src => /^https?:/i.test(src))
                .slice(0, 5);
              return {
                name: title,
                price: priceMatch ? Number(priceMatch[0]) : null,
                rawPriceString: priceText,
                currency: currencyMatch ? currencyMatch[1].toUpperCase() : null,
                roomType: roomNode?.innerText?.trim() || null,
                mealPlan: mealNode?.innerText?.trim() || null,
                images: images,
                supplierHotelId: card.getAttribute('data-hotel-id') || card.getAttribute('data-property-id') || null
              };
            }).filter(item => item.name.length > 0));
          })();
        ''');

        final decoded = jsonDecode(_unwrapJsString(raw));
        final results = decoded is List
            ? decoded.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
            : <Map<String, dynamic>>[];

        if (results.isEmpty) {
          final bodyText = await controller.runJavaScriptReturningResult('''
            (function() {
              return document.body ? document.body.innerText.slice(0, 2000) : '';
            })();
          ''');
          developer.log('[Bedzinn] No result cards. Page text snapshot: $bodyText');
          throw StateError(
            'Bedzinn returned a search page, but no hotel offers could be identified. '
            'The supplier page structure or search flow requires an updated integration.',
          );
        }
        completer.complete(results);
      } catch (error, stackTrace) {
        developer.log('[Bedzinn] Result extraction failed: $error', stackTrace: stackTrace);
        completer.completeError(error, stackTrace);
      }
    }

    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (url) async {
          developer.log('[Bedzinn] Page finished: $url');
          if (submitted) {
            await Future<void>.delayed(const Duration(seconds: 1));
            await extractResults();
            return;
          }

          submitted = true;
          try {
            final payload = jsonEncode({
              'destination': criteria.destination.name,
              'checkIn': criteria.checkIn.toIso8601String().split('T').first,
              'checkOut': criteria.checkOut.toIso8601String().split('T').first,
              'currency': criteria.currency,
              'rooms': criteria.rooms.map((room) => {
                'adults': room.adults,
                'childrenAges': room.childrenAges,
              }).toList(),
            });

            final js = '''
              (function() {
                const request = $payload;
                const setValue = (selectors, value) => {
                  const input = selectors.map(s => document.querySelector(s)).find(e => e);
                  if (!input) return false;
                  input.focus();
                  input.value = value;
                  input.dispatchEvent(new Event('input', {bubbles:true}));
                  input.dispatchEvent(new Event('change', {bubbles:true}));
                  input.blur();
                  return true;
                };

                const destinationSet = setValue(
                  ['input[name="destination"]','input[name="city"]','#search_destination',
                   'input[placeholder*="Destination" i]','input[placeholder*="City" i]'],
                  request.destination
                );
                const checkInSet = setValue(
                  ['input[name="checkin"]','input[name="fromDate"]','#checkin',
                   'input[name="check_in"]','input[name="checkIn"]'],
                  request.checkIn
                );
                const checkOutSet = setValue(
                  ['input[name="checkout"]','input[name="toDate"]','#checkout',
                   'input[name="check_out"]','input[name="checkOut"]'],
                  request.checkOut
                );

                const currency = document.querySelector('select[name="currency"],select#currency');
                if (currency) {
                  currency.value = request.currency;
                  currency.dispatchEvent(new Event('change', {bubbles:true}));
                }

                const button = document.querySelector(
                  'button[type="submit"],input[type="submit"],#btnSearch,.SearchBtn3'
                );
                if (button) {
                  button.click();
                  return 'submitted';
                }

                const form = document.querySelector('form');
                if (form) {
                  form.submit();
                  return 'submitted-form';
                }

                return 'search-controls-not-found:' +
                  [destinationSet,checkInSet,checkOutSet].join(',');
              })();
            ''';

            final submissionResult = await controller.runJavaScriptReturningResult(js);
            developer.log('[Bedzinn] Search submission result: $submissionResult');
            await Future<void>.delayed(const Duration(seconds: 2));
            await extractResults();
          } catch (error, stackTrace) {
            developer.log('[Bedzinn] Search execution failed: $error', stackTrace: stackTrace);
            if (!completer.isCompleted) completer.completeError(error, stackTrace);
          }
        },
        onWebResourceError: (error) {
          developer.log('[Bedzinn] Web resource error: ' +
              error.errorCode.toString() + ' ' + error.description);
        },
      ),
    );

    await controller.loadRequest(Uri.parse(supplier.authUrl));

    try {
      final results = await completer.future.timeout(const Duration(seconds: 30));
      return BedzinnRawResult(results);
    } on TimeoutException {
      throw TimeoutException('Bedzinn search did not produce results within 30 seconds.');
    }
  }

  String _unwrapJsString(Object value) {
    final text = value.toString();
    if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is String) return decoded;
      } catch (_) {}
    }
    return text;
  }
}
