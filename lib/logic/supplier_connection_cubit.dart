import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  bool get canContinue =>
      states.values.any((s) => s.status == SupplierConnectionStatus.connected);

  SupplierConnectionState copyWith(Map<String, SupplierStateData> newStates) {
    return SupplierConnectionState({...states, ...newStates});
  }
}

class SupplierConnectionCubit extends Cubit<SupplierConnectionState> {
  static const _connectedPrefix = 'supplier.connected.';
  final SupplierConnectionRepository _repository;
  final Future<SharedPreferences> _preferences;

  SupplierConnectionCubit(this._repository)
      : _preferences = SharedPreferences.getInstance(),
        super(SupplierConnectionState({})) {
    _init();
  }

  Future<void> _init() async {
    final initialStates = <String, SupplierStateData>{
      for (final adapter in _repository.adapters)
        adapter.supplier.id: SupplierStateData(
          supplierId: adapter.supplier.id,
          status: SupplierConnectionStatus.disconnected,
        ),
    };
    emit(SupplierConnectionState(initialStates));

    final prefs = await _preferences;

    for (final adapter in _repository.adapters) {
      final id = adapter.supplier.id;
      if (prefs.getBool('$_connectedPrefix$id') != true) {
        continue;
      }
      await _checkInitialAuth(adapter.supplier.id);
    }
  }

  Future<void> _checkInitialAuth(String supplierId) async {
    updateStatus(supplierId, SupplierConnectionStatus.connecting);
    final adapter = _repository.getAdapter(supplierId);

    try {
      final isAuthed = await adapter.isAuthenticated();
      if (isAuthed) {
        await _setPersistedConnected(supplierId, true);
        updateStatus(supplierId, SupplierConnectionStatus.connected);
      } else {
        await _setPersistedConnected(supplierId, false);
        updateStatus(supplierId, SupplierConnectionStatus.sessionExpired);
      }
    } catch (_) {
      updateStatus(supplierId, SupplierConnectionStatus.error);
    }
  }

  Future<void> markConnected(String supplierId) async {
    await _setPersistedConnected(supplierId, true);
    updateStatus(supplierId, SupplierConnectionStatus.connected);
  }

  Future<void> markDisconnected(String supplierId) async {
    await _setPersistedConnected(supplierId, false);
    updateStatus(supplierId, SupplierConnectionStatus.disconnected);
  }

  Future<void> _setPersistedConnected(String supplierId, bool value) async {
    final prefs = await _preferences;
    await prefs.setBool('$_connectedPrefix$supplierId', value);
  }

  void updateStatus(String supplierId, SupplierConnectionStatus status) {
    if (!state.states.containsKey(supplierId)) return;
    final updatedData = state.states[supplierId]!.copyWith(status: status);
    emit(state.copyWith({supplierId: updatedData}));
  }

  Future<void> disconnect(String supplierId) async {
    await _setPersistedConnected(supplierId, false);
    updateStatus(supplierId, SupplierConnectionStatus.disconnected);
    await _repository.getAdapter(supplierId).disconnect();
  }
}
