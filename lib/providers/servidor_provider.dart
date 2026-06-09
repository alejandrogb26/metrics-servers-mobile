/// servidor_provider.dart
///
/// Propósito:
///   Define [ServidorProvider], el provider que gestiona la lista paginada de
///   servidores, los catálogos de resolución (servicios y secciones) y la
///   búsqueda client-side sobre los datos ya cargados.
///
/// Capa arquitectónica:
///   Capa de presentación — providers (providers/).
///   Actúa como caché en memoria de los datos obtenidos desde api-py mediante
///   [ServidorService], [ServicioService] y [SeccionService]. No contiene
///   lógica HTTP directa.
///
/// Responsabilidades principales:
///   - Cargar la primera página de servidores ([loadFirstPage]) con guardia
///     de re-entrada y de back-navigation.
///   - Cargar páginas adicionales acumulativamente ([loadNextPage]) para
///     implementar scroll infinito.
///   - Precargar los catálogos de [Servicio] y [Seccion] como mapas de lookup
///     por ID ([preloadCaches]), permitiendo a la UI resolver las claves
///     foráneas de [Servidor] sin peticiones adicionales por servidor.
///   - Proveer búsqueda client-side ([search]) sobre los servidores ya cargados.
///   - Permitir la invalidación del estado de paginación ([invalidate]) sin
///     borrar los catálogos, ya que estos cambian con mucha menos frecuencia.
///
/// Paginación — diseño de doble estado de carga:
///   El provider expone dos flags de carga diferenciados:
///   - [isLoading]: activo durante la carga de la primera página. La UI muestra
///     un indicador de carga a pantalla completa.
///   - [isLoadingMore]: activo durante la carga de páginas adicionales. La UI
///     muestra un spinner inline en la parte inferior de la lista.
///   Esta separación permite distintos patrones de UX según si es la carga
///   inicial o una extensión de una lista ya visible.
///
/// Cachés de resolución:
///   [Servidor] almacena las relaciones como IDs enteros ([Servidor.seccion],
///   [Servidor.servicios]). Para mostrar nombres y logos, la UI necesita resolver
///   esos IDs a objetos completos. [ServidorProvider] mantiene dos mapas de
///   resolución `Map<int, T>` que permiten lookups en O(1):
///   - [serviciosCache]: `id → Servicio`
///   - [seccionesCache]: `id → Seccion`
///
/// Búsqueda client-side:
///   [search] filtra únicamente sobre los servidores ya cargados en memoria.
///   Si solo se han cargado las primeras páginas, la búsqueda no cubre el
///   conjunto completo de servidores del sistema. No realiza peticiones a
///   api-py; es una operación síncrona y local.
///
/// Qué NO debe contener este fichero:
///   - Llamadas HTTP directas (pertenecen a los servicios correspondientes).
///   - Lógica de navegación.
///   - Lógica de presentación (formateo de nombres, colores de estado, etc.).
///   - Búsqueda server-side (actualmente no implementada).
library;

import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/models/model_seccion.dart';
import 'package:metrics_servers_mobile/models/model_servicio.dart';
import 'package:metrics_servers_mobile/models/model_servidor.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';
import 'package:metrics_servers_mobile/services/seccion_service.dart';
import 'package:metrics_servers_mobile/services/servicio_service.dart';
import 'package:metrics_servers_mobile/services/servidor_service.dart';

/// Provider de la lista de servidores con paginación incremental y catálogos.
///
/// Responsabilidad:
///   Mantiene en memoria la lista acumulada de [Servidor] cargados desde api-py,
///   los catálogos de resolución de IDs y el estado de paginación. Implementa
///   el patrón [ChangeNotifier] para notificar cambios a los widgets consumidores.
///
/// Ciclo de vida del estado de paginación:
///   1. Inicial: listas vacías, `_isLoading = false`, `_hasNext = false`.
///   2. [loadFirstPage] invocado: `_isLoading = true` → notifica → carga página 0.
///   3. Éxito: `_servidores` poblado, `_currentPage = 0`, `_hasNext` según API.
///   4. [loadNextPage] invocado: `_isLoadingMore = true` → añade página N+1.
///   5. [invalidate]: reset completo del estado de paginación (sin borrar cachés).
///
/// Relación con otros módulos:
///   - [ServidorService]: obtiene páginas de servidores desde api-py.
///   - [ServicioService]: obtiene el catálogo de servicios para [serviciosCache].
///   - [SeccionService]: obtiene el catálogo de secciones para [seccionesCache].
///   - Pantalla de listado de servidores: consumidor principal; muestra la lista,
///     activa la paginación y usa los cachés para resolver IDs.
///   - [Servidor.servicios] / [Servidor.seccion]: sus IDs se resuelven usando
///     los mapas [serviciosCache] y [seccionesCache] respectivamente.
class ServidorProvider with ChangeNotifier {
  /// Lista acumulada de servidores cargados. Cada llamada a [loadNextPage]
  /// añade los servidores de la nueva página al final de esta lista mediante
  /// el operador spread, sin reemplazar los ya existentes.
  List<Servidor> _servidores = [];

