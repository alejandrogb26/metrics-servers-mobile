/// model_grupo.dart
///
/// Propósito:
///   Define los modelos de datos para la entidad Grupo y su mapa de permisos.
///   Un [Grupo] representa una agrupación de usuarios en el sistema Metrics Manager
///   con un conjunto de permisos de acceso asociados. Es el modelo central del
///   subsistema de autorización de la aplicación.
///
/// Capa arquitectónica:
///   Capa de dominio / modelos (models/).
///   Estos modelos son PODO (Plain Old Dart Objects): no dependen de Flutter,
///   no contienen lógica de presentación y no realizan llamadas HTTP. Son
///   deserializados por el servicio de grupos y consumidos por los providers y
///   pantallas de gestión de grupos.
///
/// Responsabilidades principales:
///   - Representar la estructura de un grupo tal como la devuelve api-py.
///   - Encapsular el mapa de permisos (global + por sección) en [GrupoPermissionMap].
///   - Proveer [Grupo.allPermissionIds] como única operación de dominio del modelo:
///     la unión deduplicada de todos los IDs de permiso del grupo.
///
/// Modelo de permisos de api-py:
///   El sistema de autorización de api-py usa un esquema de permisos en dos niveles:
///
///     - **Permisos globales** (`globalPerms`): IDs de permiso que aplican a todos
///       los recursos del sistema, independientemente de la sección.
///     - **Permisos por sección** (`sections`): mapa donde cada clave es el
///       identificador de una sección/módulo (p. ej. `"servers"`, `"groups"`) y
///       el valor es la lista de IDs de permiso para esa sección concreta.
///
///   Adicionalmente, un grupo puede tener el flag [Grupo.superAdmin] que, en el
///   backend, concede acceso total sin necesidad de comprobar permisos individuales.
///
/// Qué NO debe contener este fichero:
///   - Lógica de comprobación de permisos en tiempo de ejecución (eso pertenece
///     al provider de autenticación/autorización o a helpers dedicados).
///   - Llamadas HTTP ni referencias a servicios o providers.
///   - Lógica de presentación (nombres de sección formateados, colores, etc.).
///   - Gestión de sesión o token JWT.
library;

/// Mapa de permisos asociado a un [Grupo].
///
/// Responsabilidad:
///   Encapsula la estructura de permisos en dos dimensiones: permisos globales
///   (aplican a cualquier recurso) y permisos por sección (aplican solo a los
///   recursos de una sección concreta). Esta separación permite que api-py
///   defina políticas de acceso granulares por módulo funcional.
///
/// Relación con [Grupo]:
///   Es un campo opcional de [Grupo]. Si [Grupo.permisos] es `null`, el grupo
///   no tiene permisos definidos (distinto de "no tiene ningún permiso"). La
///   capa de autorización debe tratar ambos casos como acceso denegado, salvo
///   que [Grupo.superAdmin] sea `true`.
///
/// Inmutabilidad:
///   Aunque `List<int>` y `Map<String, List<int>>` no son const en Dart, el
///   diseño asume que estas colecciones no se modifican tras la construcción.
///   El constructor `const` solo es posible para los campos de tipo simple;
///   las colecciones se construyen en `fromJson` y no se exponen con setters.
class GrupoPermissionMap {
  /// Lista de IDs de permiso con alcance global.
  /// Un ID en esta lista concede el permiso sobre cualquier sección del sistema.
  /// Nunca es `null`; puede ser una lista vacía si el grupo no tiene permisos globales.
  final List<int> global;

  /// Mapa de sección → lista de IDs de permiso para esa sección.
  ///
  /// Las claves son los identificadores de sección definidos por api-py
  /// (p. ej. `"servers"`, `"groups"`, `"metrics"`). El conjunto de claves
  /// válidas lo determina el backend; este modelo no las valida.
  /// Nunca es `null`; puede ser un mapa vacío.
  final Map<String, List<int>> sections;

  const GrupoPermissionMap({required this.global, required this.sections});

