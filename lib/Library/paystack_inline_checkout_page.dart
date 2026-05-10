import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Loads Paystack Inline (public key) in a WebView — same client-side model as
/// LawhubbAdminPanel `DoctorLibraryPage` (`js.paystack.co` + `PaystackPop`).
///
/// On success, pops with the Paystack transaction reference. On cancel/error, pops null.
String buildPaystackInlineHtml({
  required String publicKey,
  required String email,
  required double amountGhs,
  required String bookTitle,
}) {
  final pk = jsonEncode(publicKey);
  final em = jsonEncode(email);
  final title = jsonEncode(bookTitle);
  final amountPesewas = (amountGhs * 100).round();
  return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <script src="https://js.paystack.co/v1/inline.js"></script>
</head>
<body style="margin:0;background:#111;color:#eee;font-family:system-ui,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;">
  <div style="text-align:center;padding:24px;max-width:360px;">
    <p id="status">Starting checkout…</p>
  </div>
  <script>
    var settled = false;
    function send(msg) {
      try { PaystackBridge.postMessage(msg); } catch (e) {}
    }
    function startPay() {
      if (typeof PaystackPop === 'undefined') {
        document.getElementById('status').innerText = 'Could not load Paystack. Check your connection.';
        send('ERROR:load');
        return;
      }
      var handler = PaystackPop.setup({
        key: $pk,
        email: $em,
        amount: $amountPesewas,
        currency: 'GHS',
        channels: ['mobile_money', 'card'],
        metadata: {
          custom_fields: [
            { display_name: 'Book', variable_name: 'book_title', value: $title }
          ]
        },
        callback: function(response) {
          if (settled) return;
          settled = true;
          send('SUCCESS:' + response.reference);
        },
        onClose: function() {
          if (!settled) send('CLOSED');
        }
      });
      handler.openIframe();
      document.getElementById('status').innerText = 'Complete payment in the window below.';
    }
    window.onload = function() { setTimeout(startPay, 200); };
  </script>
</body>
</html>
''';
}

class PaystackInlineCheckoutPage extends StatefulWidget {
  const PaystackInlineCheckoutPage({
    super.key,
    required this.publicKey,
    required this.email,
    required this.amountGhs,
    required this.bookTitle,
  });

  final String publicKey;
  final String email;
  final double amountGhs;
  final String bookTitle;

  @override
  State<PaystackInlineCheckoutPage> createState() =>
      _PaystackInlineCheckoutPageState();
}

class _PaystackInlineCheckoutPageState extends State<PaystackInlineCheckoutPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _initWebView();
  }

  Future<void> _initWebView() async {
    final html = buildPaystackInlineHtml(
      publicKey: widget.publicKey,
      email: widget.email,
      amountGhs: widget.amountGhs,
      bookTitle: widget.bookTitle,
    );
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.setBackgroundColor(const Color(0xFF111111));
    await _controller.addJavaScriptChannel(
      'PaystackBridge',
      onMessageReceived: (JavaScriptMessage message) {
        final msg = message.message;
        if (msg.startsWith('SUCCESS:')) {
          final reference = msg.substring(8);
          if (mounted) Navigator.pop(context, reference);
        } else if (msg == 'CLOSED') {
          if (mounted) Navigator.pop(context);
        }
      },
    );
    await _controller.loadHtmlString(
      html,
      baseUrl: 'https://checkout.paystack.com',
    );
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }
}
