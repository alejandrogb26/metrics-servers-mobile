/// model_paged_response.dart
///
/// Propósito:
///   Define [PagedResponse<T>], el modelo genérico que encapsula cualquier
///   respuesta paginada de api-py. Centraliza en un único lugar la estructura
///   de paginación del backend, evitando que cada servicio reimplemnte su
///   propia lógica de deserialización de metadatos de página.
///
/// Capa arquitectónica:
///   Capa de dominio / modelos (models/).
///   Es un modelo de infraestructura transversal: no pertenece a ningún
///   dominio funcional concreto (servidores, grupos, métricas), sino que es
///   compartido por todos los servicios HTTP que consumen endpoints paginados
///   de api-py.
///
/// Responsabilidades principales:
///   - Representar la envoltura de paginación devuelta por api-py.
///   - Deserializar la lista de ítems mediante una función conversora inyectada,
///     respetando el tipo genérico `T` sin acoplarse a ningún modelo concreto.
///   - Exponer los metadatos de paginación necesarios para que los providers
///     implementen carga incremental o scroll infinito.
///
/// Contrato JSON de api-py (todos los endpoints paginados):
///   ```json
///   {
///     "data":       [...],     // Lista de ítems del tipo correspondiente
///     "page":       1,         // Número de página actual
///     "size":       20,        // Ítems por página solicitados
///     "total":      150,       // Total de ítems en la colección completa
///     "totalPages": 8,         // Total de páginas disponibles
///     "hasNext":    true       // Indica si existe una página siguiente
///   }
///   ```
///   Nota: las claves `totalPages` y `hasNext` usan camelCase, a diferencia
///   del estilo snake_case habitual de api-py. Deben mantenerse exactamente así.
///
/// Qué NO debe contener este fichero:
///   - Modelos de dominio concretos (servidores, grupos, etc.).
///   - Lógica de negocio ni reglas de acceso.
///   - Llamadas HTTP ni referencias a servicios o providers.
///   - Lógica de UI ni formateo de valores.
library;

/// Envoltura genérica para una respuesta paginada de api-py.
///
/// Responsabilidad:
///   Encapsula la lista de ítems de tipo `T` junto con los metadatos de
///   paginación necesarios para navegar entre páginas. El tipo genérico `T`
///   permite reutilizar esta clase para cualquier entidad del sistema
///   (servidores, grupos, métricas, etc.) sin duplicar código.
///
/// Patrón de uso con `fromJson`:
///   El factory [PagedResponse.fromJson] recibe una función conversora
///   `T Function(dynamic)` que transforma cada elemento crudo del array JSON
///   en una instancia del modelo `T`. Esto evita el uso de reflexión y mantiene
///   la seguridad de tipos en tiempo de compilación:
///
///   ```dart
///   // En un servicio de servidores:
///   final paged = PagedResponse<Servidor>.fromJson(
///     responseJson,
///     (item) => Servidor.fromJson(item as Map<String, dynamic>),
///   );
///   ```
///
/// Relación con los providers:
///   Los providers que implementan carga incremental (scroll infinito) usan
///   [hasNext] para saber si deben mostrar el botón/trigger de "cargar más" y
///   [page] + [totalPages] para construir la petición a la siguiente página.
///   [total] se usa típicamente para mostrar el contador total de registros
///   en la cabecera de las pantallas de listado.
///
/// Inmutabilidad:
///   Todos los campos son `final`. El constructor admite `const` para instancias
///   construidas con literales (útil en tests), aunque en producción las
///   instancias se crean siempre mediante `fromJson`.
class PagedResponse<T> {
  /// Lista de ítems de la página actual, ya deserializados al tipo `T`.
  /// Nunca es `null`; puede ser una lista vacía si la página no contiene ítems
  /// (p. ej. la última página de una colección o una colección vacía).
  final List<T> data;

  /// Número de la página actual devuelta por api-py.
  /// El valor de inicio (0 o 1) sigue la convención del backend; los providers
  /// deben incrementar este valor en 1 para solicitar la página siguiente.
  final int page;

  /// Número máximo de ítems por página solicitado en la petición.
  /// Puede diferir del número real de ítems en [data] si es la última página.
  final int size;

  /// Número total de ítems en la colección completa (todas las páginas).
  /// Se usa para mostrar contadores del tipo "150 servidores" en la UI.
  final int total;

  /// Número total de páginas disponibles para la consulta actual.
  /// Clave JSON: `"totalPages"` (camelCase — excepción al estilo snake_case de api-py).
  final int totalPages;

  /// `true` si existe al menos una página posterior a la actual.
  /// Clave JSON: `"hasNext"` (camelCase — excepción al estilo snake_case de api-py).
  ///
  /// Es un campo de conveniencia: evita que el cliente tenga que calcular
  /// `page < totalPages` con su correspondiente riesgo de error de índice.
  /// Los providers deben usar este campo como condición de parada en la carga
  /// incremental, en lugar de recalcularlo localmente.
  final bool hasNext;

  const PagedResponse({
    required this.data,
    required this.page,
    required this.size,
    required this.total,
    required this.totalPages,
    required this.hasNext,
  });

  /// Deserializa una respuesta paginada de api-py.
  ///
  /// Parámetros:
  ///   - [json]: el objeto JSON completo de la respuesta paginada.
  ///   - [fromItem]: función conversora que transforma cada elemento crudo de
  ///     `json['data']` en una instancia de `T`. El argumento recibido es de
  ///     tipo `dynamic` pero en la práctica siempre es un `Map<String, dynamic>`;
  ///     el llamador debe hacer el cast explícito si el `fromJson` del modelo
  ///     lo requiere (ver ejemplo en la documentación de la clase).
  ///
  /// Todos los metadatos de paginación tienen fallback a `0` o `false` para
  /// evitar null pointer exceptions si api-py omite algún campo. En ese caso
  /// la UI mostrará "0 ítems, 0 páginas", que es preferible a un crash.
  ///
  /// Claves JSON esperadas:
  ///   - `data`       (`List<dynamic>`?) → [data]       (fallback: `[]`)
  ///   - `page`       (int?)             → [page]       (fallback: `0`)
  ///   - `size`       (int?)             → [size]       (fallback: `0`)
  ///   - `total`      (int?)             → [total]      (fallback: `0`)
  ///   - `totalPages` (int?)             → [totalPages] (fallback: `0`)
  ///   - `hasNext`    (bool?)            → [hasNext]    (fallback: `false`)
  factory PagedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromItem,
  ) {
    final items = json['data'] as List<dynamic>? ?? [];
    return PagedResponse(
      data: items.map(fromItem).toList(),
      page: json['page'] as int? ?? 0,
      size: json['size'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      hasNext: json['hasNext'] as bool? ?? false,
    );
  }
}
