import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../domain/supplier_adapter.dart';
import 'dart:developer' as developer;

class AuthWebViewRoute extends StatefulWidget {
  final SupplierAdapter adapter;
  final VoidCallback onAuthenticated;

  const AuthWebViewRoute({
    Key? key,
    required this.adapter,
    required this.onAuthenticated,
  }) : super(key: key);

  @override
  State<AuthWebViewRoute> createState() => _AuthWebViewRouteState();
}

class _AuthWebViewRouteState extends State<AuthWebViewRoute> {
  late final WebViewController _controller;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    final urlString = widget.adapter.supplier.authUrl;
    
    if (urlString.isEmpty || (!urlString.startsWith('http://') && !urlString.startsWith('https://'))) {
      _hasError = true;
      _errorMessage = 'Invalid authentication URL provided for ${widget.adapter.supplier.name}.';
      developer.log('[${widget.adapter.supplier.name}] Error: Invalid URL: $urlString');
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) async {
            developer.log('[${widget.adapter.supplier.name}] Auth WebView Page finished: $url');
            bool isSuccess = await widget.adapter.checkAuthSuccess(_controller, url);
            if (isSuccess && mounted) {
              widget.onAuthenticated();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(urlString));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Connect to ${widget.adapter.supplier.name}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _hasError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            )
          : WebViewWidget(controller: _controller),
    );
  }
}
