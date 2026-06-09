/// model_session.dart
///
/// Propósito:
///   Define los modelos del subsistema de autenticación y sesión de Metrics Manager:
///   la respuesta al login ([LoginResponse]), los datos de sesión del usuario
///   autenticado ([Session]), el snapshot de su grupo ([GrupoSession]) y el mapa
///   de permisos en forma compuesta y directamente consultable ([PermissionMap]).
///
/// Capa arquitectónica:
///   Capa de dominio / modelos (models/).
///   A diferencia del resto de modelos, este fichero contiene lógica de dominio
///   ligera: [Session] expone métodos de comprobación de acceso (`canView*`) y
///   una propiedad derivada (`isSuperAdmin`). Esto es aceptable porque esa lógica
///   es intrínseca al dominio de sesión y no tiene dependencias externas.
///
/// Distinción entre modelos de sesión y modelos de administración:
///   Este fichero define modelos de uso en tiempo de ejecución para el usuario
///   actualmente autenticado. Son distintos de los modelos de administración:
///
///   - [PermissionMap] (este fichero): permisos del usuario en sesión como claves
///     compuestas string ("AUDIT_USER"). Permite comprobación directa sin catálogo.
///   - [GrupoPermissionMap] (model_grupo.dart): permisos de un grupo administrado
///     como listas de IDs enteros. Requiere el catálogo de [Permiso] para resolverse.
///
///   - [GrupoSession] (este fichero): snapshot ligero del grupo del usuario en sesión
///     (solo id, nombre y superAdmin). No incluye el mapa de permisos porque ya está
///     en [Session.permisos] en forma más útil.
///   - [Grupo] (model_grupo.dart): entidad completa con permisos para administración.
///
/// Flujo de autenticación:
///   1. La pantalla de login envía credenciales al endpoint de api-py.
///   2. api-py devuelve un [LoginResponse] con el token JWT y los datos de sesión.
///   3. El provider de autenticación deserializa [LoginResponse], extrae el [token]
///      y almacena el objeto [Session] para uso en toda la aplicación.
///   4. El token se incluye en la cabecera `Authorization: Bearer <token>` de todas
///      las peticiones HTTP subsiguientes.
///   5. [Session] queda disponible en el árbol de widgets para comprobaciones de
///      acceso mediante los métodos `canView*` e `isSuperAdmin`.
///
/// Claves de permiso compuestas — formato:
///   Las claves se construyen en api-py como:
///   CONCAT(permiso.nombre, '_', ambito.nombre)  →  ej: "AUDIT_USER", "MODIFY_SERV"
///
///   Ámbitos conocidos: USER, SERV, SYS
///   Acciones conocidas: AUDIT, MODIFY
///
///   Regla de distribución (definida por api-py, no impuesta por el modelo):
///   - Permisos de ámbito USER y SYS: siempre globales.
///   - Permisos de ámbito SERV: siempre por sección (una por servidor/grupo).
///
/// Qué NO debe contener este fichero:
///   - Llamadas HTTP (el login lo gestiona el servicio de autenticación).
///   - Almacenamiento persistente del token (responsabilidad del provider/storage).
///   - Lógica de refresco de token o gestión de expiración (responsabilidad del
///     provider de autenticación o del cliente HTTP).
///   - Comprobaciones de permiso más allá de las operaciones de UI de alto nivel
///     (pantallas concretas deben consultar al provider, no al modelo directamente).
library;

