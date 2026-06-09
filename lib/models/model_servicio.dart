/// model_servicio.dart
///
/// Propósito:
///   Define [Servicio], el modelo de catálogo que representa un servicio o
///   tecnología de software que puede estar instalada en un servidor gestionado
///   (p. ej. Apache2, MariaDB, SSH, Nginx, Redis). Es una entidad de referencia:
///   describe qué es el servicio, no cómo se está ejecutando en un momento dado.
///
/// Capa arquitectónica:
///   Capa de dominio / modelos (models/).
///   PODO puro: no depende de Flutter, no contiene lógica de presentación
///   y no realiza llamadas HTTP. Es deserializado por el servicio correspondiente
///   y consumido por los providers y pantallas de detalle de servidor.
///
/// Distinción entre catálogo y métricas de servicio:
///   [Servicio] (este fichero) es la entidad de catálogo: identidad, nombre y
///   logo de un tipo de servicio, tal como lo define api-py.
///
///   [ServiceMetrics] (model_metrics.dart) son los datos de rendimiento en tiempo
///   real de un servicio concreto ejecutándose en un servidor (workers de Apache,
///   hilos de MariaDB, estado de SSH). Ambos modelos describen "servicios" pero
///   desde perspectivas completamente distintas y no se referencian entre sí
///   directamente.
///
/// Qué NO debe contener este fichero:
///   - Datos de métricas en tiempo real (pertenecen a model_metrics.dart).
///   - Lógica de presentación (formateo de nombres, selección de icono, etc.).
///   - Llamadas HTTP ni referencias a servicios o providers.
library;

/// Entidad de catálogo de un servicio o tecnología de software.
///
/// Responsabilidad:
///   Encapsula la identidad de un tipo de servicio tal como lo registra api-py:
///   su identificador, nombre legible y URL del logo. Permite a la UI mostrar
///   tarjetas y listas de servicios con su nombre y logo sin necesidad de
///   conocer los detalles de implementación del servicio.
///
/// Campo `logo` — clave JSON `urlLogo`:
///   El nombre del campo en el JSON de api-py es `"urlLogo"` (camelCase), a
///   diferencia del estilo snake_case habitual del backend. El campo Dart se
///   llama `logo` por brevedad. Esta discrepancia debe tenerse en cuenta si
///   alguna vez se serializa de vuelta a JSON (no es el caso actual).
///   El valor es una URL absoluta a la imagen del logo del servicio (puede ser
///   externa, p. ej. un CDN de logos de tecnologías). Si es `null`, el widget
///   [ServiceLogo] de `shared_widgets.dart` muestra un icono de ajustes genérico.
///
/// Relación con otros módulos:
///   - Servicio HTTP de catálogo: obtiene la lista de [Servicio] desde api-py.
///   - Provider de servidores/servicios: expone la lista al árbol de widgets.
///   - Pantalla de detalle de servidor: muestra los servicios instalados con su
///     logo y nombre usando este modelo.
///   - [ServiceLogo] (shared_widgets.dart): consume [logo] para renderizar la
///     imagen del servicio con fallback automático ante URL nula o rota.
class Servicio {
  /// Identificador numérico único del servicio en el catálogo de api-py.
  /// Fallback a `0` si el campo está ausente en el JSON.
  final int id;

  /// Nombre legible del servicio (p. ej. "Apache2", "MariaDB", "SSH").
  /// Fallback a cadena vacía si ausente.
  final String nombre;

  /// URL absoluta del logo del servicio. Puede ser `null` si el servicio no
  /// tiene logo configurado en api-py.
  /// Clave JSON: `"urlLogo"` (camelCase — excepción al estilo snake_case de api-py).
  final String? logo;

  const Servicio({required this.id, required this.nombre, this.logo});

  /// Deserializa desde el JSON de un servicio devuelto por api-py.
  ///
  /// Claves JSON esperadas:
  ///   - `id`      (int?)    → [id]     (fallback: `0`)
  ///   - `nombre`  (String?) → [nombre] (fallback: `''`)
  ///   - `urlLogo` (String?) → [logo]   (puede ser `null`; nota: clave camelCase)
  factory Servicio.fromJson(Map<String, dynamic> json) {
    return Servicio(
      id: json['id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? '',
      // La clave JSON es 'urlLogo' (camelCase), no 'logo' ni 'url_logo'.
      // El campo Dart se llama 'logo' por brevedad.
      logo: json['urlLogo'] as String?,
    );
  }
}
