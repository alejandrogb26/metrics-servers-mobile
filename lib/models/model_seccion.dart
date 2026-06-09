/// model_seccion.dart
///
/// Propósito:
///   Define [Seccion], el modelo de catálogo que representa un módulo o área
///   de la aplicación sobre la que se pueden asignar permisos. Es la entidad
///   completa correspondiente a las claves string del mapa
///   `GrupoPermissionMap.sections` de [model_grupo.dart].
///
/// Capa arquitectónica:
///   Capa de dominio / modelos (models/).
///   PODO puro: no depende de Flutter, no contiene lógica de presentación
///   y no realiza llamadas HTTP. Es deserializado por el servicio de secciones
///   y consumido por los providers y pantallas de gestión de permisos de grupo.
///
/// Posición en el subsistema de autorización:
///   El sistema de permisos de api-py trabaja con tres entidades de catálogo:
///
///     - [Permiso] (model_permiso.dart): acción concreta (p. ej. "ver servidores").
///     - [Ambito]  (model_permiso.dart): área funcional que agrupa permisos
///                 (p. ej. "Servidores").
///     - [Seccion] (este fichero): módulo de la aplicación al que se restringen
///                 los permisos de sección (p. ej. "monitoring", "admin").
///
///   La diferencia semántica entre [Ambito] y [Seccion] es de perspectiva:
///   [Ambito] categoriza el permiso desde el punto de vista de la acción;
///   [Seccion] lo categoriza desde el punto de vista del módulo de la app.
///   Ambas entidades tienen la misma estructura de campos, pero representan
///   conceptos distintos en el modelo de autorización de api-py.
///
///   El campo [nombre] de [Seccion] es el que probablemente se corresponde con
///   las claves string de `GrupoPermissionMap.sections`, aunque el modelo no
///   impone esa correspondencia explícitamente.
///
/// Qué NO debe contener este fichero:
///   - Lógica de comprobación de acceso por sección.
///   - Llamadas HTTP ni referencias a servicios o providers.
///   - Lógica de presentación (iconos por sección, etiquetas formateadas, etc.).
library;

/// Módulo o área de la aplicación representado como entidad de catálogo.
///
/// Responsabilidad:
///   Encapsula la descripción completa de una sección del sistema tal como la
///   define api-py: identificador numérico, nombre legible y descripción opcional.
///   Permite a la UI mostrar las secciones disponibles con su nombre completo en
///   lugar de solo la clave técnica string que almacena [GrupoPermissionMap].
///
/// Estructura idéntica a [Ambito]:
///   [Seccion] comparte exactamente los mismos campos que [Ambito]
///   (`id`, `nombre`, `descripcion`) y el mismo patrón de deserialización.
///   Son entidades separadas porque representan conceptos distintos en el
///   modelo de autorización del backend, aunque su forma en JSON sea la misma.
///
/// Relación con `GrupoPermissionMap.sections` (model_grupo.dart):
///   Las claves del mapa `sections` son strings que identifican secciones.
///   Una instancia de [Seccion] con [nombre] igual a una de esas claves es
///   la representación completa de esa sección, útil para mostrar su nombre
///   y descripción al usuario sin depender de un string técnico interno.
class Seccion {
  /// Identificador numérico único de la sección en api-py.
  /// Fallback a `0` si el campo está ausente en el JSON.
  final int id;

  /// Nombre de la sección, legible para el usuario y equivalente técnico de
  /// la clave string usada en `GrupoPermissionMap.sections`.
  /// Fallback a cadena vacía si ausente.
  final String nombre;

  /// Descripción opcional de la sección. Puede ser `null` si api-py no
  /// la incluye en la respuesta.
  final String? descripcion;

  const Seccion({required this.id, required this.nombre, this.descripcion});

  /// Deserializa desde el JSON de una sección devuelto por api-py.
  ///
  /// Claves JSON esperadas:
  ///   - `id`          (int?)    → [id]          (fallback: `0`)
  ///   - `nombre`      (String?) → [nombre]       (fallback: `''`)
  ///   - `descripcion` (String?) → [descripcion]  (puede ser `null`)
  factory Seccion.fromJson(Map<String, dynamic> json) {
    return Seccion(
      id: json['id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
    );
  }
}
