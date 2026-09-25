import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../domain/supplier_adapter.dart';
import 'dart:developer' as developer;

class AuthWebViewRoute extends StatefulWidget {
  final SupplierAdapter adapter;
  final Future<void> Function()? onAuthenticated;

  const AuthWebViewRoute({
    super.key,
    required this.adapter,
    this.onAuthenticated,
  });

  @override
  State<AuthWebViewRoute> createState() => _AuthWebViewRouteState();
}

class _AuthWebViewRouteState extends State<AuthWebViewRoute> {
  WebViewController? _controller;
  bool _hasError = false;
  bool _checking = false;
  bool _completionSent = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final urlString = widget.adapter.supplier.authUrl.trim();
    final uri = Uri.tryParse(urlString);

    if (uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Invalid authentication URL for ${widget.adapter.supplier.name}.';
      });
      return;
    }

    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (url) async {
          developer.log('[${widget.adapter.supplier.name}] Auth page finished: $url');
          await _checkAuthentication(url, controller);
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame) {
            developer.log(
              '[${widget.adapter.supplier.name}] Auth error: ${error.errorCode} ${error.description}',
            );
          }
        },
      ),
    );

    if (!mounted) return;
    setState(() => _controller = controller);

    try {
      await controller.loadRequest(uri);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = 'Could not open ${widget.adapter.supplier.name}: $error';
      });
    }
  }

  Future<void> _checkAuthentication(String url, WebViewController controller) async {
    if (_checking || _completionSent) return;
    _checking = true;
    try {
      final authenticated = await widget.adapter.checkAuthSuccess(controller, url);
      if (authenticated) {
        await _completeAuthentication();
      }
    } catch (error) {
      developer.log(
        '[${widget.adapter.supplier.name}] Auth check failed: $error',
      );
    } finally {
      _checking = false;
    }
  }

  Future<void> _completeAuthentication() async {
    if (_completionSent || !mounted) return;
    _completionSent = true;
    if (widget.onAuthenticated != null) {
      await widget.onAuthenticated!();
    }
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _manualComplete() async {
    if (_controller == null || _checking) return;
    await _completeAuthentication();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        appBar: AppBar(title: Text('Connect to ${widget.adapter.supplier.name}')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 56),
                const SizedBox(height: 16),
                Text(_errorMessage, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Connect ${widget.adapter.supplier.name}'),
        actions: [
          IconButton(
            tooltip: 'Done',
            onPressed: _checking ? null : _manualComplete,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: _controller == null
          ? const Center(child: CircularProgressIndicator())
          : WebViewWidget(controller: _controller!),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: _checking ? null : _manualComplete,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Continue to Voyage'),
        ),
      ),
    );
  }
}
