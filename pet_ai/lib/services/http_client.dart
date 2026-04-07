import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/io_client.dart';

Future<HttpClient> createHttpClient() async {
  final context = SecurityContext(withTrustedRoots: false);

  final certData =
  await rootBundle.load('assets/certs/russian_trusted_root_ca.pem');

  context.setTrustedCertificatesBytes(certData.buffer.asUint8List());

  final client = HttpClient(context: context);

  return client;
}

Future<IOClient> createIOClient() async {
  final httpClient = await createHttpClient();
  return IOClient(httpClient);
}