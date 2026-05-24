import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_colors.dart';

class KakaoPostcodeResult {
  final String roadAddress;
  final String jibunAddress;
  final String zonecode;
  final String buildingName;

  const KakaoPostcodeResult({
    required this.roadAddress,
    required this.jibunAddress,
    required this.zonecode,
    required this.buildingName,
  });

  factory KakaoPostcodeResult.fromJson(Map<String, dynamic> json) =>
      KakaoPostcodeResult(
        roadAddress:  (json['roadAddress']  as String?) ?? '',
        jibunAddress: (json['jibunAddress'] as String?) ?? '',
        zonecode:     (json['zonecode']     as String?) ?? '',
        buildingName: (json['buildingName'] as String?) ?? '',
      );
}

class KakaoPostcodePage extends StatefulWidget {
  const KakaoPostcodePage({super.key});

  @override
  State<KakaoPostcodePage> createState() => _KakaoPostcodePageState();
}

class _KakaoPostcodePageState extends State<KakaoPostcodePage> {
  late final WebViewController _controller;
  bool _loading = true;

  static const _html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; overflow: hidden; }
  </style>
</head>
<body>
<script src="https://t1.daumcdn.net/mapjsapi/bundle/postcode/prod/postcode.v2.js"></script>
<script>
  new daum.Postcode({
    oncomplete: function(data) {
      var payload = encodeURIComponent(JSON.stringify({
        roadAddress:  data.roadAddress,
        jibunAddress: data.jibunAddress,
        zonecode:     data.zonecode,
        buildingName: data.buildingName || ""
      }));
      window.location.href = 'ruttu://address?data=' + payload;
    },
    width:  "100%",
    height: "100%"
  }).embed(document.body);
</script>
</body>
</html>
''';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _loading = false),
        onNavigationRequest: (request) {
          final url = request.url;
          if (url.startsWith('ruttu://address')) {
            final uri = Uri.parse(url);
            final dataStr = uri.queryParameters['data'];
            if (dataStr != null && mounted) {
              final data = jsonDecode(dataStr) as Map<String, dynamic>;
              Navigator.of(context).pop(KakaoPostcodeResult.fromJson(data));
            }
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadHtmlString(_html, baseUrl: 'https://ruttu.app');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('주소 검색',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        leading: const CloseButton(),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 12),
                  Text('주소 검색을 불러오는 중...',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
