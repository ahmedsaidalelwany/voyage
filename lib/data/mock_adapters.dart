import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:webview_flutter/webview_flutter.dart';
import '../domain/raw_supplier_search_result.dart';
import '../domain/search_criteria.dart';
import '../domain/supplier_adapter.dart';
import '../domain/supplier_identity.dart';

class PortalRawResult extends RawSupplierSearchResult {
  final List<Map<String, dynamic>> hotels;
  PortalRawResult(super.supplierId, this.hotels);
}

abstract class PortalSupplierAdapter implements SupplierAdapter {
  @override
  Future<bool> isAuthenticated() async {
    final c = WebViewController();
    await c.setJavaScriptMode(JavaScriptMode.unrestricted);
    final done = Completer<bool>();
    var finished = false;
    void finish(bool value) { if (finished || done.isCompleted) return; finished = true; done.complete(value); }
    await c.setNavigationDelegate(NavigationDelegate(
      onPageFinished: (url) async { try { finish(await checkAuthSuccess(c, url)); } catch (_) { finish(false); } },
      onWebResourceError: (e) { if (e.isForMainFrame) finish(false); },
    ));
    try { await c.loadRequest(Uri.parse(supplier.authUrl)); return await done.future.timeout(const Duration(seconds: 12), onTimeout: () => false); }
    catch (_) { return false; }
  }

  @override
  Future<bool> checkAuthSuccess(WebViewController c, String url) async {
    try {
      final raw = await c.runJavaScriptReturningResult(r'''(function(){
        const t=document.body?document.body.innerText:'';
        const p=Array.from(document.querySelectorAll('input')).some(e=>(e.type||'').toLowerCase()==='password');
        const login=/\\b(login|sign in|log in)\\b|تسجيل الدخول|دخول/i.test(t);
        const account=/\\b(logout|sign out|log out|dashboard|account|profile|bookings)\\b|تسجيل خروج|حسابي|الحجوزات/i.test(t);
        return JSON.stringify({p:p,login:login,account:account});
      })();''');
      final v=jsonDecode(_unwrap(raw)) as Map<String,dynamic>;
      return v['account']==true && v['p']!=true && v['login']!=true;
    } catch (_) { return false; }
  }

  @override
  Future<void> disconnect() async { await WebViewCookieManager().clearCookies(); }

