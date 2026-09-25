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
    void finish(bool v) {
      if (done || completer.isCompleted) return;
      done = true;
      completer.complete(v);
    }
    await controller.setNavigationDelegate(NavigationDelegate(
      onPageFinished: (url) async {
        try { finish(await checkAuthSuccess(controller, url)); } catch (_) { finish(false); }
      },
      onWebResourceError: (_) => finish(false),
    ));
    try {
      await controller.loadRequest(Uri.parse(supplier.authUrl));
      return await completer.future.timeout(const Duration(seconds: 8), onTimeout: () => false);
    } catch (_) { return false; }
  }

  @override
  Future<bool> checkAuthSuccess(WebViewController controller, String url) async {
    try {
      final result = await controller.runJavaScriptReturningResult(r"""
        (function() {
          const text = document.body ? document.body.innerText : '';
          return JSON.stringify({
            hasLogout: /\bLogout\b|\bSign out\b|\bMy Account\b/i.test(text),
            hasLogin:  /\bLogin\b|\bSign in\b/i.test(text)
          });
        })();
      """);
      final decoded = jsonDecode(_unwrapJsString(result));
      return decoded['hasLogout'] == true && decoded['hasLogin'] != true;
    } catch (e) {
      developer.log('[Bedzinn] Auth check failed: $e');
      return false;
    }
  }

  @override
  Future<void> disconnect() async => WebViewCookieManager().clearCookies();

  @override
  Future<RawSupplierSearchResult> search(SearchCriteria criteria) async {
    developer.log('[Bedzinn] Search: dest=${criteria.destination.name} '
      'in=${criteria.checkIn.toIso8601String()} out=${criteria.checkOut.toIso8601String()} '
      'rooms=${criteria.rooms.length} cur=${criteria.currency}');

    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    final completer = Completer<List<Map<String, dynamic>>>();
    var submitted = false;
    var extracting = false;

    Future<void> extractResults() async {
      if (extracting || completer.isCompleted) return;
      extracting = true;
      try {
        final raw = await controller.runJavaScriptReturningResult(r"""
          (function() {
            const selectors = [
              '[data-hotel-id]','[data-property-id]','article','table tbody tr',
              '.hotel-item','.hotel-card','.result-card','.property-card','.hotel_list',
              '[class*="hotel-item"]','[class*="hotel-card"]',
              '[class*="hotel-list"]','[class*="property-card"]',
              '[class*="result-card"]','[class*="hotel_row"]'
            ];
            let cards = [];
            for (const s of selectors) {
              const found = Array.from(document.querySelectorAll(s));
              if (found.length > cards.length) cards = found;
            }
            return JSON.stringify(cards.map(card => {
              const t = card.querySelector('[data-hotel-name],.hotel-title,.hotel-name,.property-name,h2,h3,h4,[class*="hotel-name"],[class*="name"]');
              const p = card.querySelector('.price,.amount,.room-price,[class*="price"],[class*="amount"]');
              const r = card.querySelector('.room-type,.room-name,[class*="room-type"],[class*="room-name"]');
              const m = card.querySelector('.meal-plan,.board-type,[class*="meal"],[class*="board"]');
              const title = t?.innerText?.trim() || '';
              const priceText = p?.innerText?.trim() || '';
              const pm = priceText.replace(/,/g,'').match(/-?\d+(?:\.\d+)?/);
              const cm = priceText.match(/\b(AED|USD|EUR|GBP|EGP|SAR|QAR|KWD|BHD|OMR)\b/i);
              const imgs = Array.from(card.querySelectorAll('img')).map(i => i.currentSrc||i.src||'').filter(s => /^https?:/i.test(s)).slice(0,5);
              return {
                name: title,
                price: pm ? Number(pm[0]) : null,
                rawPriceString: priceText,
                currency: cm ? cm[1].toUpperCase() : null,
                roomType: r?.innerText?.trim() || null,
                mealPlan: m?.innerText?.trim() || null,
                images: imgs,
                supplierHotelId: card.getAttribute('data-hotel-id')||card.getAttribute('data-property-id')||null
              };
            }).filter(x => x.name.length > 0));
          })();
        """);
        final decoded = jsonDecode(_unwrapJsString(raw));
        final results = decoded is List
          ? decoded.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList()
          : <Map<String, dynamic>>[];
        if (results.isEmpty) {
          final snap = await controller.runJavaScriptReturningResult("(document.body?.innerText?.slice(0,2000)||'')");
          developer.log('[Bedzinn] No cards found. Page: ${_unwrapJsString(snap)}');
          throw StateError('Bedzinn: no hotel offers identified on results page.');
        }
        if (!completer.isCompleted) completer.complete(results);
      } catch (e, st) {
        developer.log('[Bedzinn] Extraction failed: $e', stackTrace: st);
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    }

    controller.setNavigationDelegate(NavigationDelegate(
      onPageFinished: (url) async {
        developer.log('[Bedzinn] Page finished: $url');
        if (submitted) {
          try {
            final peek = await controller.runJavaScriptReturningResult(
              '(document.querySelectorAll(".hotel-item,.hotel-card,.result-card,.hotel_list,.hotel_row").length>0).toString()'
            );
            if (peek.toString().contains('true')) {
              developer.log('[Bedzinn] Cards on reload, extracting...');
              await Future<void>.delayed(const Duration(milliseconds: 500));
              await extractResults();
            }
          } catch (_) {}
          return;
        }

        // ── First page load: fill form ──────────────────────────────────────
        submitted = true;
        try {
          // Exact OTRAMS field IDs confirmed by diagnostic:
          //  id=date_from        name=arrival_date     format: DD/MM/YYYY
          //  id=date_to          name=departure_date   format: DD/MM/YYYY
          //  id=selected_currency name=sel_currency
          //  id=roomarray        name=roomarray        JSON array
          //  id=txt_other_hotel_city  (jQuery UI autocomplete)
          //  id=city_code        (hidden, populated by autocomplete select)

          final dest = criteria.destination.name;
          String pad(int n) => n.toString().padLeft(2, '0');
          final ci = criteria.checkIn;
          final co = criteria.checkOut;
          final dIn  = '${pad(ci.day)}/${pad(ci.month)}/${ci.year}';
          final dOut = '${pad(co.day)}/${pad(co.month)}/${co.year}';

          final roomArr = jsonEncode(criteria.rooms.map((r) {
            final obj = <String, dynamic>{
              'numberofAdults': '${r.adults}',
              'noOfChildren': '${r.childrenAges.length}',
            };
            for (int i = 0; i < r.childrenAges.length; i++) {
              obj['child_age_${i+1}'] = '${r.childrenAges[i]}';
            }
            return obj;
          }).toList());

          developer.log('[Bedzinn] Filling: dest=$dest in=$dIn out=$dOut cur=${criteria.currency} rooms=$roomArr');

          // A. Dates + currency + roomarray
          final jsA = """
            (function() {
              const setDate = (id, val) => {
                const el = document.getElementById(id);
                if (!el) return false;
                el.readOnly = false;
                const s = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set;
                s.call(el, val);
                el.dispatchEvent(new Event('input',  {bubbles:true}));
                el.dispatchEvent(new Event('change', {bubbles:true}));
                if (window.jQuery) { try { jQuery(el).datepicker('setDate', val); } catch(e){} }
                return true;
              };
              const dIn  = setDate('date_from', ${jsonEncode(dIn)});
              const dOut = setDate('date_to',   ${jsonEncode(dOut)});

              const cur = document.getElementById('selected_currency')
                       || document.querySelector('[name="sel_currency"]');
              if (cur) { cur.value=${jsonEncode(criteria.currency)}; cur.dispatchEvent(new Event('change',{bubbles:true})); }

              const ra = document.getElementById('roomarray') || document.querySelector('[name="roomarray"]');
              if (ra) ra.value = ${jsonEncode(roomArr)};

              return JSON.stringify({dIn, dOut, cur:cur?.value, ra:!!ra});
            })();
          """;
          final rA = await controller.runJavaScriptReturningResult(jsA);
          developer.log('[Bedzinn] A-fill: ${_unwrapJsString(rA)}');

          // B. Trigger jQuery autocomplete
          final jsB = """
            (function() {
              if (!window.jQuery) return 'no-jquery';
              const el = jQuery('#txt_other_hotel_city');
              if (!el.length) return 'no-field';
              el.val(${jsonEncode(dest)});
              el.autocomplete('search', ${jsonEncode(dest)});
              return 'triggered';
            })();
          """;
          final rB = await controller.runJavaScriptReturningResult(jsB);
          developer.log('[Bedzinn] B-ac: ${_unwrapJsString(rB)}');

          // Wait for dropdown
          await Future<void>.delayed(const Duration(seconds: 3));

          // C. Click first suggestion (populates city_code hidden field)
          const jsC = """
            (function() {
              const items = document.querySelectorAll('.ui-menu-item,.ui-menu-item a,.ui-autocomplete li');
              if (!items.length) return 'no-items';
              if (window.jQuery) {
                try {
                  const ac   = jQuery('#txt_other_hotel_city').data('ui-autocomplete');
                  const item = jQuery(items[0]).data('ui-autocomplete-item')
                            || jQuery(items[0]).data('item.autocomplete');
                  if (ac && item) { ac._trigger('select', null, {item}); return 'jq-select:'+String(item.label||item.value||'').slice(0,60); }
                } catch(e){}
              }
              items[0].click();
              return 'clicked:' + items[0].innerText.trim().slice(0,60);
            })();
          """;
          final rC = await controller.runJavaScriptReturningResult(jsC);
          developer.log('[Bedzinn] C-click: ${_unwrapJsString(rC)}');

          await Future<void>.delayed(const Duration(milliseconds: 800));

          // D. Pre-submit verification
          const jsD = """
            (function() {
              return JSON.stringify({
                cityCode: document.getElementById('city_code')?.value||'',
                destText: document.getElementById('txt_other_hotel_city')?.value||'',
                dateIn:   document.getElementById('date_from')?.value||'',
                dateOut:  document.getElementById('date_to')?.value||'',
                cur:      document.getElementById('selected_currency')?.value||'',
              });
            })();
          """;
          final rD = await controller.runJavaScriptReturningResult(jsD);
          developer.log('[Bedzinn] D-verify: ${_unwrapJsString(rD)}');

          // E. Submit
          const jsE = """
            (function() {
              const btn = document.querySelector('[class*="transfer-search-btn-box"],[class*="SearchBtn"],[class*="search-btn"],button[type="submit"],input[type="submit"],#btnSearch');
              if (btn) { btn.click(); return 'btn:'+btn.className.trim().slice(0,40); }
              const form = document.querySelector('form');
              if (form) { form.submit(); return 'form'; }
              return 'none';
            })();
          """;
          final rE = await controller.runJavaScriptReturningResult(jsE);
          developer.log('[Bedzinn] E-submit: ${_unwrapJsString(rE)}');

          // F. Poll for results (up to 60 s)
          for (int i = 0; i < 20 && !completer.isCompleted; i++) {
            await Future<void>.delayed(const Duration(seconds: 3));
            try {
              final has = await controller.runJavaScriptReturningResult(
                '(document.querySelectorAll(".hotel-item,.hotel-card,.result-card,.hotel_list,.hotel_row,[class*=hotel-item],[class*=hotelitem]").length>0).toString()'
              );
              if (has.toString().contains('true')) {
                developer.log('[Bedzinn] Cards after ${(i+1)*3}s');
                await extractResults();
                break;
              }
            } catch (_) {}
          }

          if (!completer.isCompleted) {
            final snap = await controller.runJavaScriptReturningResult("(document.body?.innerText?.slice(0,400)||'')");
            developer.log('[Bedzinn] Timeout. Snap: ${_unwrapJsString(snap)}');
            completer.completeError(TimeoutException('Bedzinn: no cards after submit.'));
          }

        } catch (e, st) {
          developer.log('[Bedzinn] Form fill failed: $e', stackTrace: st);
          if (!completer.isCompleted) completer.completeError(e, st);
        }
      },
      onWebResourceError: (e) {
        developer.log('[Bedzinn] WebResourceError: ${e.errorCode} ${e.description}');
      },
    ));

    await controller.loadRequest(Uri.parse(supplier.authUrl));

    try {
      final results = await completer.future.timeout(const Duration(seconds: 90));
      return BedzinnRawResult(results);
    } on TimeoutException {
      throw TimeoutException('Bedzinn search timed out after 90 seconds.');
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
