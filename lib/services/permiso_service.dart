/// permiso_service.dart
///
/// Propósito:
///   Servicio de dominio para permisos de usuario. Obtiene el catálogo completo
///   de permisos registrados en api-py y devuelve la lista deserializada de
///   instancias [Permiso]. Es la única clase que conoce el endpoint `/permisos`.
///
/// Capa arquitectónica:
///   Capa de servicios (services/). Actúa como adaptador entre [GrupoProvider]
///   (capa de estado) y [ApiService] (capa de transporte HTTP).
///
/// Clases definidas en este fichero:
///   - [PermisoService]: singleton con el método [getAll].
///
/// Patrón singleton:
///   Constructor privado `PermisoService._()` + campo estático `instance`.
///   Mismo patrón que el resto de servicios de dominio.
///
/// Rol de los permisos en la app:
///   Los permisos son un catálogo de referencia. [GrupoProvider] los carga una
///   vez al inicializar y los almacena en caché indexados por ID. La pantalla
///   [DetalleGrupoScreen] usa ese caché para resolver los IDs de permiso que
///   contiene un [Grupo] y mostrar su nombre y ámbito legibles, sin peticiones
///   HTTP adicionales por cada permiso.
///
/// Formato de respuesta de la API:
///   `GET /permisos?page=0&size=100` devuelve un envelope paginado:
///   `{ "data": [...], "total": n, "page": 0, "size": 100 }`.
///   [getAll] extrae únicamente la clave `data` y deserializa cada elemento
///   en un [Permiso] mediante `Permiso.fromJson`.
///
/// Estrategia de paginación:
///   Se solicita siempre la página 0 con tamaño 100. Asume implícitamente que
///   el número de permisos del sistema no supera 100. No hay iteración de páginas
///   ni indicación de truncado si el total supera ese límite.
///
/// Qué NO debe contener este fichero:
///   - Lógica de estado reactivo (ChangeNotifier, streams).
///   - Caché de resultados (responsabilidad de [GrupoProvider]).
///   - Consulta de un permiso individual por ID.
///   - Llamadas a otros servicios de dominio.
library;

import 'package:metrics_servers_mobile/models/model_permiso.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';

/// Servicio de acceso al catálogo de permisos singleton.
///
/// Responsabilidad:
///   Realizar la petición HTTP de lectura sobre el recurso `/permisos` y
///   deserializar la respuesta en una lista de [Permiso].
///
/// Usado exclusivamente por [GrupoProvider], que invoca [getAll] durante la
/// carga inicial para construir el mapa de permisos (`Map<int, Permiso>`)
/// que usa [DetalleGrupoScreen] para resolver nombres de permisos.
class PermisoService {
  PermisoService._();

  /// Instancia única compartida por toda la aplicación.
  static final PermisoService instance = PermisoService._();

  /// Obtiene hasta 100 permisos de api-py (página 0, tamaño 100).
  ///
  /// La respuesta es un envelope paginado; este método extrae solo la clave
  /// `data` y deserializa cada elemento en un [Permiso] mediante
  /// `Permiso.fromJson`.
  ///
  /// El guard `?? []` sobre `map['data']` protege contra una clave `data`
  /// ausente o con valor `null` en la respuesta, devolviendo una lista vacía
  /// en lugar de lanzar un error de deserialización.
  ///
  /// El cast `raw as Map<String, dynamic>` es directo y no defensivo: si
  /// api-py devolviera un formato inesperado (p. ej. un array en lugar del
  /// envelope) se lanzaría [TypeError] en lugar de [ApiException].
  ///
  /// Limitación: con `page=0, size=100` solo se recuperan los primeros 100
  /// permisos. Si el catálogo supera ese número, los excedentes no se cargan
  /// y [GrupoProvider] no podrá resolver sus IDs, mostrando el fallback
  /// `'#id'` en [DetalleGrupoScreen].
  ///
  /// Throws [ApiException] si [ApiService.get] falla por error de red, timeout
  /// o código HTTP de error.
  Future<List<Permiso>> getAll() async {
    final raw = await ApiService.instance.get(
      '/permisos',
      query: {'page': '0', 'size': '100'},
    );
    final map = raw as Map<String, dynamic>;
    final items = map['data'] as List<dynamic>? ?? [];
    return items
        .map((e) => Permiso.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
