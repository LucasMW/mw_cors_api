enum Method { get, post, patch, delete }

class ProxyHttpRequest {
  ProxyHttpRequest({
    required this.method,
    required this.url,
    required this.body,
    required this.headers,
  });
  late final String method;
  late final String url;
  late final Map<String, dynamic> body;
  late final Map<String, String> headers;

  ProxyHttpRequest.fromJson(Map<String, dynamic> json) {
    method = json['method'];
    url = json['url'];
    body = json['body'] ?? {};
    headers = json['headers'] ?? {};
  }

  Map<String, dynamic> toJson() {
    final _data = <String, dynamic>{};
    _data['method'] = method;
    _data['url'] = url;
    _data['body'] = body;
    _data['headers'] = headers;
    return _data;
  }
}