/// Mapa de permisos del usuario en sesión, en forma de claves compuestas string.
///
/// Responsabilidad:
///   Encapsula los permisos del usuario autenticado en una estructura optimizada
///   para comprobaciones directas en tiempo de ejecución, sin necesidad de
///   resolver catálogos de IDs. Las claves son strings compuestos del tipo
///   "ACCIÓN_ÁMBITO" (p. ej. "AUDIT_USER", "MODIFY_SERV").
///
/// Diferencia clave respecto a [GrupoPermissionMap] (model_grupo.dart):
///   [GrupoPermissionMap] almacena IDs enteros que referencian el catálogo de
///   [Permiso]. [PermissionMap] almacena directamente las claves compuestas
///   legibles, que api-py construye en el momento del login. Esto evita que la
///   app tenga que cargar el catálogo completo de permisos para saber qué puede
///   hacer el usuario.
///
/// Normalización a mayúsculas:
///   Tanto en `fromJson` como en todos los métodos de consulta, las claves se
///   normalizan a mayúsculas (`toUpperCase()`). Esto garantiza que las
///   comprobaciones sean insensibles a la capitalización del servidor, aunque
///   api-py actualmente siempre devuelve mayúsculas. La doble normalización
///   (en parse y en consulta) es redundante pero inofensiva.
class PermissionMap {
  /// Lista de claves de permiso con alcance global.
  /// Contiene permisos de ámbito USER y SYS (según la regla del backend).
  /// Nunca es `null`; puede ser una lista vacía.
  final List<String> global;

  /// Mapa de sección → lista de claves de permiso para esa sección.
  /// Las claves del mapa son IDs de sección (string); los valores son listas
  /// de claves compuestas de ámbito SERV asignadas a ese servidor/sección.
  /// Nunca es `null`; puede ser un mapa vacío.
  final Map<String, List<String>> sections;

  const PermissionMap({required this.global, required this.sections});

  /// Deserializa desde el objeto JSON `permisos` dentro de la respuesta de login.
  ///
  /// Claves JSON esperadas:
  ///   - `globalPerms` (`List<String>`?)              → [global]
  ///   - `sections`    (`Map<String, List<String>>`?) → [sections]
  ///
  /// Ambos campos se normalizan a mayúsculas durante el parseo. Ambos tienen
  /// fallback seguro a colecciones vacías.
  factory PermissionMap.fromJson(Map<String, dynamic> json) {
    // Las claves ya vienen como "AUDIT_USER", "AUDIT_SERV", etc.
    // Se normalizan a mayúsculas al parsear para no depender del servidor.
    final global =
        (json['globalPerms'] as List<dynamic>?)
            ?.map((e) => e.toString().toUpperCase())
            .toList() ??
        [];

    final sections = <String, List<String>>{};
    if (json['sections'] != null) {
      (json['sections'] as Map<String, dynamic>).forEach((seccionId, value) {
        sections[seccionId] = (value as List<dynamic>)
            .map((e) => e.toString().toUpperCase())
            .toList();
      });
    }

    return PermissionMap(global: global, sections: sections);
  }

  /// Comprueba si una clave compuesta (p. ej. "AUDIT_USER") está en los
  /// permisos globales del usuario.
  ///
  /// La comparación es insensible a mayúsculas: [pkey] se normaliza a
  /// mayúsculas antes de buscar en [global].
  ///
  /// Uso típico: comprobar permisos de ámbito USER o SYS.
  bool hasGlobalPermission(String pkey) => global.contains(pkey.toUpperCase());

  /// Comprueba si una clave compuesta (p. ej. "AUDIT_SERV") está en los
  /// permisos de una sección concreta.
  ///
  /// Parámetros:
  ///   - [seccionId]: identificador de la sección (clave del mapa [sections]).
  ///   - [pkey]: clave de permiso compuesta a comprobar.
  ///
  /// Devuelve `false` si la sección no existe en [sections] o si la clave
  /// no está en la lista de permisos de esa sección.
  ///
  /// Uso típico: comprobar si el usuario puede operar sobre un servidor
  /// concreto (p. ej. `hasSectionPermission(servidor.seccion.toString(), 'AUDIT_SERV')`).
  bool hasSectionPermission(String seccionId, String pkey) {
    final perms = sections[seccionId];
    return perms != null && perms.contains(pkey.toUpperCase());
  }

