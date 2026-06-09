/// api_service.dart
///
/// Propósito:
///   Cliente HTTP singleton de la aplicación. Centraliza todas las peticiones
///   a api-py: gestión del token Bearer, cabeceras comunes, timeout, logging
///   en modo debug, manejo de errores de red y protocolo, y notificación
///   automática de sesión expirada (401).
///
/// Capa arquitectónica:
///   Capa de servicios (services/). Es la única clase que realiza peticiones
///   HTTP en la aplicación. Los servicios de dominio (AuthService, ServidorService,
///   etc.) lo usan como capa de transporte sin conocer los detalles del cliente HTTP.
///
/// Clases definidas en este fichero:
///   - [ApiException]: excepción tipada para errores HTTP y de red.
///   - [ApiService]:   singleton con los métodos [get] y [post].
///
/// Patrón singleton:
///   Constructor privado `ApiService._()` + campo estático `instance`. Una sola
///   instancia compartida por toda la app: el cliente HTTP ([_client]) y el token
///   se mantienen en un único objeto durante toda la sesión.
///
/// Bypass de certificado SSL:
///   El entorno de despliegue usa nginx con un certificado autofirmado
///   (`pfc-nginx.alejandrogb.local`). El cliente se construye con
///   `badCertificateCallback` que siempre devuelve `true`, aceptando cualquier
///   certificado. En modo debug se registra el subject e issuer del certificado.
///   ADVERTENCIA: en producción este comportamiento aceptaría certificados
///   fraudulentos; debe restringirse o eliminarse antes de desplegar en entornos
///   con certificados CA válidos.
///
/// Mecanismo de invalidación de sesión (401):
///   [onUnauthorized] es un callback `void Function()?` que [AuthProvider] registra
///   tras el login y elimina antes del logout. Cuando [_handle] recibe un 401,
///   llama a este callback antes de lanzar la excepción. Esto desacopla la lógica
///   de sesión: los servicios de dominio no necesitan saber qué hacer en un 401;
///   [ApiService] notifica a [AuthProvider] y la excepción se propaga normalmente.
///
/// Convención de statusCode en ApiException:
///   - `statusCode > 0`: código HTTP real devuelto por api-py (400, 401, 404...).
///   - `statusCode == 0`: error de transporte sin respuesta HTTP ([SocketException],
///     [HandshakeException], [TimeoutException] u otro error inesperado).
///
/// Qué NO debe contener este fichero:
///   - Lógica de negocio ni interpretación del contenido de las respuestas.
///   - Serialización/deserialización de modelos de dominio (pertenece a los modelos).
///   - Lógica de reintento automático.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Excepción tipada para cualquier error originado en [ApiService].
///
/// [statusCode] permite al llamador distinguir la causa del error:
///   - `0`  → error de transporte (sin respuesta HTTP).
///   - `401` → sesión expirada o credenciales inválidas.
///   - `4xx` → error del cliente (bad request, not found, etc.).
///   - `5xx` → error del servidor.
class ApiException implements Exception {
  /// Código de estado HTTP, o `0` para errores de transporte.
  final int statusCode;

  /// Mensaje legible extraído del cuerpo de la respuesta o generado localmente.
  final String message;

  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Cliente HTTP singleton de la aplicación.
///
/// Responsabilidad:
///   Realizar peticiones GET y POST a api-py con autenticación Bearer,
///   cabeceras JSON, timeout de 15 segundos y manejo centralizado de errores.
///
/// Ciclo de vida del token:
///   [AuthProvider] llama a [setToken] después de un login exitoso y a
///   [clearToken] durante el logout. El token se almacena en memoria; no hay
///   persistencia entre sesiones de la app.
///
/// Callback [onUnauthorized]:
///   [AuthProvider] registra `_invalidateSession` como [onUnauthorized] justo
///   después del login. Lo elimina (pone a `null`) al inicio del logout, antes
///   de llamar al endpoint de logout de api-py. Este orden evita que una respuesta
///   401 del endpoint de logout dispare una invalidación de sesión redundante.
class ApiService {
  ApiService._();

  /// Instancia única compartida por toda la aplicación.
  static final ApiService instance = ApiService._();

  /// URL base de api-py. Puede modificarse en tiempo de ejecución si fuera
  /// necesario cambiar el entorno, aunque en la práctica es constante.
  String baseUrl = 'https://pfc-nginx.alejandrogb.local';

  /// Token Bearer de la sesión activa. `null` si el usuario no está autenticado.
  String? _token;

  /// Cliente HTTP subyacente. `late final`: se inicializa una vez al primer
  /// acceso y no se reasigna. Reutilizar el cliente permite que la capa HTTP
  /// mantenga conexiones persistentes (keep-alive).
  late final http.Client _client = _buildClient();

  /// Construye el cliente HTTP con bypass de verificación de certificado SSL.
  ///
  /// El entorno de despliegue usa un certificado autofirmado. El callback
  /// `badCertificateCallback` devuelve `true` para cualquier certificado,
  /// desactivando la verificación de la cadena de confianza.
  /// Solo se registra información del certificado en modo debug.
  ///
  /// ADVERTENCIA: este comportamiento no es seguro en producción con CA pública.
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

  /// Almacena el token Bearer para incluirlo en las peticiones autenticadas.
  /// Llamado por [AuthProvider] tras un login exitoso.
  void setToken(String token) => _token = token;

  /// Elimina el token Bearer. Las peticiones posteriores se enviarán sin
  /// cabecera Authorization. Llamado por [AuthProvider] durante el logout.
  void clearToken() => _token = null;

