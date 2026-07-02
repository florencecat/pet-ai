import 'dart:io';
import 'package:http/io_client.dart';

Future<HttpClient> createHttpClient() async {
  final context = SecurityContext(withTrustedRoots: true);
  final client = HttpClient(context: context);
  return client;
}

Future<IOClient> createIOClient() async {
  final httpClient = await createHttpClient();
  return IOClient(httpClient);
}