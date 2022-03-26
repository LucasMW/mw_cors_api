import 'dart:io';

import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_plus/shelf_plus.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:http/http.dart' as http;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import 'api_cache.dart';
import 'my_request.dart';

const version = "0.8.5 beta";
const identifier = "mwcors_server";

Future<void> runServer(int port, {String? cert, String? key}) async {
  Map<String, APICacheRegistry> getMap = {};
  final liturgyCache = APICache(duration: Duration(hours: 1));
  final trendsCache = APICache(duration: Duration(hours: 1));
  final genericCache = APICache(duration: Duration(minutes: 5));
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
    final result = await getJsonStringCached(trendsUrl, trendsCache);
    return Response.ok(result, headers: {"content-type": "text/json"});
  });

  app.get("/liturgy", (Request request) async {
    final result = await getJsonStringCached(liturgyUrl, liturgyCache);
    return Response.ok(result, headers: {"content-type": "text/json"});
  });

  app.get("/liturgy/<day>/<month>/<year>",
      (Request request, String dayS, String monthS, String yearS) async {
    final day = int.tryParse(dayS);
    final month = int.tryParse(monthS);
    final year = int.tryParse(yearS);
    if (day == null || month == null || year == null) {
      return Response.internalServerError(
          body: "Please use /liturgy/<day>/<month>/<year>");
    }
    final result = await getJsonStringCached(
        liturgyForDayUrl(day, month, year), liturgyCache);
    return Response.ok(result, headers: {"content-type": "text/json"});
  });

  app.get("/liturgicalCalendar/<year>", (Request request, String yearS) async {
    final year = int.tryParse(yearS);
    if (year == null) {
      return Response.internalServerError(
          body: "Please use /liturgicalCalendar/<year>");
    }
    final result =
        await getJsonStringCached(liturgicalCalendarUrl(year), liturgyCache);
    return Response.ok(result, headers: {"content-type": "text/json"});
  });

  app.post('/json', (Request request) async {
    final obj = await request.body.asJson;
    final str = obj.toString();
    final userRequest = ProxyHttpRequest.fromJson(obj);
    if (userRequest.method.toLowerCase() == "get") {
      final result = await getJsonStringCached(userRequest.url, genericCache);
      return Response.ok(result, headers: {"content-type": "text/json"});
    } else if (userRequest.method.toLowerCase() == "post") {
      final result = await postJsonString(userRequest.url, userRequest.body);
      return Response.ok(result, headers: {"content-type": "text/json"});
    }

    return Response.ok("Survived $str");
    //var person = Schedule.fromJson(await request.body.asJson);
    //return 'You send me: ${person.name}';
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
      return Response.ok(resp.body);
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
  if (debug) {
    final server = await io.serve(handler, 'localhost', port);
    print("DEBUG MODE");
  } else {
    final server = await io.serve(handler, InternetAddress.anyIPv4, port,
        securityContext: security);
    final serverDebug = await io.serve(handler, 'localhost', port + 1);
  }

  print('Server created!');
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
    if (arguments.contains("--help")) {
      help();
    }
    if (arguments.contains("--debug")) {
      debug = true;
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
  print("use: --debug for enabling localhost");
  exit(1);
}

final String trendsUrl = "https://trends.gab.com/trend-feed/json";
final String liturgyUrl =
    "http://calapi.inadiutorium.cz/api/v0/en/calendars/default/today";
String liturgyForDayUrl(int day, int month, int year) =>
    "http://calapi.inadiutorium.cz/api/v0/en/calendars/default/$year/$month/$day";
String liturgicalCalendarUrl(int year) =>
    "http://calapi.inadiutorium.cz/api/v0/en/calendars/default/$year";

late bool debug = false;

Future<String> getJsonStringCached(String str, APICache cache) async {
  final response = await cache.get(str);
  return response.body;
}

Future<String> getJsonString(String str) async {
  final url = Uri.parse(str);
  final response = await http.get(url);
  return response.body;
}

Future<String> postJsonString(String str, Object? body) async {
  final url = Uri.parse(str);
  final response = await http.post(url, body: body);
  return response.body;
}