  /// Deserializa desde el objeto JSON `permisos` devuelto por api-py.
  ///
  /// Claves JSON esperadas:
  ///   - `globalPerms` (`List<int>`?)              → [global]
  ///     Nota: la clave usa camelCase (`globalPerms`), a diferencia del estilo
  ///     snake_case habitual de api-py. Debe mantenerse exactamente así.
  ///   - `sections`    (`Map<String, List<int>>`?) → [sections]
  ///
  /// Ambos campos tienen fallback seguro: `globalPerms` nulo produce `[]` y
  /// `sections` nulo produce un mapa vacío `{}`, evitando null pointer exceptions
  /// en los consumidores.
  factory GrupoPermissionMap.fromJson(Map<String, dynamic> json) {
    final global =
        (json['globalPerms'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        [];
    final sections = <String, List<int>>{};
    // Se usa forEach imperativo porque Map.map() no permite construir
    // directamente un Map<String, List<int>> sin un cast adicional.
    if (json['sections'] != null) {
      (json['sections'] as Map<String, dynamic>).forEach((key, value) {
        sections[key] = (value as List<dynamic>).map((e) => e as int).toList();
      });
    }
    return GrupoPermissionMap(global: global, sections: sections);
  }
}

/// Modelo de un grupo de usuarios de Metrics Manager.
///
/// Responsabilidad:
///   Representa un grupo/rol del sistema, con su identidad ([id], [nombre], [dn]),
///   su nivel de privilegio ([superAdmin]) y su mapa de permisos ([permisos]).
///   Es la unidad de autorización: los usuarios pertenecen a grupos, y los grupos
///   determinan qué operaciones pueden realizarse sobre cada recurso.
///
/// Campo `dn` — Distinguished Name:
///   El campo `dn` es el identificador único del grupo en el directorio LDAP/AD
///   que api-py usa como backend de autenticación. En pantallas de UI se muestra
///   como identificador técnico del grupo. No debe confundirse con [nombre], que
///   es el nombre de presentación legible.
///
/// Campo `superAdmin`:
///   Si es `true`, el grupo tiene privilegios de superadministrador. En api-py
///   esto implica acceso total sin comprobación de permisos granulares. La app
///   debe interpretar este flag para mostrar u ocultar controles de administración
///   en la UI. El fallback en `fromJson` es `false` (más seguro: no conceder
///   privilegios elevados si el campo está ausente).
///
/// Campo `permisos`:
///   Es opcional: puede ser `null` si api-py no devuelve información de permisos
///   para el grupo (p. ej. al listar grupos sin detalle de permisos). Si es `null`,
///   [allPermissionIds] devuelve `[]`. La lógica de autorización de la app no debe
///   asumir que `permisos == null` equivale a "sin permisos" sin considerar también
///   el flag [superAdmin].
///
/// Relación con otros módulos:
///   - `GrupoService` / repositorio HTTP: obtiene y deserializa instancias de [Grupo].
///   - Provider de grupos: expone la lista de grupos al árbol de widgets.
///   - Pantalla de gestión de grupos: consume [Grupo] para mostrar y editar grupos.
///   - Provider de autenticación: puede usar [allPermissionIds] o [superAdmin] para
///     determinar qué acciones están disponibles para el usuario en sesión.
class Grupo {
  /// Identificador numérico único del grupo en la base de datos de api-py.
  /// Fallback a `0` si el campo está ausente en el JSON (valor centinela,
  /// no un ID real; la capa de servicio no debería recibir grupos sin ID).
  final int id;

  /// Nombre de presentación del grupo, legible para el usuario final.
  final String nombre;

  /// Distinguished Name del grupo en el directorio LDAP/AD.
  /// Identificador técnico único; se muestra en pantallas de detalle del grupo.
  final String dn;

  /// `true` si el grupo tiene privilegios de superadministrador en api-py.
  /// Implica acceso total al sistema; la UI debe tratarlo con especial cuidado
  /// para no exponer operaciones destructivas sin confirmación adicional.
  /// Clave JSON: `"superadmin"` (todo en minúsculas, sin guion).
  final bool superAdmin;

  /// Mapa de permisos del grupo. Puede ser `null` si la respuesta de api-py
  /// no incluye el detalle de permisos (p. ej. en listados resumidos).
  final GrupoPermissionMap? permisos;

  const Grupo({
    required this.id,
    required this.nombre,
    required this.dn,
    required this.superAdmin,
    this.permisos,
  });

  /// Deserializa desde el JSON de un grupo devuelto por api-py.
  ///
  /// Claves JSON esperadas:
  ///   - `id`         (int?)    → [id]         (fallback: `0`)
  ///   - `nombre`     (String?) → [nombre]      (fallback: `''`)
  ///   - `dn`         (String?) → [dn]          (fallback: `''`)
  ///   - `superadmin` (bool?)   → [superAdmin]  (fallback: `false` — más seguro)
  ///   - `permisos`   (Map? / null) → [permisos]
  ///
  /// Los fallbacks de campos de texto vacíos y `superAdmin: false` garantizan
  /// que el modelo nunca contenga `null` en campos requeridos, simplificando
  /// la lógica de la UI que no necesita hacer null-checks sobre estos campos.
  factory Grupo.fromJson(Map<String, dynamic> json) {
    return Grupo(
      id: json['id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? '',
      dn: json['dn'] as String? ?? '',
      // Fallback explícito a false: ante la ausencia del campo, se niegan
      // privilegios elevados como medida de seguridad por defecto.
      superAdmin: json['superadmin'] as bool? ?? false,
      permisos: json['permisos'] != null
          ? GrupoPermissionMap.fromJson(
              json['permisos'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  /// Devuelve la unión deduplicada de todos los IDs de permiso del grupo:
  /// los permisos globales más los permisos de todas las secciones.
  ///
  /// Se usa un [Set] internamente para eliminar duplicados: un mismo ID de
  /// permiso puede aparecer tanto en [GrupoPermissionMap.global] como en una
  /// o varias secciones de [GrupoPermissionMap.sections]. Sin deduplicación,
  /// la comprobación `contains(id)` seguiría funcionando, pero las listas
  /// duplicadas consumirían memoria innecesaria y complicarían comparaciones.
  ///
  /// Devuelve `[]` si [permisos] es `null`, lo que el llamador debe interpretar
  /// como "sin permisos conocidos" (no como "acceso denegado" si [superAdmin]
  /// es `true`).
  List<int> allPermissionIds() {
    if (permisos == null) return [];
    final all = <int>{...permisos!.global};
    for (final list in permisos!.sections.values) {
      all.addAll(list);
    }
    return all.toList();
  }
}
