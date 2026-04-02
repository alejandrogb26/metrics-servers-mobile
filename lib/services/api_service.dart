import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  String baseUrl = 'https://pfc-nginx.alejandrogb.local/metrics-servers/api';
  String? _token;

  late final http.Client _client = _buildClient();

  http.Client _buildClient() {
    final ioHttpClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        debugPrint('Aceptando certificado no verificado de $host:$port');
        debugPrint('Subject: ${cert.subject}');
        debugPrint('Issuer: ${cert.issuer}');
        return true;
      };

    return IOClient(ioHttpClient);
  }

  void setToken(String token) => _token = token;
  void clearToken() => _token = null;

  Map<String, String> get _headers {
    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.acceptHeader: 'application/json',
    };

    if (_token != null) {
      headers[HttpHeaders.authorizationHeader] = 'Bearer $_token';
    }

    return headers;
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);

    try {
      debugPrint('GET -> $uri');
      debugPrint('Headers -> $_headers');

      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));

      debugPrint('Status -> ${response.statusCode}');
      debugPrint('Body -> ${response.body}');

      return _handle(response);
    } on SocketException catch (e) {
      debugPrint('SocketException: $e');
      throw const ApiException(
        statusCode: 0,
        message: 'No se pudo alcanzar el servidor',
      );
    } on HandshakeException catch (e) {
      debugPrint('HandshakeException: $e');
      throw const ApiException(statusCode: 0, message: 'Error SSL/TLS');
    } on TimeoutException catch (e) {
      debugPrint('TimeoutException: $e');
      throw const ApiException(
        statusCode: 0,
        message: 'Tiempo de espera agotado',
      );
    } catch (e) {
      debugPrint('Error inesperado GET: $e');
      throw ApiException(statusCode: 0, message: 'Error inesperado: $e');
    }
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');

    try {
      debugPrint('POST -> $uri');
      debugPrint('Headers -> $_headers');
      debugPrint('Body -> ${jsonEncode(body)}');

      final response = await _client
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      debugPrint('Status -> ${response.statusCode}');
      debugPrint('Body -> ${response.body}');

      return _handle(response);
    } on SocketException catch (e) {
      debugPrint('SocketException: $e');
      throw const ApiException(
        statusCode: 0,
        message: 'No se pudo alcanzar el servidor',
      );
    } on HandshakeException catch (e) {
      debugPrint('HandshakeException: $e');
      throw const ApiException(statusCode: 0, message: 'Error SSL/TLS');
    } on TimeoutException catch (e) {
      debugPrint('TimeoutException: $e');
      throw const ApiException(
        statusCode: 0,
        message: 'Tiempo de espera agotado',
      );
    } catch (e) {
      debugPrint('Error inesperado POST: $e');
      throw ApiException(statusCode: 0, message: 'Error inesperado: $e');
    }
  }

  dynamic _handle(http.Response response) {
    if (response.statusCode == 204) return null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    String message = 'Error ${response.statusCode}';

    try {
      final body = jsonDecode(response.body);
      message = body['message'] ?? body['error'] ?? message;
    } catch (_) {}

    throw ApiException(statusCode: response.statusCode, message: message);
  }
}
