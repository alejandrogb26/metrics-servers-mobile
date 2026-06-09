/// servicio_service.dart
///
/// Propósito:
///   Servicio de dominio para servicios de software (Apache, MySQL, etc.).
///   Provee acceso de solo lectura al catálogo de servicios registrados en
///   api-py: obtención del listado completo y consulta de un servicio concreto
///   por ID. Traduce las respuestas HTTP en instancias de [Servicio].
///
/// Capa arquitectónica:
///   Capa de servicios (services/). Actúa como adaptador entre [ServidorProvider]
///   (capa de estado) y [ApiService] (capa de transporte HTTP). No gestiona
///   estado reactivo ni caché: eso pertenece a [ServidorProvider].
///
/// Clases definidas en este fichero:
///   - [ServicioService]: singleton con los métodos [getAll] y [getById].
///
/// Patrón singleton:
///   Constructor privado `ServicioService._()` + campo estático `instance`.
///   Mismo patrón que el resto de servicios de dominio.
///
/// Rol de los servicios en la app:
///   Un [Servicio] representa un software monitorizado (p. ej. Apache HTTP,
///   MySQL, Redis). Cada [Servidor] lleva una lista de IDs de servicios
///   instalados. [ServidorProvider.preloadCaches] llama a [getAll] para poblar
///   `serviciosCache` (`Map<int, Servicio>`), que usan:
///   - [DetalleServiciosList]: muestra los servicios instalados en un servidor.
///   - [ListaServiciosScreen]: muestra el catálogo completo de servicios con
///     los servidores cargados que los usan.
///
/// Nombre del endpoint:
///   api-py expone el recurso como `/servicio` (singular), igual que `/seccion`,
///   a diferencia del patrón REST habitual de usar plural.
///
/// Formato de respuesta de la API:
///   - `GET /servicio` devuelve un envelope paginado:
///     `{ "data": [...], "total": n, "page": 0, "size": 100 }`.
///     [getAll] extrae únicamente la clave `data`.
///   - `GET /servicio/{id}` devuelve el objeto servicio directamente (sin envelope).
///
/// Estrategia de paginación en [getAll]:
///   Se solicita siempre la página 0 con tamaño 100. Asume implícitamente que
///   el número de servicios registrados no supera 100. No hay iteración de
///   páginas ni indicación de truncado si el total supera ese límite.
///
/// Qué NO debe contener este fichero:
///   - Lógica de estado reactivo (ChangeNotifier, streams).
///   - Caché de resultados (responsabilidad de [ServidorProvider]).
///   - Llamadas a otros servicios de dominio.
///   - Operaciones de escritura (creación, edición o borrado de servicios).
library;

import 'package:metrics_servers_mobile/models/model_servicio.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';

/// Servicio de acceso al catálogo de servicios de software singleton.
///
/// Responsabilidad:
///   Realizar las peticiones HTTP de lectura sobre el recurso `/servicio` y
///   deserializar las respuestas en instancias de [Servicio].
///
/// Invocado por [ServidorProvider.preloadCaches], que lo llama junto con
/// [SeccionService] para construir los cachés necesarios antes de mostrar
/// la lista de servidores y el catálogo de servicios.
class ServicioService {
  ServicioService._();

  /// Instancia única compartida por toda la aplicación.
  static final ServicioService instance = ServicioService._();

  /// Obtiene hasta 100 servicios de api-py (página 0, tamaño 100).
  ///
  /// La respuesta es un envelope paginado; este método extrae solo la clave
  /// `data` y deserializa cada elemento en un [Servicio] mediante
  /// `Servicio.fromJson`.
  ///
  /// El guard `?? []` sobre `map['data']` protege contra una clave `data`
  /// ausente o con valor `null` en la respuesta, devolviendo una lista vacía
  /// en lugar de lanzar un error de deserialización.
  ///
  /// El cast `raw as Map<String, dynamic>` es directo y no defensivo: si
  /// api-py devolviera un formato inesperado se lanzaría [TypeError] en lugar
  /// de [ApiException].
  ///
  /// Limitación: con `page=0, size=100` solo se recuperan los primeros 100
  /// servicios. Si el catálogo supera ese número, los servicios restantes no
  /// aparecerán en [DetalleServiciosList] ni en [ListaServiciosScreen].
  ///
  /// Throws [ApiException] si [ApiService.get] falla por error de red, timeout
  /// o código HTTP de error.
  Future<List<Servicio>> getAll() async {
    final raw = await ApiService.instance.get(
      '/servicio',
      query: {'page': '0', 'size': '100'},
    );
    final map = raw as Map<String, dynamic>;
    final items = map['data'] as List<dynamic>? ?? [];
    return items
        .map((e) => Servicio.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene un servicio concreto por su [id].
  ///
  /// Llama a `GET /servicio/{id}`. La respuesta es el objeto servicio
  /// directamente, sin envelope paginado, y se deserializa en [Servicio]
  /// mediante `Servicio.fromJson`.
  ///
  /// El cast `data as Map<String, dynamic>` es directo y no defensivo: si
  /// api-py devolviera un formato inesperado se lanzaría [TypeError] en lugar
  /// de [ApiException].
  ///
  /// Throws [ApiException] si [ApiService.get] falla por error de red, timeout,
  /// 404 (servicio no encontrado) u otro código HTTP de error.
  Future<Servicio> getById(int id) async {
    final data = await ApiService.instance.get('/servicio/$id');
    return Servicio.fromJson(data as Map<String, dynamic>);
  }
}
