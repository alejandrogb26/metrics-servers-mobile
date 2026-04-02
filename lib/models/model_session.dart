/// Claves de permiso compuestas tal como las construye la API:
/// CONCAT(p.nombre, '_', a.nombre)  →  ej: "AUDIT_USER", "AUDIT_SERV", "MODIFY_SERV"
///
/// Ámbitos conocidos: USER, SERV, SYS
/// Permisos conocidos: AUDIT, MODIFY
///
/// Los permisos de ámbito USER y SYS son siempre globales.
/// Los permisos de ámbito SERV son siempre por sección.
class PermissionMap {
  final List<String> global;
  final Map<String, List<String>> sections;

  const PermissionMap({required this.global, required this.sections});

  factory PermissionMap.fromJson(Map<String, dynamic> json) {
    // Las claves ya vienen como "AUDIT_USER", "AUDIT_SERV", etc.
    // Se normalizan a mayúsculas al parsear para no depender del servidor.
    final global =
        (json['global'] as List<dynamic>?)
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

  /// Comprueba si una clave compuesta (ej: "AUDIT_USER") está en los permisos globales.
  bool hasGlobalPermission(String pkey) => global.contains(pkey.toUpperCase());

  /// Comprueba si una clave compuesta (ej: "AUDIT_SERV") está en los permisos
  /// de una sección concreta.
  bool hasSectionPermission(String seccionId, String pkey) {
    final perms = sections[seccionId];
    return perms != null && perms.contains(pkey.toUpperCase());
  }

  /// Comprueba si una clave compuesta aparece en al menos una sección.
  bool hasAnySectionPermission(String pkey) {
    return sections.values.any((perms) => perms.contains(pkey.toUpperCase()));
  }
}

class GrupoSession {
  final int id;
  final String nombre;
  final bool superAdmin;

  const GrupoSession({
    required this.id,
    required this.nombre,
    required this.superAdmin,
  });

  factory GrupoSession.fromJson(Map<String, dynamic> json) {
    return GrupoSession(
      id: json['id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? '',
      superAdmin: json['superAdmin'] as bool? ?? false,
    );
  }
}

class Session {
  final String username;
  final String displayName;
  final String email;
  final GrupoSession grupo;
  final PermissionMap permisos;
  final String? urlFoto;

  const Session({
    required this.username,
    required this.displayName,
    required this.email,
    required this.grupo,
    required this.permisos,
    this.urlFoto,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      grupo: GrupoSession.fromJson(json['grupo'] as Map<String, dynamic>),
      permisos: PermissionMap.fromJson(
        json['permisos'] as Map<String, dynamic>? ?? {},
      ),
      urlFoto: json['urlFoto'] as String?,
    );
  }

  bool get isSuperAdmin => grupo.superAdmin;

  /// Gestión de usuarios (grupos/permisos): requiere AUDIT_USER en permisos globales.
  /// El ámbito USER siempre es global según el modelo de datos.
  bool canViewUserManagement() {
    if (isSuperAdmin) return true;
    return permisos.hasGlobalPermission('AUDIT_USER');
  }

  /// Ver servidores de una sección concreta: requiere AUDIT_SERV en esa sección.
  /// El ámbito SERV es siempre por sección según el modelo de datos.
  bool canViewServersInSection(String seccionId) {
    if (isSuperAdmin) return true;
    return permisos.hasSectionPermission(seccionId, 'AUDIT_SERV');
  }

  /// Ver el menú/listado de servidores: basta con tener AUDIT_SERV en alguna sección.
  bool canViewAnyServer() {
    if (isSuperAdmin) return true;
    return permisos.hasAnySectionPermission('AUDIT_SERV');
  }
}

class LoginResponse {
  final String token;
  final String tokenType;
  final int expiresIn;
  final Session session;

  const LoginResponse({
    required this.token,
    required this.tokenType,
    required this.expiresIn,
    required this.session,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] as String,
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      expiresIn: json['expiresIn'] as int? ?? 0,
      session: Session.fromJson(json['session'] as Map<String, dynamic>),
    );
  }
}