  @override
  Future<RawSupplierSearchResult> search(SearchCriteria criteria) async {
    final c=WebViewController();
    await c.setJavaScriptMode(JavaScriptMode.unrestricted);
    final done=Completer<List<Map<String,dynamic>>>();
    var submitted=false;
    Future<void> extract() async {
      if(done.isCompleted) return;
      final raw=await c.runJavaScriptReturningResult(r'''(function(){
        const ss=['[data-hotel-id]','[data-property-id]','article','.hotel-card','.hotel-item','.property-card','.result-card','[class*="hotel-card"]','[class*="hotel-item"]','[class*="property-card"]','[class*="result-card"]','[class*="hotel-list"]','[class*="hotel_list"]'];
        let cards=[]; ss.forEach(s=>{const a=Array.from(document.querySelectorAll(s));if(a.length>cards.length)cards=a;});
        return JSON.stringify(cards.map(card=>{const text=card.innerText||'';const title=card.querySelector('[data-hotel-name],h2,h3,h4,.hotel-name,.hotel-title,[class*="hotel-name"],[class*="property-name"]')?.innerText?.trim()||'';const pt=card.querySelector('.price,.amount,.hotel-price,[class*="price"],[class*="amount"]')?.innerText?.trim()||'';const n=pt.replace(/,/g,'').match(/\\d+(?:\\.\\d+)?/);const cur=pt.match(/\\b(AED|USD|EUR|GBP|EGP|SAR|QAR|KWD|BHD|OMR)\\b/i);const id=card.getAttribute('data-hotel-id')||card.getAttribute('data-property-id')||'';const img=card.querySelector('img')?.currentSrc||card.querySelector('img')?.src||'';return {name:title,price:n?Number(n[0]):null,currency:cur?cur[1].toUpperCase():null,images:img?[img]:[],supplierHotelId:id||null,rawText:text.slice(0,3000)};}).filter(x=>x.name));
      })();''');
      final v=jsonDecode(_unwrap(raw));
      if(v is List && v.isNotEmpty) done.complete(v.whereType<Map>().map(Map<String,dynamic>.from).toList());
    }
    String pad(int n)=>n.toString().padLeft(2,'0');
    final ci=criteria.checkIn; final co=criteria.checkOut;
    final payload=jsonEncode({'destination':criteria.destination.name,'cityCode':criteria.destination.cityCode,'checkIn':ci.year.toString()+'-'+pad(ci.month)+'-'+pad(ci.day),'checkOut':co.year.toString()+'-'+pad(co.month)+'-'+pad(co.day),'currency':criteria.currency,'hotelName':criteria.hotelName,'rooms':criteria.rooms.map((r)=>{'adults':r.adults,'childrenAges':r.childrenAges}).toList(),'minimumStars':criteria.minimumStars,'maximumPrice':criteria.maximumPrice,'mealPlan':criteria.mealPlan,'cancellation':criteria.cancellationPreference});
    await c.setNavigationDelegate(NavigationDelegate(
      onPageFinished:(url) async {
        developer.log('['+supplier.name+'] page finished: '+url);
        if(!submitted){submitted=true;try{final raw=await c.runJavaScriptReturningResult("""
          (function(){const c=$payload;function setV(e,v){if(!e)return false;const p=e.tagName==='SELECT'?HTMLSelectElement.prototype:HTMLInputElement.prototype;const s=Object.getOwnPropertyDescriptor(p,'value')?.set;if(s)s.call(e,v);else e.value=v;e.dispatchEvent(new Event('input',{bubbles:true}));e.dispatchEvent(new Event('change',{bubbles:true}));return true;}function field(k){return Array.from(document.querySelectorAll('input,select,textarea')).find(e=>k.some(x=>[e.id,e.name,e.placeholder,e.getAttribute('aria-label')].filter(Boolean).join(' ').toLowerCase().includes(x)));}setV(field(['destination','city','location','place']),c.destination);setV(field(['check-in','checkin','arrival','from']),c.checkIn);setV(field(['check-out','checkout','departure','to']),c.checkOut);setV(field(['currency','عملة']),c.currency);if(c.hotelName)setV(field(['hotel name','hotel']),c.hotelName);const b=Array.from(document.querySelectorAll('button,input[type=submit],a')).find(e=>/search|find hotels|search hotels|بحث|بحث عن/i.test((e.innerText||e.value||'').trim()));if(b){b.click();return 'clicked-search';}const f=document.querySelector('form');if(f){f.requestSubmit?f.requestSubmit():f.submit();return 'submitted-form';}return 'no-search-control';})()
        """);developer.log('['+supplier.name+'] submit: '+_unwrap(raw));}catch(e){if(!done.isCompleted)done.completeError(e);}}
        await Future<void>.delayed(const Duration(seconds:2));try{await extract();}catch(_){}}
      ,onWebResourceError:(e){if(e.isForMainFrame&&!done.isCompleted)done.completeError(StateError(supplier.name+': '+e.description));}
    ));
    await c.loadRequest(Uri.parse(supplier.authUrl));
    for(var i=0;i<30&&!done.isCompleted;i++){await Future<void>.delayed(const Duration(seconds:2));try{await extract();}catch(_){}}
    if(!done.isCompleted)throw TimeoutException(supplier.name+': no hotel results detected.');
    return PortalRawResult(supplier.id,await done.future);
  }

  String _unwrap(Object value){final t=value.toString();if(t.startsWith('"')&&t.endsWith('"')){try{final d=jsonDecode(t);if(d is String)return d;}catch(_){}}return t;}
}

class TripovoAdapter extends PortalSupplierAdapter { @override SupplierIdentity get supplier=>const SupplierIdentity(id:'tripovo',name:'Tripovo Agents',authUrl:'https://agents.tripovo.com/login?returnTo=%2Fhome%3Fproduct%3Dhotel'); }
class EliteBookingsAdapter extends PortalSupplierAdapter { @override SupplierIdentity get supplier=>const SupplierIdentity(id:'elite',name:'Elite Bookings',authUrl:'https://www.elite-bookings.com/ar/idea/64073179/755223/-'); }
class MustasharAdapter extends PortalSupplierAdapter { @override SupplierIdentity get supplier=>const SupplierIdentity(id:'mustashar',name:'Mustashar Holidays',authUrl:'https://www.mustasharholidays.com/index.php'); }
