import 'dart:convert';
import 'dart:io';

import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_plus/shelf_plus.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:http/http.dart' as http;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import 'api_cache.dart';

const version = "0.6.1 beta";
const identifier = "mwcors_server";

Future<void> runServer(int port, {String? cert, String? key}) async {
  Map<String, APICacheRegistry> getMap = {};
  final app = Router();

  app.get('/version', (Request request) {
    return Response.ok(version);
  });

  app.get('/id', (Request request) {
    return Response.ok(identifier);
  });

  app.get('/teapot', (Request request) {
    final body = """ 
        <html> <body> <a href = "https://menezesworks.com"> I am a teapot! </a> </body> </html>
    """;
    print(request.context);
    final x = request.context["shelf.io.connection_info"] as HttpConnectionInfo;
    print(x.remoteAddress.toString());
    x.remoteAddress.reverse().then((v) => print(v));

    return Response(418, body: body, headers: {"content-type": "text/html"});
  });

  app.get("/trends", (Request request) async {
    final result = await getJsonString(trendsUrl);
    return Response.ok(result, headers: {"content-type": "text/json"});
  });

  app.get("/liturgy", (Request request) async {
    final result = await getJsonString(liturgyUrl);
    return Response.ok(result, headers: {"content-type": "text/json"});
  });

  app.get("/getjson/<url>", (Request request, String url) async {
    print(url);
    final uri = Uri.parse("https://$url");
    // return Response.ok(uri.toString());
    final obj = getMap[uri.toString()];
    if (obj == null || cacheTimeout(obj, Duration(minutes: 10))) {
      final result = await getJsonString(uri.toString());
      return Response.ok(result, headers: {"content-type": "text/json"});
    } else {
      print("has resp");
      http.Response resp = obj.response;
      return Response.ok("${resp.body}");
      //return Response(resp.statusCode, body: resp.body, headers: resp.headers);
    }
  });
  final security = SecurityContext.defaultContext;

  final overrideHeaders = {
    ACCESS_CONTROL_ALLOW_ORIGIN: '*',
    'Content-Type': 'application/json;charset=utf-8'
  };

  final handler = Pipeline()
      .addMiddleware(corsHeaders(headers: overrideHeaders))
      .addHandler(app);

  if (cert != null && key != null) {
    security.useCertificateChain(cert);
    security.usePrivateKey(key);
  }

  final server = await io.serve(handler, InternetAddress.anyIPv4, port,
      securityContext: security);
  //final server2 = await io.serve(handler, InternetAddress.anyIPv4, port + 1);

  print('Server created! ${server.serverHeader}');
}

bool cacheTimeout(APICacheRegistry reg, Duration time) {
  return DateTime.now().difference(reg.timestamp) > time;
}

void main(List<String> arguments) {
  const defaultPort = 8080;
  int port = defaultPort;
  String? certificate;
  String? key;
  if (arguments.isNotEmpty) {
    if (arguments[0].contains("--help")) {
      help();
    }
    port = int.tryParse(arguments[0]) ?? defaultPort;
  }
  if (arguments.length >= 3) {
    final certPath = arguments[1];
    final keyPath = arguments[2];

    certificate = certPath;
    key = keyPath;

    runServer(port, cert: certificate, key: key).then((_) {
      print('Server Online https! $port');
    });
  } else {
    runServer(port).then((_) {
      print('Server Online! $port');
    });
  }
}

void help() {
  print("for http:");
  print("\tusage: ./cors_api.exe [port] ");
  print("for https:");
  print("\tusage: ./cors_api.exe [port] [certificate_path] [key_path]");
  exit(1);
}

final String trendsUrl = "https://trends.gab.com/trend-feed/json";
final String liturgyUrl =
    "http://calapi.inadiutorium.cz/api/v0/en/calendars/default/today";

Future<String> getJsonString(String str) async {
  final url = Uri.parse(str);
  final response = await http.get(url);
  return response.body;
}