  /// Caché de servicios indexada por ID: `Servicio.id → Servicio`.
  /// Permite a la UI resolver los IDs de [Servidor.servicios] en O(1) sin
  /// peticiones HTTP adicionales por servidor. Construida en [preloadCaches].
  Map<int, Servicio> _serviciosCache = {};

  /// Caché de secciones indexada por ID: `Seccion.id → Seccion`.
  /// Permite a la UI resolver [Servidor.seccion] en O(1). Construida en [preloadCaches].
  Map<int, Seccion> _seccionesCache = {};

  /// `true` durante la carga de la primera página. Diferenciado de
  /// [_isLoadingMore] para que la UI pueda mostrar un spinner de pantalla
  /// completa en la carga inicial en lugar de un spinner inline.
  bool _isLoading = false;

  /// `true` durante la carga de páginas adicionales (scroll infinito).
  /// La UI lo usa para mostrar un indicador inline al final de la lista.
  bool _isLoadingMore = false;

  /// `true` si api-py indica que existe al menos una página más.
  /// Se actualiza tras cada carga de página con el valor de [PagedResponse.hasNext].
  bool _hasNext = false;

  /// Índice de la última página cargada exitosamente (base 0).
  /// [loadNextPage] incrementa este valor en 1 para solicitar la siguiente página.
  int _currentPage = 0;

  /// Mensaje del último error de carga. `null` si la última operación fue exitosa.
  String? _error;

  /// Número de servidores por página. Constante compartida entre [loadFirstPage]
  /// y [loadNextPage] para garantizar consistencia en todas las peticiones.
  static const int _pageSize = 20;

  // ── Getters públicos ────────────────────────────────────────────────────────

  /// Lista acumulada de servidores cargados hasta la página actual.
  List<Servidor> get servidores => _servidores;

  /// Caché `id → Servicio` para resolución O(1) de [Servidor.servicios].
  Map<int, Servicio> get serviciosCache => _serviciosCache;

  /// Caché `id → Seccion` para resolución O(1) de [Servidor.seccion].
  Map<int, Seccion> get seccionesCache => _seccionesCache;

  /// `true` durante la carga de la primera página (spinner de pantalla completa).
  bool get isLoading => _isLoading;

  /// `true` durante la carga de páginas adicionales (spinner inline al pie de lista).
  bool get isLoadingMore => _isLoadingMore;

  /// `true` si hay páginas pendientes de cargar según la última respuesta de api-py.
  bool get hasNext => _hasNext;

  /// Mensaje del último error. `null` si no hay error activo.
  String? get error => _error;

  // ── Primera página ──────────────────────────────────────────────────────────