  /// Callback invocado exactamente una vez cuando [_handle] recibe un 401.
  ///
  /// [AuthProvider] lo registra como `_invalidateSession` tras el login y
  /// lo pone a `null` antes del logout. El callback se llama antes de que
  /// [_handle] lance [ApiException], de modo que la sesión queda invalidada
  /// antes de que la excepción se propague al llamador.
  void Function()? onUnauthorized;

  /// Cabeceras comunes a todas las peticiones.
  ///
  /// Siempre incluye `Content-Type: application/json` y `Accept: application/json`.
  /// Añade `Authorization: Bearer {token}` solo si [_token] no es `null`.
  /// Devuelve un nuevo mapa en cada llamada (no se cachea).
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

  /// Realiza una petición GET a `baseUrl + path` con parámetros de query opcionales.
  ///
  /// Timeout: 15 segundos desde el envío de la petición.
  ///
  /// En modo debug ([kDebugMode]) registra la URL completa, cabeceras,
  /// código de estado y cuerpo de la respuesta mediante [debugPrint].
  ///
  /// Errores de transporte (sin código HTTP):
  ///   - [SocketException]: sin conectividad o host no alcanzable.
  ///   - [HandshakeException]: fallo en el handshake SSL/TLS.
  ///   - [TimeoutException]: la petición superó los 15 segundos.
  ///   - Cualquier otro error: capturado y envuelto en [ApiException].
  ///
  /// Todos los errores de transporte se convierten en `ApiException(statusCode: 0)`.
  ///
  /// Throws [ApiException] en cualquier error (de transporte o HTTP ≥ 400).
  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);

    try {
      if (kDebugMode) {
        debugPrint('GET -> $uri');
        debugPrint('Headers -> $_headers');
      }

      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        debugPrint('Status -> ${response.statusCode}');
        debugPrint('Body -> ${response.body}');
      }

      return _handle(response);
    } on SocketException catch (e) {
      if (kDebugMode) debugPrint('SocketException: $e');
      throw const ApiException(
        statusCode: 0,
        message: 'No se pudo alcanzar el servidor',
      );
    } on HandshakeException catch (e) {
      if (kDebugMode) debugPrint('HandshakeException: $e');
      throw const ApiException(statusCode: 0, message: 'Error SSL/TLS');
    } on TimeoutException catch (e) {
      if (kDebugMode) debugPrint('TimeoutException: $e');
      throw const ApiException(
        statusCode: 0,
        message: 'Tiempo de espera agotado',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error inesperado GET: $e');
      throw ApiException(statusCode: 0, message: 'Error inesperado: $e');
    }
  }

  /// Realiza una petición POST a `baseUrl + path` con [body] serializado como JSON.
  ///
  /// El cuerpo se serializa con [jsonEncode] antes de enviarse.
  /// Comparte timeout y manejo de errores con [get].
  ///
  /// Throws [ApiException] en cualquier error (de transporte o HTTP ≥ 400).
  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');

    try {
      if (kDebugMode) {
        debugPrint('POST -> $uri');
        debugPrint('Headers -> $_headers');
        debugPrint('Body -> ${jsonEncode(body)}');
      }

      final response = await _client
          .post(uri, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        debugPrint('Status -> ${response.statusCode}');
        debugPrint('Body -> ${response.body}');
      }

      return _handle(response);
    } on SocketException catch (e) {
      if (kDebugMode) debugPrint('SocketException: $e');
      throw const ApiException(
        statusCode: 0,
        message: 'No se pudo alcanzar el servidor',
      );
    } on HandshakeException catch (e) {
      if (kDebugMode) debugPrint('HandshakeException: $e');
      throw const ApiException(statusCode: 0, message: 'Error SSL/TLS');
    } on TimeoutException catch (e) {
      if (kDebugMode) debugPrint('TimeoutException: $e');
      throw const ApiException(
        statusCode: 0,
        message: 'Tiempo de espera agotado',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error inesperado POST: $e');
      throw ApiException(statusCode: 0, message: 'Error inesperado: $e');
    }
  }

  /// Interpreta la respuesta HTTP y devuelve el cuerpo decodificado o lanza
  /// [ApiException].
  ///
  /// Respuestas exitosas (2xx):
  ///   - 204 No Content → `null` (sin cuerpo por diseño).
  ///   - Cuerpo vacío   → `null`.
  ///   - Con cuerpo     → `dynamic` resultado de [jsonDecode].
  ///
  /// Respuestas de error (fuera de 2xx):
  ///   Intenta extraer el mensaje de error del cuerpo JSON buscando en orden
  ///   los campos `message`, `detail` y `error` (los tres formatos que puede
  ///   devolver api-py según el tipo de error). Si el cuerpo no es JSON válido
  ///   o no contiene ninguno de esos campos, usa `'Error {statusCode}'`.
  ///
  ///   Para el código 401 específicamente, invoca [onUnauthorized] ANTES de
  ///   lanzar la excepción: así la sesión se invalida antes de que el finally
  ///   del llamador (p. ej. [MetricsProvider]) se ejecute.
  dynamic _handle(http.Response response) {
    if (response.statusCode == 204) return null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    String message = 'Error ${response.statusCode}';

    try {
      final body = jsonDecode(response.body);
      // api-py usa 'message' en errores de negocio, 'detail' en errores FastAPI
      // y 'error' en algunos casos de autenticación.
      message = body['message'] ?? body['detail'] ?? body['error'] ?? message;
    } catch (_) {
      // Cuerpo no JSON (p. ej. HTML de nginx ante error 502): se usa el fallback.
    }

    if (response.statusCode == 401) {
      // Notificar antes de lanzar: AuthProvider limpia la sesión y el provider
      // de métricas puede leer el estado ya invalidado en su bloque finally.
      onUnauthorized?.call();
    }

    throw ApiException(statusCode: response.statusCode, message: message);
  }
}