  /// Comprueba si una clave compuesta aparece en al menos una sección,
  /// independientemente de cuál.
  ///
  /// Uso típico: determinar si el usuario tiene acceso a algún servidor,
  /// sin saber de antemano a cuáles. Si devuelve `false`, el usuario no
  /// tiene acceso a ningún recurso de tipo SERV y la pantalla de servidores
  /// puede mostrarse vacía o bloqueada directamente.
  bool hasAnySectionPermission(String pkey) {
    return sections.values.any((perms) => perms.contains(pkey.toUpperCase()));
  }
}

/// Snapshot del grupo del usuario para uso dentro de la sesión activa.
///
/// Responsabilidad:
///   Almacena la información mínima del grupo necesaria durante la sesión:
///   identificador, nombre de presentación y flag de superadministrador.
///   No incluye el mapa completo de permisos del grupo porque [Session] ya
///   expone los permisos en forma de [PermissionMap], más adecuada para
///   comprobaciones en tiempo de ejecución.
///
/// Relación con [Grupo] (model_grupo.dart):
///   [GrupoSession] es un subconjunto de [Grupo]. [Grupo] es la entidad
///   completa usada en las pantallas de administración; [GrupoSession] es
///   el snapshot ligero embebido en la sesión del usuario autenticado.
class GrupoSession {
  /// Identificador numérico del grupo. Fallback a `0` si ausente.
  final int id;

  /// Nombre de presentación del grupo. Fallback a cadena vacía si ausente.
  final String nombre;

  /// `true` si el grupo tiene privilegios de superadministrador en api-py.
  /// Cuando es `true`, [Session.isSuperAdmin] devuelve `true` y todos los
  /// métodos `canView*` de [Session] retornan `true` sin comprobar permisos.
  /// Fallback a `false` (más seguro: no conceder privilegios elevados si
  /// el campo está ausente).
  final bool superAdmin;

  const GrupoSession({
    required this.id,
    required this.nombre,
    required this.superAdmin,
  });

  /// Deserializa desde el objeto JSON `grupo` dentro de la respuesta de login.
  ///
  /// Claves JSON esperadas:
  ///   - `id`         (int?)    → [id]         (fallback: `0`)
  ///   - `nombre`     (String?) → [nombre]      (fallback: `''`)
  ///   - `superadmin` (bool?)   → [superAdmin]  (fallback: `false`)
  factory GrupoSession.fromJson(Map<String, dynamic> json) {
    return GrupoSession(
      id: json['id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? '',
      // Fallback a false: no conceder superAdmin si el campo falta.
      superAdmin: json['superadmin'] as bool? ?? false,
    );
  }
}

/// Datos completos de la sesión del usuario autenticado.
///
/// Responsabilidad:
///   Encapsula toda la información del usuario en sesión que la app necesita
///   tras el login: identidad, grupo, permisos y foto de perfil. Es el objeto
///   central del provider de autenticación y el punto de referencia para todas
///   las comprobaciones de acceso en la UI.
///
/// Comprobaciones de acceso:
///   [Session] expone métodos `canView*` que encapsulan las reglas de negocio
///   de visibilidad para las distintas secciones de la app. Todas siguen el
///   mismo patrón: cortocircuito si [isSuperAdmin], luego comprobación del
///   permiso específico en [permisos].
///
///   Las pantallas deben consultar estos métodos (o al provider de auth) para
///   decidir qué mostrar o bloquear, en lugar de replicar la lógica de permisos
///   en cada widget.
///
/// Relación con otros módulos:
///   - Provider de autenticación: almacena la instancia de [Session] activa y
///     la expone al árbol de widgets.
///   - Pantalla de login: recibe un [LoginResponse] y extrae [Session] de él.
///   - Cualquier pantalla con acceso condicional: consulta `isSuperAdmin` o los
///     métodos `canView*` a través del provider.
///   - Servicio HTTP: usa [LoginResponse.token] para autenticar las peticiones.
class Session {
  /// Nombre de usuario usado para autenticarse (login identifier).
  final String username;

