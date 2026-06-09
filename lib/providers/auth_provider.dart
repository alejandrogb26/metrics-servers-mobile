/// auth_provider.dart
///
/// Propósito:
///   Define [AuthProvider], el provider central de autenticación y sesión de
///   Metrics Manager. Gestiona el ciclo de vida completo de la autenticación:
///   login, logout, invalidación automática de sesión por token expirado y
///   exposición del estado de autenticación y permisos al árbol de widgets.
///
/// Capa arquitectónica:
///   Capa de presentación — providers (providers/).
///   Se sitúa entre la capa de servicios (AuthService, ApiService) y la capa
///   de UI (screens). No contiene lógica HTTP directa; delega en los servicios.
///
/// Responsabilidades principales:
///   - Orquestar el flujo de login: invocar AuthService, almacenar el token en
///     ApiService, registrar el callback de invalidación por 401 y actualizar
///     el estado.
///   - Orquestar el logout: revocar el callback de 401, solicitar el logout al
///     servidor (best-effort) y limpiar el estado local.
///   - Manejar la invalidación automática de sesión cuando ApiService recibe un
///     401 en cualquier petición (token expirado o revocado).
///   - Exponer a la UI el estado de autenticación ([AuthStatus]), los datos de
///     sesión ([Session]) y los métodos de comprobación de acceso.
///
/// Mecanismo de invalidación automática por 401:
///   Tras el login, [AuthProvider] registra [_invalidateSession] como callback
///   en `ApiService.instance.onUnauthorized`. Cuando cualquier petición HTTP
///   de la app recibe una respuesta 401, ApiService invoca ese callback, lo que
///   resetea la sesión local y lleva la app de vuelta al estado [AuthStatus.initial].
///   La pantalla de login detecta este cambio de estado y redirige al usuario.
///   Este callback se elimina explícitamente antes de cualquier operación que
///   pudiera generar un 401 propio (logout, invalidación), evitando re-entradas.
///
/// Persistencia de sesión:
///   Esta implementación es stateless entre reinicios de la app: el token se
///   almacena únicamente en memoria (ApiService). Cada arranque en frío requiere
///   que el usuario se autentique de nuevo. No se usa flutter_secure_storage ni
///   ningún mecanismo de persistencia de token.
///
/// Qué NO debe contener este fichero:
///   - Llamadas HTTP directas (eso pertenece a AuthService / ApiService).
///   - Lógica de navegación (eso pertenece a las screens o a un NavigationProvider).
///   - Lógica de refresco de token (no implementado; los 401 fuerzan re-login).
///   - Persistencia de credenciales o tokens en disco.
library;

import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/models/model_session.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';
import 'package:metrics_servers_mobile/services/auth_service.dart';

/// Estados posibles del ciclo de vida de la autenticación.
///
/// Usado por [AuthProvider] para comunicar a la UI en qué fase se encuentra
/// el proceso de autenticación, de forma que cada pantalla pueda reaccionar
/// mostrando el estado adecuado (spinner, error, contenido).
///
///   - [initial]:       estado de partida — no autenticado, sin intento previo.
///                      También es el estado tras un logout o una invalidación.
///   - [loading]:       petición de login en curso; la UI debe mostrar spinner.
///   - [authenticated]: login exitoso; la sesión está activa y [Session] disponible.
///   - [error]:         login fallido; [AuthProvider.errorMessage] contiene el motivo.
enum AuthStatus { initial, loading, authenticated, error }

/// Provider de autenticación y sesión de Metrics Manager.
///
/// Responsabilidad:
///   Gestiona el estado de autenticación de la app mediante el patrón
///   [ChangeNotifier]. Es el único punto de acceso de la UI a los datos de
///   sesión y a las comprobaciones de permisos de alto nivel.
///
/// Ciclo de vida del estado:
///   ```
///   initial  →  loading  →  authenticated   (login exitoso)
///                        →  error            (login fallido)
///   authenticated  →  initial               (logout o 401 en cualquier petición)
///   error          →  loading               (reintento de login)
///   ```
///
/// Acceso a servicios:
///   Usa los singletons `AuthService.instance` y `ApiService.instance` en lugar
///   de inyección por constructor. Esta decisión simplifica la integración con
///   el árbol de providers de Flutter pero dificulta los tests unitarios del
///   provider de forma aislada.
///
/// Relación con otros módulos:
///   - `AuthService`: ejecuta la petición HTTP de login/logout contra api-py.
///   - `ApiService`: almacena el token Bearer y gestiona el callback de 401.
///   - `Session` / `PermissionMap`: modelos que este provider expone a la UI.
///   - Pantalla de login: consume [status] y [errorMessage] para la UI y llama
///     a [login].
///   - Pantallas con acceso condicional: consultan [isSuperAdmin],
///     [canViewUserManagement] y [canViewAnyServer].
class AuthProvider with ChangeNotifier {
  /// Estado actual del ciclo de autenticación.
  AuthStatus _status = AuthStatus.initial;

