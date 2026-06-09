/// servidor_service.dart
///
/// Propósito:
///   Servicio de dominio para servidores monitorizados. Provee acceso de solo
///   lectura al listado paginado de servidores registrados en api-py, a la
///   consulta de una página concreta con metadatos de paginación completos, y
///   a la consulta de un servidor individual por ID.
///
/// Capa arquitectónica:
///   Capa de servicios (services/). Actúa como adaptador entre [ServidorProvider]
///   (capa de estado) y [ApiService] (capa de transporte HTTP). No gestiona
///   estado reactivo ni caché: eso pertenece a [ServidorProvider].
///
/// Clases definidas en este fichero:
///   - [ServidorService]: singleton con los métodos [getPage], [getAll] y [getById].
///
/// Patrón singleton:
///   Constructor privado `ServidorService._()` + campo estático `instance`.
///   Mismo patrón que el resto de servicios de dominio.
///
/// Diferencia clave frente a otros servicios del proyecto:
///   [GrupoService], [SeccionService] y [ServicioService] extraen manualmente
///   la clave `data` del envelope paginado y devuelven una lista plana. Este
///   servicio devuelve el envelope completo como `PagedResponse<Servidor>`,
///   preservando los metadatos `total`, `page` y `size`. Eso permite a
///   [ServidorProvider] saber si hay más páginas disponibles y gestionar la
///   carga infinita de [ListaServidoresScreen].
///
/// Nombre del endpoint:
///   api-py expone el recurso como `/servidor` (singular), igual que `/seccion`
///   y `/servicio`, a diferencia del patrón REST habitual de usar plural.
///
/// Formato de respuesta de la API:
///   - `GET /servidor` devuelve un envelope paginado:
///     `{ "data": [...], "total": n, "page": p, "size": s }`.
///     [getPage] lo deserializa completo en `PagedResponse<Servidor>`.
///   - `GET /servidor/{id}` devuelve el objeto servidor directamente (sin envelope).
///
/// Qué NO debe contener este fichero:
///   - Lógica de estado reactivo ni de paginación incremental (responsabilidad
///     de [ServidorProvider]).
///   - Caché de resultados.
///   - Llamadas a otros servicios de dominio.
///   - Operaciones de escritura (creación, edición o borrado de servidores).
library;

import 'package:metrics_servers_mobile/models/model_paged_response.dart';
import 'package:metrics_servers_mobile/models/model_servidor.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';

/// Servicio de acceso a servidores singleton.
///
/// Responsabilidad:
///   Realizar las peticiones HTTP de lectura sobre el recurso `/servidor` y
///   deserializar las respuestas en instancias de [Servidor] o en el envelope
///   tipado `PagedResponse<Servidor>`.
///
/// [ServidorProvider] usa [getPage] como método principal para la paginación
/// incremental. [getAll] es un wrapper de conveniencia para los llamadores
/// que solo necesitan la lista plana de la primera página.
class ServidorService {
  ServidorService._();

  /// Instancia única compartida por toda la aplicación.
  static final ServidorService instance = ServidorService._();

  /// Obtiene una página de servidores con metadatos de paginación completos.
  ///
  /// Realiza `GET /servidor?page={page}&size={size}` y deserializa la respuesta
  /// en `PagedResponse<Servidor>` mediante `PagedResponse.fromJson`, que
  /// recibe una función factory `(item) => Servidor.fromJson(item)` para
  /// deserializar cada elemento del array `data`.
  ///
  /// El `PagedResponse` resultante expone `total`, `page`, `size` y `data`,
  /// lo que permite a [ServidorProvider] calcular si quedan páginas por cargar
  /// (`page * size < total`) sin necesidad de una segunda petición.
  ///
  /// El cast `raw as Map<String, dynamic>` es directo y no defensivo: si
  /// api-py devolviera un formato inesperado se lanzaría [TypeError] en lugar
  /// de [ApiException].
  ///
  /// Throws [ApiException] si [ApiService.get] falla por error de red, timeout
  /// o código HTTP de error.
  Future<PagedResponse<Servidor>> getPage({
    required int page,
    required int size,
  }) async {
    final raw = await ApiService.instance.get(
      '/servidor',
      query: {'page': page.toString(), 'size': size.toString()},
    );
    final map = raw as Map<String, dynamic>;
    return PagedResponse.fromJson(
      map,
      (item) => Servidor.fromJson(item as Map<String, dynamic>),
    );
  }

  /// Obtiene hasta 100 servidores de la primera página como lista plana.
  ///
  /// Wrapper de conveniencia sobre `getPage(page: 0, size: 100)` que descarta
  /// los metadatos de paginación y devuelve solo `PagedResponse.data`.
  ///
  /// Limitación: solo recupera los primeros 100 servidores. Los metadatos
  /// `total` y `size` se descartan, por lo que el llamador no puede saber si
  /// la lista está truncada.
  ///
  /// Throws [ApiException] si la petición subyacente falla.
  // Mantenido para llamadores que necesitan una lista plana sin gestionar paginación.
  Future<List<Servidor>> getAll() async {
    final paged = await getPage(page: 0, size: 100);
    return paged.data;
  }

  /// Obtiene un servidor concreto por su [id].
  ///
  /// Llama a `GET /servidor/{id}`. La respuesta es el objeto servidor
  /// directamente, sin envelope paginado, y se deserializa en [Servidor]
  /// mediante `Servidor.fromJson`.
  ///
  /// El cast `data as Map<String, dynamic>` es directo y no defensivo: si
  /// api-py devolviera un formato inesperado se lanzaría [TypeError] en lugar
  /// de [ApiException].
  ///
  /// Throws [ApiException] si [ApiService.get] falla por error de red, timeout,
  /// 404 (servidor no encontrado) u otro código HTTP de error.
  Future<Servidor> getById(int id) async {
    final data = await ApiService.instance.get('/servidor/$id');
    return Servidor.fromJson(data as Map<String, dynamic>);
  }
}
