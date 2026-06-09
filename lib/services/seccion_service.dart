/// seccion_service.dart
///
/// Propósito:
///   Servicio de dominio para secciones de servidor. Provee acceso de solo
///   lectura al catálogo de secciones registradas en api-py: obtención del
///   listado completo y consulta de una sección concreta por ID. Traduce las
///   respuestas HTTP en instancias de [Seccion].
///
/// Capa arquitectónica:
///   Capa de servicios (services/). Actúa como adaptador entre [ServidorProvider]
///   (capa de estado) y [ApiService] (capa de transporte HTTP). No gestiona
///   estado reactivo ni caché: eso pertenece a [ServidorProvider].
///
/// Clases definidas en este fichero:
///   - [SeccionService]: singleton con los métodos [getAll] y [getById].
///
/// Patrón singleton:
///   Constructor privado `SeccionService._()` + campo estático `instance`.
///   Mismo patrón que el resto de servicios de dominio.
///
/// Rol de las secciones en la app:
///   Las secciones agrupan servidores lógicamente (p. ej. "Producción", "QA").
///   [ServidorProvider.preloadCaches] llama a [getAll] para poblar
///   `seccionesCache` (`Map<int, Seccion>`), que usa [ListaServidoresScreen]
///   para agrupar la lista de servidores por sección y [DetalleInfoCard] para
///   mostrar nombre y descripción de la sección de cada servidor.
///
/// Nombre del endpoint:
///   api-py expone el recurso como `/seccion` (singular), a diferencia del
///   patrón REST habitual de usar plural. Los métodos de este servicio
///   reproducen ese nombre tal cual.
///
/// Formato de respuesta de la API:
///   - `GET /seccion` devuelve un envelope paginado:
///     `{ "data": [...], "total": n, "page": 0, "size": 100 }`.
///     [getAll] extrae únicamente la clave `data`.
///   - `GET /seccion/{id}` devuelve el objeto sección directamente (sin envelope).
///
/// Estrategia de paginación en [getAll]:
///   Se solicita siempre la página 0 con tamaño 100. Asume implícitamente que
///   el número de secciones no supera 100. No hay iteración de páginas ni
///   indicación de truncado si el total supera ese límite.
///
/// Qué NO debe contener este fichero:
///   - Lógica de estado reactivo (ChangeNotifier, streams).
///   - Caché de resultados (responsabilidad de [ServidorProvider]).
///   - Llamadas a otros servicios de dominio.
///   - Operaciones de escritura (creación, edición o borrado de secciones).
library;

import 'package:metrics_servers_mobile/models/model_seccion.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';

/// Servicio de acceso a secciones singleton.
///
/// Responsabilidad:
///   Realizar las peticiones HTTP de lectura sobre el recurso `/seccion` y
///   deserializar las respuestas en instancias de [Seccion].
///
/// Invocado por [ServidorProvider.preloadCaches], que lo usa junto con
/// [ServicioService] para construir los cachés necesarios antes de mostrar
/// la lista de servidores y el catálogo de servicios.
class SeccionService {
  SeccionService._();

  /// Instancia única compartida por toda la aplicación.
  static final SeccionService instance = SeccionService._();

  /// Obtiene hasta 100 secciones de api-py (página 0, tamaño 100).
  ///
  /// La respuesta es un envelope paginado; este método extrae solo la clave
  /// `data` y deserializa cada elemento en una [Seccion] mediante
  /// `Seccion.fromJson`.
  ///
  /// El guard `?? []` sobre `map['data']` protege contra una clave `data`
  /// ausente o con valor `null` en la respuesta, devolviendo una lista vacía
  /// en lugar de lanzar un error de deserialización.
  ///
  /// El cast `raw as Map<String, dynamic>` es directo y no defensivo: si
  /// api-py devolviera un formato inesperado se lanzaría [TypeError] en lugar
  /// de [ApiException].
  ///
  /// Limitación: con `page=0, size=100` solo se recuperan las primeras 100
  /// secciones. Si el catálogo supera ese número, las secciones restantes no
  /// aparecerán en el agrupamiento de [ListaServidoresScreen] ni en
  /// [DetalleInfoCard].
  ///
  /// Throws [ApiException] si [ApiService.get] falla por error de red, timeout
  /// o código HTTP de error.
  Future<List<Seccion>> getAll() async {
    final raw = await ApiService.instance.get(
      '/seccion',
      query: {'page': '0', 'size': '100'},
    );
    final map = raw as Map<String, dynamic>;
    final items = map['data'] as List<dynamic>? ?? [];
    return items
        .map((e) => Seccion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene una sección concreta por su [id].
  ///
  /// Llama a `GET /seccion/{id}`. La respuesta es el objeto sección
  /// directamente, sin envelope paginado, y se deserializa en [Seccion]
  /// mediante `Seccion.fromJson`.
  ///
  /// El cast `data as Map<String, dynamic>` es directo y no defensivo: si
  /// api-py devolviera un formato inesperado se lanzaría [TypeError] en lugar
  /// de [ApiException].
  ///
  /// Throws [ApiException] si [ApiService.get] falla por error de red, timeout,
  /// 404 (sección no encontrada) u otro código HTTP de error.
  Future<Seccion> getById(int id) async {
    final data = await ApiService.instance.get('/seccion/$id');
    return Seccion.fromJson(data as Map<String, dynamic>);
  }
}