  /// Nombre de presentación legible del usuario, para mostrar en la UI.
  /// Clave JSON: `"displayName"` (camelCase).
  final String displayName;

  /// Dirección de correo electrónico del usuario.
  final String email;

  /// Snapshot del grupo al que pertenece el usuario en sesión.
  /// Siempre presente: si api-py no devuelve un objeto `grupo` válido,
  /// `fromJson` crea un [GrupoSession] vacío como valor de seguridad.
  final GrupoSession grupo;

  /// Mapa de permisos del usuario en forma de claves compuestas string.
  /// Siempre presente: si api-py no devuelve `permisos`, se usa un
  /// [PermissionMap] vacío (sin acceso a nada, salvo si [isSuperAdmin]).
  final PermissionMap permisos;

  /// URL a la foto de perfil del usuario. Puede ser `null` si el usuario
  /// no tiene foto configurada. Clave JSON: `"urlFoto"` (camelCase).
  final String? urlFoto;

  const Session({
    required this.username,
    required this.displayName,
    required this.email,
    required this.grupo,
    required this.permisos,
    this.urlFoto,
  });

  /// Deserializa desde el objeto JSON `session` dentro de [LoginResponse].
  ///
  /// Claves JSON esperadas:
  ///   - `username`    (String?)          → [username]
  ///   - `displayName` (String?)          → [displayName]
  ///   - `email`       (String?)          → [email]
  ///   - `grupo`       (Map? / any)       → [grupo]
  ///   - `permisos`    (Map? / null)      → [permisos]
  ///   - `urlFoto`     (String?)          → [urlFoto]
  ///
  /// Nota sobre la deserialización defensiva de `grupo`:
  ///   Se usa un chequeo de tipo `is Map<String, dynamic>` en lugar de un
  ///   simple null check. Esto cubre el caso en que `grupo` esté presente en
  ///   el JSON pero sea de un tipo inesperado (string, int, lista). En ese
  ///   caso se crea un [GrupoSession] vacío como valor de seguridad, evitando
  ///   un crash y negando implícitamente todos los privilegios elevados.
  factory Session.fromJson(Map<String, dynamic> json) {
    final grupoRaw = json['grupo'];
    return Session(
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      // Comprobación de tipo en lugar de null check: cubre respuestas malformadas
      // donde 'grupo' existe pero no es un Map. Fallback a sesión sin grupo.
      grupo: grupoRaw is Map<String, dynamic>
          ? GrupoSession.fromJson(grupoRaw)
          : const GrupoSession(id: 0, nombre: '', superAdmin: false),
      // Si 'permisos' es null o está ausente se parsea un mapa vacío, resultando
      // en un PermissionMap sin permisos: acceso denegado a todo (salvo superAdmin).
      permisos: PermissionMap.fromJson(
        json['permisos'] as Map<String, dynamic>? ?? {},
      ),
      urlFoto: json['urlFoto'] as String?,
    );
  }

  /// `true` si el usuario pertenece a un grupo con privilegios de superadministrador.
  /// Cuando es `true`, todos los métodos `canView*` retornan `true` directamente.
  bool get isSuperAdmin => grupo.superAdmin;

  /// Determina si el usuario puede acceder a la gestión de usuarios y grupos.
  ///
  /// Requiere el permiso global "AUDIT_USER". El ámbito USER es siempre global
  /// según el modelo de datos de api-py (nunca por sección).
  /// Un superadministrador siempre tiene acceso.
  bool canViewUserManagement() {
    if (isSuperAdmin) return true;
    return permisos.hasGlobalPermission('AUDIT_USER');
  }

