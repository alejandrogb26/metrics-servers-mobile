/// model_permiso.dart
///
/// Propósito:
///   Define los modelos [Ambito] y [Permiso], que representan la estructura
///   granular del sistema de autorización de Metrics Manager. Un [Permiso] es
///   una acción concreta que puede realizarse en el sistema (p. ej. "ver
///   servidores", "editar grupos"), y un [Ambito] categoriza ese permiso dentro
///   de un área funcional (p. ej. "Servidores", "Grupos", "Métricas").
///
/// Capa arquitectónica:
///   Capa de dominio / modelos (models/).
///   Estos modelos son PODO: no dependen de Flutter, no contienen lógica de
///   presentación y no realizan llamadas HTTP. Son deserializados por el
///   servicio de permisos y consumidos por los providers y pantallas de
///   gestión de grupos y permisos.
///
/// Relación con el resto del subsistema de autorización:
///   El sistema de permisos de la app opera en tres capas:
///
///     1. [Permiso] + [Ambito] (este fichero): entidades de catálogo que
///        describen qué permisos existen y a qué ámbito pertenecen.
///     2. `GrupoPermissionMap` (model_grupo.dart): lista de IDs de [Permiso]
///        asignados a un grupo, organizados en permisos globales y por sección.
///     3. Provider de autenticación: cruza los IDs del grupo del usuario en
///        sesión con el catálogo de [Permiso] para determinar el acceso.
///
///   El `id` de [Permiso] es la clave de enlace entre ambas capas: los valores
///   almacenados en `GrupoPermissionMap.global` y `GrupoPermissionMap.sections`
///   son IDs que corresponden a instancias de [Permiso].
///
/// Qué NO debe contener este fichero:
///   - Lógica de comprobación de acceso (pertenece al provider de auth).
///   - Llamadas HTTP ni referencias a servicios o providers.
///   - Lógica de presentación (iconos por ámbito, etiquetas formateadas, etc.).
///   - Gestión de sesión o token JWT.
library;

/// Categoría o área funcional a la que pertenece un [Permiso].
///
/// Responsabilidad:
///   Agrupa permisos relacionados bajo un mismo dominio funcional del sistema.
///   Permite a la UI organizar la lista de permisos disponibles por ámbito
///   (p. ej. mostrar todos los permisos de "Servidores" juntos), y facilita
///   al administrador comprender el alcance de cada permiso.
///
/// Relación con `GrupoPermissionMap.sections`:
///   Las claves del mapa `sections` en [model_grupo.dart] son identificadores
///   de sección (strings), que pueden corresponderse conceptualmente con los
///   nombres de los ámbitos. Sin embargo, son representaciones independientes:
///   `sections` almacena IDs agrupados por clave string, mientras que [Ambito]
///   es la entidad de catálogo completa con id, nombre y descripción.
///
/// Todos los campos no opcionales tienen fallback en `fromJson` para garantizar
/// que el modelo nunca contiene `null` en campos requeridos.
class Ambito {
  /// Identificador numérico único del ámbito en api-py.
  /// Fallback a `0` si el campo está ausente (valor centinela; api-py no
  /// debería devolver ámbitos sin ID en condiciones normales).
  final int id;

  /// Nombre del ámbito, legible para el usuario (p. ej. "Servidores", "Grupos").
  /// Fallback a cadena vacía si ausente.
  final String nombre;

  /// Descripción opcional del ámbito. Puede ser `null` si api-py no la incluye.
  final String? descripcion;

  const Ambito({required this.id, required this.nombre, this.descripcion});

  /// Deserializa desde el objeto JSON `ambito` embebido en un [Permiso].
  ///
  /// Claves JSON esperadas:
  ///   - `id`          (int?)    → [id]          (fallback: `0`)
  ///   - `nombre`      (String?) → [nombre]       (fallback: `''`)
  ///   - `descripcion` (String?) → [descripcion]  (puede ser `null`)
  factory Ambito.fromJson(Map<String, dynamic> json) {
    return Ambito(
      id: json['id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
    );
  }
}

/// Permiso individual del sistema de autorización de Metrics Manager.
///
/// Responsabilidad:
///   Representa una acción o capacidad concreta que puede ser concedida a un
///   grupo. Cada permiso pertenece a exactamente un [Ambito] que categoriza
///   su área funcional.
///
/// Relación con [Ambito]:
///   [ambito] es un campo requerido y no nullable: api-py siempre embebe el
///   objeto ámbito completo dentro de cada permiso (no solo su ID). Esto evita
///   que la app tenga que hacer una petición separada para resolver el ámbito,
///   a costa de cierta redundancia si varios permisos comparten el mismo ámbito.
///
/// Relación con `GrupoPermissionMap` (model_grupo.dart):
///   Los valores almacenados en `GrupoPermissionMap.global` y en las listas de
///   `GrupoPermissionMap.sections` son valores de [Permiso.id]. La app cruza
///   esos IDs con el catálogo de [Permiso] obtenido de api-py para determinar
///   qué permisos tiene asignados el grupo del usuario en sesión.
///
/// Relación con otros módulos:
///   - Servicio de permisos: obtiene el catálogo completo de [Permiso] desde
///     api-py y los deserializa usando este modelo.
///   - Provider de gestión de grupos: usa [Permiso] para mostrar el selector
///     de permisos al editar un grupo.
///   - Provider de autenticación: puede usar [Permiso.id] para comprobar si
///     el grupo del usuario tiene un permiso concreto.
class Permiso {
  /// Identificador numérico único del permiso en api-py.
  /// Es la clave de enlace con las listas de IDs de `GrupoPermissionMap`.
  /// Fallback a `0` si el campo está ausente.
  final int id;

  /// Nombre del permiso, legible para el usuario (p. ej. "Ver servidores",
  /// "Editar grupos"). Fallback a cadena vacía si ausente.
  final String nombre;

  /// Descripción opcional del permiso. Puede ser `null` si api-py no la incluye.
  final String? descripcion;

  /// Ámbito funcional al que pertenece este permiso.
  /// Es requerido y no nullable: api-py siempre lo incluye en la respuesta.
  final Ambito ambito;

  const Permiso({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.ambito,
  });

  /// Deserializa desde el JSON de un permiso devuelto por api-py.
  ///
  /// Claves JSON esperadas:
  ///   - `id`          (int?)             → [id]          (fallback: `0`)
  ///   - `nombre`      (String?)          → [nombre]       (fallback: `''`)
  ///   - `descripcion` (String?)          → [descripcion]  (puede ser `null`)
  ///   - `ambito`      (`Map<String,dyn>`) → [ambito]       (requerido, sin fallback)
  ///
  /// Advertencia:
  ///   A diferencia de otros modelos, la deserialización de [ambito] no tiene
  ///   guarda de nulo (`json['ambito'] != null ? ... : null`). Si api-py devuelve
  ///   un permiso sin el objeto `ambito`, esta línea lanzará un [TypeError] en
  ///   tiempo de ejecución. El contrato con api-py asume que `ambito` siempre
  ///   está presente; si ese contrato se rompe, el error se manifestará aquí.
  factory Permiso.fromJson(Map<String, dynamic> json) {
    return Permiso(
      id: json['id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      // Cast directo sin guarda de nulo: se asume que api-py siempre incluye
      // el objeto ambito embebido. Ver advertencia en la documentación del método.
      ambito: Ambito.fromJson(json['ambito'] as Map<String, dynamic>),
    );
  }
}