  /// Carga la primera página de servidores desde api-py (página 0).
  ///
  /// Guarda de re-entrada y back-navigation:
  ///   Retorna inmediatamente si `_isLoading` es `true` (petición en curso) o si
  ///   `_servidores` ya contiene datos. La segunda condición cubre el caso de
  ///   back-navigation: cuando el usuario vuelve a la pantalla de servidores,
  ///   esta llama a [loadFirstPage] de nuevo, pero los datos ya están en memoria
  ///   y no se realizan peticiones redundantes a api-py.
  ///
  /// Establece [_currentPage] a `0` y actualiza [_hasNext] según la respuesta.
  /// En error, `_servidores` queda vacío y `_hasNext` permanece `false`.
  Future<void> loadFirstPage() async {
    // Guard: ya cargando, o datos presentes (cubre back-navigation).
    if (_isLoading || _servidores.isNotEmpty) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final paged = await ServidorService.instance.getPage(
        page: 0,
        size: _pageSize,
      );
      _servidores = paged.data;
      _currentPage = 0;
      _hasNext = paged.hasNext;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Páginas adicionales ─────────────────────────────────────────────────────

  /// Carga la siguiente página de servidores y la acumula en [servidores].
  ///
  /// Implementa scroll infinito: el widget de lista llama a este método cuando
  /// el usuario se aproxima al final de la lista visible.
  ///
  /// Guardas:
  ///   - `!_hasNext`: no hay más páginas según la última respuesta de api-py.
  ///   - `_isLoadingMore`: ya hay una carga de página adicional en curso.
  ///   - `_isLoading`: la primera página aún no terminó de cargar.
  ///
  /// Los nuevos servidores se añaden al final de [_servidores] mediante spread
  /// (`[..._servidores, ...paged.data]`), creando una nueva lista en lugar de
  /// mutar la existente, lo que es compatible con el sistema de notificación
  /// de Flutter que detecta cambios por referencia.
  Future<void> loadNextPage() async {
    if (!_hasNext || _isLoadingMore || _isLoading) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final nextPage = _currentPage + 1;
      final paged = await ServidorService.instance.getPage(
        page: nextPage,
        size: _pageSize,
      );
      // Acumulación mediante spread: preserva los servidores de páginas previas
      // y añade los nuevos al final, sin mutar la lista existente.
      _servidores = [..._servidores, ...paged.data];
      _currentPage = nextPage;
      _hasNext = paged.hasNext;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // ── Catálogos de resolución ─────────────────────────────────────────────────

  /// Precarga los catálogos de [Servicio] y [Seccion] como mapas de lookup por ID.
  ///
  /// Guarda de re-carga:
  ///   Solo omite la carga si AMBOS cachés están ya poblados. Si uno de los dos
  ///   está vacío (p. ej. por un fallo parcial previo), ambos se recargan.
  ///
  /// Las listas obtenidas de api-py se transforman en `Map<int, T>` usando
  /// la sintaxis de colección-for de Dart (`{for (final s in list) s.id: s}`),
  /// lo que permite lookups en O(1) frente al O(n) de una búsqueda en lista.
  ///
  /// Las dos peticiones se ejecutan secuencialmente (no en paralelo). Esto es
  /// más simple pero ligeramente más lento que usar [Future.wait]; el impacto
  /// es mínimo dado que los catálogos se cargan una sola vez por sesión.
  ///
  /// Advertencia: no tiene bloque try-catch propio. Si cualquiera de los dos
  /// servicios lanza una excepción, esta se propaga al llamador. La pantalla
  /// de servidores debe gestionar ese error si llama a este método directamente.
  Future<void> preloadCaches() async {
    // Omite la recarga solo si ambos catálogos ya están en memoria.
    if (_serviciosCache.isNotEmpty && _seccionesCache.isNotEmpty) return;

    final servicios = await ServicioService.instance.getAll();
    // Convierte la lista a mapa para lookups O(1) por ID en la UI.
    _serviciosCache = {for (final s in servicios) s.id: s};

    final secciones = await SeccionService.instance.getAll();
    _seccionesCache = {for (final s in secciones) s.id: s};

    notifyListeners();
  }

  // ── Búsqueda client-side ────────────────────────────────────────────────────

  /// Filtra los servidores cargados en memoria según una cadena de búsqueda.
  ///
  /// Busca en los campos: [Servidor.hostname], [Servidor.dns],
  /// [Servidor.serverId] y [Servidor.prettyOs] (este último con guard de nulo).
  /// La comparación es insensible a mayúsculas (todo a minúsculas antes de comparar).
  ///
  /// Limitación importante:
  ///   La búsqueda opera únicamente sobre las páginas ya cargadas en [servidores].
  ///   Si se han cargado 20 de 150 servidores, la búsqueda solo examina esos 20.
  ///   Para cubrir el conjunto completo sería necesaria una búsqueda server-side
  ///   (endpoint de api-py con parámetro de query), que actualmente no está
  ///   implementada.
  ///
  /// Devuelve una nueva lista filtrada; no modifica [_servidores] ni notifica.
  /// Es una operación síncrona.
  List<Servidor> search(String query) {
    final q = query.toLowerCase();
    return _servidores.where((s) {
      return s.hostname.toLowerCase().contains(q) ||
          s.dns.toLowerCase().contains(q) ||
          s.serverId.toLowerCase().contains(q) ||
          (s.prettyOs?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  // ── Invalidación ───────────────────────────────────────────────────────────

  /// Invalida el estado de paginación forzando una recarga completa en el
  /// próximo [loadFirstPage].
  ///
  /// Resetea: lista de servidores, flags de carga, página actual, flag hasNext
  /// y mensaje de error. Llama a [notifyListeners] para que la UI transite
  /// al estado vacío.
  ///
  /// Los cachés de [serviciosCache] y [seccionesCache] NO se borran, ya que los
  /// catálogos de servicios y secciones cambian con mucha menos frecuencia que
  /// la lista de servidores. Borrarlos innecesariamente implicaría peticiones
  /// adicionales a api-py tras cada invalidación.
  ///
  /// Debe llamarse tras operaciones de escritura sobre servidores (añadir,
  /// editar, eliminar) o cuando se desee forzar una actualización desde api-py.
  void invalidate() {
    _servidores = [];
    _isLoading = false;
    _isLoadingMore = false;
    _hasNext = false;
    _currentPage = 0;
    _error = null;
    notifyListeners();
  }
}
