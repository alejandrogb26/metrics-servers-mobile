/// auth_service.dart
///
/// Propósito:
///   Servicio de autenticación. Traduce las acciones de login y logout en
///   peticiones HTTP a api-py y devuelve modelos de dominio tipados. Es la
///   única clase que conoce los endpoints `/auth/login` y `/auth/logout`.
///
/// Capa arquitectónica:
///   Capa de servicios (services/). Actúa como adaptador entre [AuthProvider]
///   (capa de estado) y [ApiService] (capa de transporte HTTP).
///
/// Clases definidas en este fichero:
///   - [AuthService]: singleton con los métodos [login] y [logout].
///
/// Patrón singleton:
///   Constructor privado `AuthService._()` + campo estático `instance`.
///   Mismo patrón que [ApiService]: instancia única compartida por toda la app.
///
/// Responsabilidades de [AuthService]:
///   - Llamar a [ApiService.instance.post] con los parámetros correctos.
///   - Deserializar la respuesta de login en [LoginResponse].
///   - Propagar [ApiException] al llamador ([AuthProvider]) sin capturarla.
///
/// Qué NO hace [AuthService] (responsabilidad de [AuthProvider]):
///   - Llamar a [ApiService.setToken] / [ApiService.clearToken].
///   - Registrar o limpiar [ApiService.onUnauthorized].
///   - Persistir la sesión ni actualizar el estado reactivo de la app.
///
/// Qué NO debe contener este fichero:
///   - Lógica de navegación post-login / post-logout.
///   - Gestión de estado (ChangeNotifier, Provider, streams).
///   - Llamadas a otros servicios de dominio.
library;

import 'package:metrics_servers_mobile/models/model_session.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';

/// Servicio de autenticación singleton.
///
/// Responsabilidad:
///   Enviar las credenciales a api-py y deserializar la respuesta en [LoginResponse],
///   o solicitar el cierre de sesión remoto mediante el endpoint de logout.
///
/// Gestión del token:
///   [AuthService] no gestiona el token directamente. Tras un login exitoso,
///   [AuthProvider] extrae el token de [LoginResponse] y lo inyecta en
///   [ApiService] mediante [ApiService.setToken]. [AuthService] no sabe qué
///   hacer con el token: solo devuelve el modelo deserializado.
///
/// Propagación de errores:
///   Tanto [login] como [logout] dejan que [ApiException] se propague al
///   llamador ([AuthProvider]). No hay captura ni transformación de errores en
///   esta capa.
class AuthService {
  AuthService._();

  /// Instancia única compartida por toda la aplicación.
  static final AuthService instance = AuthService._();

  /// Autentica al usuario contra api-py y devuelve la sesión iniciada.
  ///
  /// Realiza un POST a `/auth/login` con las credenciales en texto plano
  /// (la capa de transporte usa HTTPS, por lo que el cuerpo viaja cifrado).
  ///
  /// La respuesta JSON se deserializa en [LoginResponse] mediante
  /// `LoginResponse.fromJson`. El cast `data as Map<String, dynamic>` es
  /// directo y no defensivo: si api-py devolviera un formato inesperado
  /// (no un objeto JSON), se lanzaría un [TypeError] en lugar de [ApiException].
  ///
  /// Throws [ApiException] si [ApiService.post] falla por error de red,
  /// timeout, o código HTTP de error (401 credenciales inválidas, etc.).
  Future<LoginResponse> login(String username, String password) async {
    final data = await ApiService.instance.post('/auth/login', {
      'username': username,
      'password': password,
    });
    return LoginResponse.fromJson(data as Map<String, dynamic>);
  }

  /// Cierra la sesión activa en el servidor.
  ///
  /// Realiza un POST a `/auth/logout` con cuerpo vacío. api-py invalida el
  /// token en el servidor y devuelve 204 No Content; [ApiService._handle]
  /// mapea el 204 a `null`, que este método descarta.
  ///
  /// [AuthProvider] llama a este método con [ApiService.onUnauthorized] ya
  /// puesto a `null` para evitar que una respuesta 401 inesperada del endpoint
  /// de logout dispare una invalidación de sesión redundante.
  ///
  /// Throws [ApiException] si la petición falla. [AuthProvider] debe capturar
  /// este error para no dejar la sesión local en un estado inconsistente.
  Future<void> logout() async {
    await ApiService.instance.post('/auth/logout', {});
  }
}
