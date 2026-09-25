import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/supplier_connection_status.dart';
import '../data/supplier_connection_repository.dart';

class SupplierStateData {
  final String supplierId;
  final SupplierConnectionStatus status;

  SupplierStateData({required this.supplierId, required this.status});
  
  SupplierStateData copyWith({SupplierConnectionStatus? status}) {
    return SupplierStateData(
      supplierId: supplierId,
      status: status ?? this.status,
    );
  }
}

class SupplierConnectionState {
  final Map<String, SupplierStateData> states;

  SupplierConnectionState(this.states);
  
  bool get canContinue => states.values.any((s) => s.status == SupplierConnectionStatus.connected);

  SupplierConnectionState copyWith(Map<String, SupplierStateData> newStates) {
    return SupplierConnectionState({...states, ...newStates});
  }
}

class SupplierConnectionCubit extends Cubit<SupplierConnectionState> {
  final SupplierConnectionRepository _repository;

  SupplierConnectionCubit(this._repository) : super(SupplierConnectionState({})) {
    _init();
  }

  void _init() {
    final Map<String, SupplierStateData> initialStates = {};
    for (var adapter in _repository.adapters) {
      initialStates[adapter.supplier.id] = SupplierStateData(
        supplierId: adapter.supplier.id,
        status: SupplierConnectionStatus.disconnected,
      );
    }
    emit(SupplierConnectionState(initialStates));
    
    // Check initial auth
    for (var adapter in _repository.adapters) {
      _checkInitialAuth(adapter.supplier.id);
    }
  }

  Future<void> _checkInitialAuth(String supplierId) async {
    updateStatus(supplierId, SupplierConnectionStatus.connecting);
    final adapter = _repository.getAdapter(supplierId);
    
    try {
      bool isAuthed = await adapter.isAuthenticated();
      updateStatus(supplierId, isAuthed ? SupplierConnectionStatus.connected : SupplierConnectionStatus.disconnected);
    } catch (e) {
      updateStatus(supplierId, SupplierConnectionStatus.error);
    }
  }

  void updateStatus(String supplierId, SupplierConnectionStatus status) {
    if (!state.states.containsKey(supplierId)) return;
    
    final updatedData = state.states[supplierId]!.copyWith(status: status);
    emit(state.copyWith({supplierId: updatedData}));
  }

  Future<void> disconnect(String supplierId) async {
    updateStatus(supplierId, SupplierConnectionStatus.disconnected);
    await _repository.getAdapter(supplierId).disconnect();
  }
}