  /// Datos de la sesión activa. `null` si el usuario no está autenticado.
  Session? _session;

  /// Mensaje de error del último intento de login fallido. `null` si no hay error.
  String? _errorMessage;

  // ── Getters públicos ────────────────────────────────────────────────────────

  /// Estado actual de autenticación. Observado por la UI para reaccionar
  /// a cambios en el ciclo de vida de la sesión.
  AuthStatus get status => _status;

  /// Datos de la sesión activa. `null` si no autenticado.
  /// Las pantallas que requieran datos del usuario deben comprobar que no
  /// es `null` antes de acceder, o usar [isAuthenticated] como guardia.
  Session? get session => _session;

  /// Mensaje de error del último login fallido. Solo relevante cuando
  /// [status] es [AuthStatus.error].
  String? get errorMessage => _errorMessage;

  /// `true` si el usuario está autenticado y la sesión es válida.
  /// Equivalente a `status == AuthStatus.authenticated`.
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // ── Login ───────────────────────────────────────────────────────────────────

  /// Inicia el proceso de autenticación contra api-py.
  ///
  /// Flujo:
  ///   1. Transiciona a [AuthStatus.loading] y notifica (muestra spinner en UI).
  ///   2. Delega en `AuthService.instance.login` la petición HTTP al endpoint
  ///      de login de api-py.
  ///   3. En caso de éxito:
  ///      - Almacena el objeto [Session] con los datos del usuario.
  ///      - Inyecta el token Bearer en `ApiService` para autenticar peticiones.
  ///      - Registra [_invalidateSession] como handler de respuestas 401.
  ///      - Transiciona a [AuthStatus.authenticated].
  ///   4. En caso de [ApiException] (error HTTP conocido de api-py):
  ///      - Transiciona a [AuthStatus.error] con el mensaje del servidor.
  ///   5. En caso de cualquier otro error (red, parse, etc.):
  ///      - Transiciona a [AuthStatus.error] con mensaje genérico.
  ///
  /// Devuelve `true` si el login fue exitoso, `false` en caso contrario.
  /// La pantalla de login usa este valor de retorno para decidir si navegar
  /// a la pantalla principal, en lugar de observar el estado asíncronamente.
  ///
  /// Efectos secundarios:
  ///   - Modifica [_status], [_session], [_errorMessage].
  ///   - Llama a `notifyListeners()` dos veces: al inicio (loading) y al final.
  ///   - Registra el callback `onUnauthorized` en `ApiService`.
  Future<bool> login(String username, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await AuthService.instance.login(username, password);

      _session = response.session;
      // El token se inyecta en ApiService para que todas las peticiones
      // posteriores incluyan la cabecera Authorization: Bearer <token>.
      ApiService.instance.setToken(response.token);
      // Se registra el callback de invalidación: cualquier 401 futuro
      // en cualquier petición HTTP de la app resetea la sesión automáticamente.
      ApiService.instance.onUnauthorized = _invalidateSession;

      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      // Error HTTP conocido de api-py (credenciales inválidas, usuario bloqueado,
      // servidor no disponible, etc.). El mensaje viene del cuerpo de la respuesta.
      _status = AuthStatus.error;
      _errorMessage = e.message;
      debugPrint('ApiException en login: $e');
      notifyListeners();
      return false;
    } catch (e, st) {
      // Error inesperado: fallo de red, timeout, error de parseo del JSON, etc.
      _status = AuthStatus.error;
      _errorMessage = 'Error inesperado: $e';
      debugPrint('Error inesperado en login: $e');
      debugPrint('Stack trace: $st');
      notifyListeners();
      return false;
    }
  }

  // ── Logout ──────────────────────────────────────────────────────────────────

  /// Cierra la sesión del usuario de forma limpia.
  ///
  /// Flujo:
  ///   1. Elimina el callback `onUnauthorized` de `ApiService` ANTES de llamar
  ///      al servidor. Esto previene que un hipotético 401 en el endpoint de
  ///      logout dispare [_invalidateSession] mientras ya se está cerrando la
  ///      sesión, lo que causaría una doble notificación y potencialmente un
  ///      estado inconsistente.
  ///   2. Llama a `AuthService.instance.logout()` de forma best-effort: el
  ///      resultado se ignora con `catchError((_) {})`. Si el endpoint de
  ///      logout falla (red cortada, token ya expirado), la sesión local se
  ///      limpia igualmente. El token del servidor puede quedar activo hasta
  ///      su expiración natural.
  ///   3. Limpia el estado local: sesión, token en ApiService y status a initial.
  ///
  /// Efectos secundarios:
  ///   - Elimina `ApiService.instance.onUnauthorized`.
  ///   - Limpia el token de `ApiService`.
  ///   - Resetea [_session] a `null` y [_status] a [AuthStatus.initial].
  ///   - Llama a `notifyListeners()`: la UI (habitualmente la pantalla de login
  ///     registrada como observer) debe detectar este cambio y navegar al login.
  void logout() {
    // Elimina el callback antes del POST para evitar que un 401 en el logout
    // vuelva a disparar la invalidación mientras ya estamos saliendo.
    ApiService.instance.onUnauthorized = null;
    // Revoca el token en el servidor (best-effort: no bloquea si falla).
    // Si el servidor no está disponible, el token expirará de forma natural.
    AuthService.instance.logout().catchError((_) {});
    _session = null;
    ApiService.instance.clearToken();
    _status = AuthStatus.initial;
    notifyListeners();
  }

  // ── Invalidación automática por 401 ────────────────────────────────────────

  /// Invalida la sesión local sin llamar al servidor.
  ///
  /// Se registra en `ApiService.instance.onUnauthorized` tras el login para
  /// que cualquier petición HTTP que reciba un 401 (token expirado, revocado
  /// o sesión invalidada en el servidor) limpie automáticamente la sesión local.
  ///
  /// Diferencia con [logout]:
  ///   - [logout] es iniciado por el usuario: intenta revocar el token en el
  ///     servidor antes de limpiar el estado local.
  ///   - [_invalidateSession] es iniciado por ApiService ante un 401: la sesión
  ///     ya no es válida en el servidor, por lo que no tiene sentido llamar al
  ///     endpoint de logout; se limpia el estado local directamente.
  ///
  /// El callback se elimina de `ApiService` antes de modificar el estado para
  /// evitar re-entradas si [_invalidateSession] se llamara de nuevo durante
  /// la notificación (aunque en la práctica no debería ocurrir).
  ///
  /// Efectos secundarios:
  ///   - Elimina `ApiService.instance.onUnauthorized`.
  ///   - Limpia el token de `ApiService`.
  ///   - Resetea [_session] a `null` y [_status] a [AuthStatus.initial].
  ///   - Llama a `notifyListeners()`.
  void _invalidateSession() {
    ApiService.instance.onUnauthorized = null;
    _session = null;
    ApiService.instance.clearToken();
    _status = AuthStatus.initial;
    notifyListeners();
  }

  // ── Comprobaciones de acceso ────────────────────────────────────────────────

  /// `true` si el usuario en sesión pertenece a un grupo superadministrador.
  /// Devuelve `false` de forma segura si no hay sesión activa.
  /// Ver [Session.isSuperAdmin] para la definición completa.
  bool get isSuperAdmin => _session?.isSuperAdmin ?? false;

  /// `true` si el usuario puede acceder a la gestión de usuarios y grupos.
  /// Devuelve `false` si no hay sesión activa.
  /// Ver [Session.canViewUserManagement] para la lógica de permisos.
  bool canViewUserManagement() => _session?.canViewUserManagement() ?? false;

  /// `true` si el usuario puede ver al menos un servidor en la app.
  /// Devuelve `false` si no hay sesión activa.
  /// Ver [Session.canViewAnyServer] para la lógica de permisos.
  bool canViewAnyServer() => _session?.canViewAnyServer() ?? false;
}