  /// Determina si el usuario puede ver al menos un servidor en la app.
  ///
  /// Requiere el permiso "AUDIT_SERV" en al menos una sección. El ámbito SERV
  /// es siempre por sección según el modelo de datos de api-py.
  /// Si devuelve `false` (y el usuario no es superAdmin), la pantalla de
  /// servidores puede mostrarse bloqueada o con lista vacía.
  /// Un superadministrador siempre tiene acceso.
  bool canViewAnyServer() {
    if (isSuperAdmin) return true;
    return permisos.hasAnySectionPermission('AUDIT_SERV');
  }
}

/// Respuesta completa del endpoint de login de api-py.
///
/// Responsabilidad:
///   Encapsula el token JWT de acceso junto con sus metadatos y los datos de
///   sesión del usuario autenticado. Es el objeto raíz deserializado tras un
///   login exitoso.
///
/// Implicaciones de seguridad:
///   - [token]: token JWT que debe incluirse en la cabecera
///     `Authorization: Bearer <token>` de todas las peticiones autenticadas.
///     Debe almacenarse de forma segura (p. ej. `flutter_secure_storage`),
///     nunca en `SharedPreferences` sin cifrado.
///   - [expiresIn]: duración de validez del token en segundos (convención OAuth2).
///     El provider de autenticación debería usar este valor para detectar la
///     expiración y redirigir al login o refrescar el token antes de que caduque.
///     Actualmente el modelo solo almacena el valor; la lógica de refresco es
///     responsabilidad del provider o del interceptor HTTP.
///   - [tokenType]: tipo de token según OAuth2 (habitualmente `"Bearer"`).
///     Fallback a `"Bearer"` si ausente, siguiendo el estándar.
///
/// Nota sobre la deserialización de `token`:
///   A diferencia de otros campos, [token] se deserializa sin `?` ni fallback
///   (`json['token'] as String`). Si api-py no devuelve el campo `token` en el
///   login, se lanzará un [TypeError] inmediatamente. Esto es correcto: una
///   respuesta de login sin token es un error irrecuperable que no debe silenciarse.
class LoginResponse {
  /// Token JWT de acceso. Se usa como Bearer token en todas las peticiones
  /// autenticadas a api-py. Debe almacenarse de forma segura.
  /// Sin fallback: su ausencia lanza [TypeError] en `fromJson`.
  final String token;

  /// Tipo de token según el estándar OAuth2. Habitualmente `"Bearer"`.
  /// Fallback a `"Bearer"` si ausente. Clave JSON: `"tokenType"` (camelCase).
  final String tokenType;

  /// Duración de validez del token en segundos desde el momento del login.
  /// Valor estándar OAuth2 (`expires_in`). Clave JSON: `"expiresIn"` (camelCase).
  /// Fallback a `0` si ausente (implica expiración inmediata o desconocida).
  final int expiresIn;

  /// Datos completos de la sesión del usuario autenticado.
  /// Sin fallback: su ausencia lanza [TypeError] en `fromJson`.
  final Session session;

  const LoginResponse({
    required this.token,
    required this.tokenType,
    required this.expiresIn,
    required this.session,
  });

  /// Deserializa desde el JSON de respuesta del endpoint de login de api-py.
  ///
  /// Claves JSON esperadas:
  ///   - `token`     (String)  → [token]     (requerido, sin fallback ni `?`)
  ///   - `tokenType` (String?) → [tokenType] (fallback: `"Bearer"`)
  ///   - `expiresIn` (int?)    → [expiresIn] (fallback: `0`)
  ///   - `session`   (Map)     → [session]   (requerido, sin fallback ni `?`)
  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      // Cast no nullable intencional: un login sin token es un error irrecuperable.
      token: json['token'] as String,
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      expiresIn: json['expiresIn'] as int? ?? 0,
      // Cast no nullable intencional: un login sin datos de sesión es irrecuperable.
      session: Session.fromJson(json['session'] as Map<String, dynamic>),
    );
  }
}
