/// grupo_service.dart
///
/// Propósito:
///   Servicio de dominio para grupos de usuarios. Provee acceso de solo lectura
///   al catálogo de grupos registrados en api-py: obtención del listado completo
///   y consulta de un grupo concreto por ID. Traduce las respuestas HTTP en
///   instancias de [Grupo].
///
/// Capa arquitectónica:
///   Capa de servicios (services/). Actúa como adaptador entre [GrupoProvider]
///   (capa de estado) y [ApiService] (capa de transporte HTTP). No gestiona
///   estado reactivo ni caché: eso pertenece a [GrupoProvider].
///
/// Clases definidas en este fichero:
///   - [GrupoService]: singleton con los métodos [getAll] y [getById].
///
/// Patrón singleton:
///   Constructor privado `GrupoService._()` + campo estático `instance`.
///   Mismo patrón que [ApiService] y [AuthService].
///
/// Formato de respuesta de la API:
///   - `GET /grupos` devuelve un envelope paginado:
///     `{ "data": [...], "total": n, "page": 0, "size": 100 }`.
///     [getAll] extrae únicamente la clave `data`.
///   - `GET /grupos/{id}` devuelve el objeto grupo directamente (sin envelope).
///
/// Estrategia de paginación en [getAll]:
///   Se solicita siempre la página 0 con tamaño 100. Asume implícitamente que
///   el número de grupos en el sistema no supera 100. No hay iteración de páginas
///   ni indicación visual de truncado si el total supera ese límite.
///
/// Qué NO debe contener este fichero:
///   - Lógica de estado reactivo (ChangeNotifier, streams).
///   - Caché de resultados (responsabilidad de [GrupoProvider]).
///   - Llamadas a otros servicios de dominio.
///   - Operaciones de escritura (creación, edición o borrado de grupos).
library;

import 'package:metrics_servers_mobile/models/model_grupo.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';

/// Servicio de acceso a grupos singleton.
///
/// Responsabilidad:
///   Realizar las peticiones HTTP de lectura sobre el recurso `/grupos` y
///   deserializar las respuestas en instancias de [Grupo].
///
/// Usado por [GrupoProvider], que lo invoca para poblar su estado interno
/// y exponer los datos desserializados al árbol de widgets.
class GrupoService {
  GrupoService._();

  /// Instancia única compartida por toda la aplicación.
  static final GrupoService instance = GrupoService._();

  /// Obtiene hasta 100 grupos de api-py (página 0, tamaño 100).
  ///
  /// La respuesta es un envelope paginado; este método extrae solo la clave
  /// `data` y deserializa cada elemento en un [Grupo] mediante
  /// `Grupo.fromJson`.
  ///
  /// El guard `?? []` sobre `map['data']` protege contra una clave `data`
  /// ausente o con valor `null` en la respuesta, devolviendo una lista vacía
  /// en lugar de lanzar un error de deserialización.
  ///
  /// Limitación: con los parámetros `page=0, size=100` solo se recuperan los
  /// primeros 100 grupos. Si el total supera ese número, los grupos restantes
  /// no se cargan y no hay ningún aviso de truncado.
  ///
  /// Throws [ApiException] si [ApiService.get] falla por error de red, timeout
  /// o código HTTP de error.
  Future<List<Grupo>> getAll() async {
    final raw = await ApiService.instance.get(
      '/grupos',
      query: {'page': '0', 'size': '100'},
    );
    final map = raw as Map<String, dynamic>;
    final items = map['data'] as List<dynamic>? ?? [];
    return items.map((e) => Grupo.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Obtiene un grupo concreto por su [id].
  ///
  /// Llama a `GET /grupos/{id}`. La respuesta es el objeto grupo directamente,
  /// sin envelope paginado, y se deserializa en [Grupo] mediante `Grupo.fromJson`.
  ///
  /// El cast `data as Map<String, dynamic>` es directo y no defensivo: si
  /// api-py devolviera un formato inesperado se lanzaría [TypeError] en lugar
  /// de [ApiException].
  ///
  /// Throws [ApiException] si [ApiService.get] falla por error de red, timeout,
  /// 404 (grupo no encontrado) u otro código HTTP de error.
  Future<Grupo> getById(int id) async {
    final data = await ApiService.instance.get('/grupos/$id');
    return Grupo.fromJson(data as Map<String, dynamic>);
  }
}
