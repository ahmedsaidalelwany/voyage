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
  const SupplierScreen({super.key});

  Future<void> _connectSupplier(
    BuildContext context,
    SupplierAdapter adapter,
  ) async {
    final cubit = context.read<SupplierConnectionCubit>();
    cubit.updateStatus(adapter.supplier.id, SupplierConnectionStatus.connecting);

    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AuthWebViewRoute(
          adapter: adapter,
          onAuthenticated: () => cubit.markConnected(adapter.supplier.id),
        ),
      ),
    );

    if (!context.mounted) return;

    final current = cubit.state.states[adapter.supplier.id]?.status;
    if (completed == true) return;

    if (current == SupplierConnectionStatus.connecting) {
      cubit.updateStatus(
        adapter.supplier.id,
        SupplierConnectionStatus.disconnected,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final adapters = sl<SupplierConnectionRepository>().adapters;

    return Scaffold(
      appBar: AppBar(title: const Text('Hotel suppliers')),
      body: BlocBuilder<SupplierConnectionCubit, SupplierConnectionState>(
        builder: (context, state) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Connect your authorized supplier accounts once. '
                    'Voyage keeps the WebView session and restores it on the next launch.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: adapters.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final adapter = adapters[index];
                    final status = state.states[adapter.supplier.id]?.status ??
                        SupplierConnectionStatus.disconnected;
                    return Card(
                      child: _buildSupplierTile(context, adapter, status),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: state.canContinue ? () => context.go('/home') : null,
                  child: const Text('Continue to hotel search'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSupplierTile(
    BuildContext context,
    SupplierAdapter adapter,
    SupplierConnectionStatus status,
  ) {
    String statusText;
    Color statusColor;
    Widget action;

    switch (status) {
      case SupplierConnectionStatus.disconnected:
        statusText = 'Not connected';
        statusColor = Colors.grey;
        action = TextButton(
          onPressed: () => _connectSupplier(context, adapter),
          child: const Text('Connect'),
        );
        break;
      case SupplierConnectionStatus.connecting:
        statusText = 'Connecting...';
        statusColor = Theme.of(context).colorScheme.primary;
        action = const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        break;
      case SupplierConnectionStatus.connected:
        statusText = 'Connected';
        statusColor = Colors.green;
        action = TextButton(
          onPressed: () => _connectSupplier(context, adapter),
          child: const Text('Reconnect'),
        );
        break;
      case SupplierConnectionStatus.sessionExpired:
        statusText = 'Session expired';
        statusColor = Colors.orange;
        action = TextButton(
          onPressed: () => _connectSupplier(context, adapter),
          child: const Text('Reconnect'),
        );
        break;
      case SupplierConnectionStatus.error:
        statusText = 'Connection check failed';
        statusColor = Colors.red;
        action = TextButton(
          onPressed: () => _connectSupplier(context, adapter),
          child: const Text('Retry'),
        );
        break;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.hotel_outlined),
      ),
      title: Text(
        adapter.supplier.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        statusText,
        style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
      ),
      trailing: action,
    );
  }
}
