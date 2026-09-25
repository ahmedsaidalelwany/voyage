import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../logic/supplier_connection_cubit.dart';
import '../domain/supplier_connection_status.dart';
import '../domain/supplier_adapter.dart';
import '../data/supplier_connection_repository.dart';
import '../bootstrap.dart';
import 'auth_webview_route.dart';

class SupplierScreen extends StatelessWidget {
  const SupplierScreen({Key? key}) : super(key: key);

  void _connectSupplier(BuildContext context, SupplierAdapter adapter) {
    if (adapter.supplier.authUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No integration available for ${adapter.supplier.name}')),
      );
      return;
    }

    context.read<SupplierConnectionCubit>().updateStatus(adapter.supplier.id, SupplierConnectionStatus.connecting);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AuthWebViewRoute(
          adapter: adapter,
          onAuthenticated: () {
            if (context.mounted) {
              context.read<SupplierConnectionCubit>().updateStatus(adapter.supplier.id, SupplierConnectionStatus.connected);
              Navigator.of(context).pop();
            }
          },
        ),
      ),
    ).then((_) {
      if (!context.mounted) return;
      final state = context.read<SupplierConnectionCubit>().state;
      if (state.states[adapter.supplier.id]?.status == SupplierConnectionStatus.connecting) {
        context.read<SupplierConnectionCubit>().updateStatus(adapter.supplier.id, SupplierConnectionStatus.disconnected);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final adapters = sl<SupplierConnectionRepository>().adapters;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hotel suppliers'),
      ),
      body: BlocBuilder<SupplierConnectionCubit, SupplierConnectionState>(
        builder: (context, state) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Connect your authorized supplier accounts once.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: adapters.length,
                  itemBuilder: (context, index) {
                    final adapter = adapters[index];
                    final statusData = state.states[adapter.supplier.id];
                    final status = statusData?.status ?? SupplierConnectionStatus.disconnected;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                      child: Card(
                        child: _buildSupplierTile(context, adapter, status),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: state.canContinue ? () => context.go('/home') : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Continue', style: TextStyle(fontSize: 18)),
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildSupplierTile(BuildContext context, SupplierAdapter adapter, SupplierConnectionStatus status) {
    String statusText = 'Not connected';
    Widget actionWidget = const Icon(Icons.arrow_forward, color: Colors.grey);
    Color statusColor = Colors.grey;

    switch (status) {
      case SupplierConnectionStatus.disconnected:
        statusText = 'Not connected';
        actionWidget = TextButton(
          onPressed: () => _connectSupplier(context, adapter),
          child: const Text('Connect'),
        );
        break;
      case SupplierConnectionStatus.connecting:
        statusText = 'Connecting...';
        actionWidget = const CircularProgressIndicator();
        statusColor = Colors.blue;
        break;
      case SupplierConnectionStatus.connected:
        statusText = 'Connected';
        actionWidget = const Icon(Icons.check, color: Colors.green);
        statusColor = Colors.green;
        break;
      case SupplierConnectionStatus.sessionExpired:
        statusText = 'Session expired';
        statusColor = Colors.orange;
        actionWidget = TextButton(
          onPressed: () => _connectSupplier(context, adapter),
          child: const Text('Reconnect'),
        );
        break;
      case SupplierConnectionStatus.error:
        statusText = 'Error';
        statusColor = Colors.red;
        actionWidget = TextButton(
          onPressed: () => _connectSupplier(context, adapter),
          child: const Text('Retry'),
        );
        break;
    }

    return ListTile(
      title: Text(adapter.supplier.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
        statusText,
        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
      ),
      trailing: actionWidget,
    );
  }
}
