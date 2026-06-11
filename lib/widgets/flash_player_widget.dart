import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../main.dart' show webViewEnvironment;

/// WebView-based Flash player that uses Ruffle (Wasm) to play .swf files.
/// Injects Ruffle from bundled assets into a local HTML page that loads the SWF.
class FlashPlayerWidget extends StatefulWidget {
  final String swfUrl;
  final double? width;
  final double? height;

  const FlashPlayerWidget({
    super.key,
    required this.swfUrl,
    this.width,
    this.height,
  });

  @override
  State<FlashPlayerWidget> createState() => _FlashPlayerWidgetState();
}

class _FlashPlayerWidgetState extends State<FlashPlayerWidget> {
  bool _isLoaded = false;
  bool _hasError = false;
  String _errorMessage = '';

  // Ruffle CDN URL — self-hosted in production assets would be better,
  // but CDN works for now and avoids asset bundling complexity.
  static const String _ruffleCdn = 'https://unpkg.com/@ruffle-rs/ruffle@latest';

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildError();
    }
    return _buildWebView();
  }

  Widget _buildWebView() {
    return InAppWebView(
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        allowsInlineMediaPlayback: true,
        // Disable vertical/horizontal scroll bounce
        disableVerticalScroll: false,
        disableHorizontalScroll: false,
      ),
      // Share the same WebViewEnvironment as login for cookies
      webViewEnvironment: webViewEnvironment,
      onWebViewCreated: (_) {},
      onLoadStart: (controller, url) {
        debugPrint('=== FlashPlayer: loading $url');
      },
      onLoadStop: (controller, url) async {
        if (_isLoaded) return;
        _isLoaded = true;

        // Inject Ruffle after page loads
        await _injectRuffle(controller);
      },
      onConsoleMessage: (controller, message) {
        debugPrint('=== FlashPlayer console: ${message.message}');
      },
      onReceivedError: (controller, request, error) async {
        if (!(request.isForMainFrame ?? false)) return;
        debugPrint('=== FlashPlayer error: ${error.description}');
      },
      onReceivedHttpError: (controller, request, response) async {
        if (!(request.isForMainFrame ?? false)) return;
        final status = response.statusCode ?? 0;
        if (status == 403 || status == 404) {
          setState(() {
            _hasError = true;
            _errorMessage = 'HTTP $status — flash file blocked or not found';
          });
        }
      },
    );
  }

  /// Generate a minimal HTML page with an embedded SWF object,
  /// then load it via loadData (local, no network request for the HTML itself).
  /// Ruffle is injected via script tag from CDN.
  Future<void> _injectRuffle(InAppWebViewController controller) async {
    final swfUrl = widget.swfUrl;

    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background: #1a1a2e; display: flex;
                 justify-content: center; align-items: center; overflow: hidden; }
    #flash-container { width: 100%; height: 100%; display: flex;
                      justify-content: center; align-items: center; }
    #flash-container object, #flash-container embed {
      max-width: 100%; max-height: 100%;
    }
    .loading { color: #888; font-family: sans-serif; font-size: 14px; text-align: center; }
  </style>
</head>
<body>
  <div id="flash-container">
    <p class="loading">Loading Flash player...</p>
  </div>
  <script src="$_ruffleCdn"></script>
  <script>
    window.RufflePlayer = window.RufflePlayer || {};
    window.addEventListener("load", (event) => {
      const ruffle = window.RufflePlayer.newest();
      const player = ruffle.createPlayer();
      const container = document.getElementById("flash-container");
      container.innerHTML = "";
      container.appendChild(player);
      player.load("$swfUrl");
      console.log("Ruffle: loading SWF from $swfUrl");
    });
  </script>
</body>
</html>
''';

    await controller.loadData(
      data: html,
      mimeType: 'text/html',
      encoding: 'utf-8',
    );
  }

  Widget _buildError() {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? 300,
      color: const Color(0xFF12121e),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.flash_off,
              color: Color(0xFF666680),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage.isNotEmpty ? _errorMessage : 'Flash player error',
              style: const TextStyle(
                color: Color(0xFF666680),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
