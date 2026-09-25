import '../domain/supplier_adapter.dart';

class SupplierConnectionRepository {
  final List<SupplierAdapter> _adapters;

  SupplierConnectionRepository(this._adapters);

  List<SupplierAdapter> get adapters => _adapters;
  
  SupplierAdapter getAdapter(String supplierId) {
    return _adapters.firstWhere((a) => a.supplier.id == supplierId);
  }
}
