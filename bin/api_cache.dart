import 'dart:convert';

import 'package:http/http.dart' as http;

class APICacheRegistry {
  final DateTime timestamp;
  final http.Response response;
  APICacheRegistry(this.timestamp, this.response);
}

class APICache {
  Map<String, APICacheRegistry> getMap = {};
  Map<String, APICacheRegistry> postMap = {};
  Duration duration;
  static const cacheDefaultTime = Duration(minutes: 2);

  APICache({this.duration = cacheDefaultTime});

  Future<http.Response> get(String url, {Map<String, String>? headers}) async {
    final obj = getMap[url];
    if (obj == null || cacheTimeout(obj)) {
      final resp = await http.get(Uri.parse(url), headers: headers);
      getMap[url] = APICacheRegistry(DateTime.now(), resp);
      return resp;
    }
    return obj.response;
  }

  bool cacheTimeout(APICacheRegistry reg) {
    return DateTime.now().difference(reg.timestamp) > duration;
  }

  Future<http.Response> post(String url, String jsonEncodedBody,
      {Map<String, String>? headers}) async {
    final obj = postMap[url + jsonEncodedBody];
    if (obj == null || cacheTimeout(obj)) {
      final decoder = JsonDecoder();
      final body = decoder.convert(jsonEncodedBody);
      final resp =
          await http.post(Uri.parse(url), body: body, headers: headers);
      postMap[url + jsonEncodedBody] = APICacheRegistry(DateTime.now(), resp);
      return resp;
    }
    return obj.response;
  }
}
