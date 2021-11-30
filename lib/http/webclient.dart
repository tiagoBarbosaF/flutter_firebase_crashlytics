
import 'package:http/http.dart';
import 'package:http_interceptor/http_interceptor.dart';

import 'interceptors/logging_interceptor.dart';



final Client client = InterceptedClient.build(
  interceptors: [LoggingInterceptor()],
  requestTimeout: const Duration(seconds: 5)
);

const String baseUrl = 'http://192.168.0.100:8080/abc';
// const String baseUrl = 'http://192.168.0.100:8080/transactions';

