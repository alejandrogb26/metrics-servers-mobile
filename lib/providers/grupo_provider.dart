/// grupo_provider.dart
///
/// Propósito:
///   Define [GrupoProvider], el provider que gestiona el catálogo de grupos y
///   el catálogo completo de permisos disponibles en el sistema. Ambos recursos
///   se cargan juntos porque la pantalla de gestión de grupos necesita los dos
///   simultáneamente: los grupos para listarlos y editarlos, y los permisos para
///   mostrar el selector de permisos al editar un grupo.
///
/// Capa arquitectónica:
///   Capa de presentación — providers (providers/).
///   Actúa como caché en memoria de los datos obtenidos desde api-py mediante
///   [GrupoService] y [PermisoService]. No contiene lógica HTTP directa.
///
/// Responsabilidades principales:
///   - Obtener grupos y permisos en paralelo desde api-py (una sola vez por
///     sesión gracias al flag [_loaded]).
///   - Exponer la lista de grupos ([grupos]) y el catálogo de permisos ([permisos])
///     al árbol de widgets.
///   - Proveer [getPermisoById] para resolver los IDs de permiso almacenados en
///     [GrupoPermissionMap] a objetos [Permiso] completos.
///   - Permitir la invalidación explícita del caché ([invalidate]) para forzar
///     una recarga tras operaciones de escritura (crear/editar/eliminar grupo).
///
/// Estrategia de caché:
///   [GrupoProvider] implementa un caché de "carga única": los datos se cargan
///   la primera vez que se llama a [fetchAll] y no se vuelven a pedir hasta que
///   se invoca [invalidate]. No hay expiración por tiempo. Esta estrategia es
///   adecuada para catálogos que cambian raramente (grupos y permisos del sistema).
///
/// Estado de carga — ausencia de flag explícito:
///   A diferencia de otros providers de la app, [GrupoProvider] no expone un
///   estado "loading" dedicado. Durante la carga, `grupos` está vacío, `error`
///   es null y `_loaded` es false. La UI infiere el estado de carga de esta
///   combinación. `notifyListeners()` solo se llama al finalizar (éxito o error),
///   no al inicio de la carga.
///
/// Qué NO debe contener este fichero:
///   - Llamadas HTTP directas (pertenecen a GrupoService / PermisoService).
///   - Lógica de navegación.
///   - Lógica de presentación (formateo de nombres, colores por tipo, etc.).
///   - Persistencia en disco del catálogo de grupos.
library;

import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/models/model_grupo.dart';
import 'package:metrics_servers_mobile/models/model_permiso.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';
import 'package:metrics_servers_mobile/services/grupo_service.dart';
import 'package:metrics_servers_mobile/services/permiso_service.dart';

/// Provider de grupos y permisos para la pantalla de administración.
///
/// Responsabilidad:
///   Carga y mantiene en memoria el catálogo de grupos ([Grupo]) y el catálogo
///   completo de permisos ([Permiso]) disponibles en el sistema. Implementa
///   el patrón [ChangeNotifier] para notificar a los widgets consumidores cuando
///   los datos están disponibles o cuando ocurre un error.
///
/// Relación con otros módulos:
///   - [GrupoService]: obtiene la lista de [Grupo] desde api-py.
///   - [PermisoService]: obtiene el catálogo de [Permiso] desde api-py.
///   - [GrupoPermissionMap]: sus listas de IDs se resuelven a objetos [Permiso]
///     completos mediante [getPermisoById], necesario para el editor de grupos.
///   - Pantalla de gestión de grupos: consumidor principal; lista grupos y edita
///     sus permisos usando el catálogo de [permisos].
///
/// Ciclo de vida del estado:
///   1. Inicial: `_grupos = []`, `_permisos = []`, `_loaded = false`, `_error = null`.
///   2. Tras [fetchAll] exitoso: listas pobladas, `_loaded = true`.
///   3. Tras [fetchAll] con error: listas vacías, `_error` con mensaje.
///   4. Tras [invalidate]: vuelta al estado inicial (1), próximo [fetchAll] recarga.
class GrupoProvider with ChangeNotifier {
  /// Lista de grupos cargada desde api-py. Vacía hasta que [fetchAll] completa.
  List<Grupo> _grupos = [];

  /// Catálogo completo de permisos del sistema. Vacío hasta que [fetchAll] completa.
  /// Se usa para resolver los IDs de permiso de [GrupoPermissionMap] a objetos
  /// [Permiso] completos mediante [getPermisoById].
  List<Permiso> _permisos = [];

  /// Flag de caché: `true` si los datos ya fueron cargados exitosamente.
  /// Evita peticiones redundantes a api-py en sucesivas llamadas a [fetchAll].
  /// Solo se resetea al llamar a [invalidate].
  bool _loaded = false;

  /// Mensaje del último error de carga. `null` si no hay error.
  String? _error;

  // ── Getters públicos ────────────────────────────────────────────────────────

  /// Lista de grupos disponibles en el sistema.
  List<Grupo> get grupos => _grupos;

  /// Catálogo completo de permisos del sistema.
  List<Permiso> get permisos => _permisos;

  /// Mensaje del último error de carga. `null` si no ocurrió error.
  String? get error => _error;

  // ── Carga de datos ──────────────────────────────────────────────────────────

  /// Carga grupos y permisos desde api-py en paralelo.
  ///
  /// Si los datos ya están cargados ([_loaded] es `true`), retorna inmediatamente
  /// sin hacer ninguna petición HTTP. Para forzar una recarga, llamar a
  /// [invalidate] antes de [fetchAll].
  ///
  /// Las dos peticiones HTTP se ejecutan en paralelo mediante [Future.wait],
  /// reduciendo el tiempo de carga respecto a ejecutarlas secuencialmente.
  /// El orden de los futures en el array determina el índice de acceso a los
  /// resultados: `results[0]` → grupos, `results[1]` → permisos.
  ///
  /// Gestión de errores:
  ///   - [ApiException]: error HTTP conocido de api-py (401, 403, 500, etc.).
  ///   - Cualquier otro error: fallo de red, timeout, parse de JSON, etc.
  ///   En ambos casos `_grupos` y `_permisos` quedan vacíos y `_loaded` permanece
  ///   `false`, por lo que el siguiente [fetchAll] volverá a intentar la carga.
  ///
  /// Nota: `notifyListeners()` se llama una sola vez al final (no al inicio),
  /// por lo que la UI no recibe notificación del estado "en carga". Ver nota
  /// de diseño en la cabecera del fichero.
  Future<void> fetchAll() async {
    // Caché: si ya está cargado, no repetir las peticiones HTTP.
    if (_loaded) return;
    _error = null;
    try {
      // Peticiones paralelas: grupos y permisos son independientes entre sí.
      // El orden del array debe coincidir con los índices de acceso a results.
      final results = await Future.wait([
        GrupoService.instance.getAll(),
        PermisoService.instance.getAll(),
      ]);
      _grupos = results[0] as List<Grupo>;
      _permisos = results[1] as List<Permiso>;
      _loaded = true;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Error inesperado al cargar grupos';
    }
    notifyListeners();
  }

  // ── Consultas al catálogo ───────────────────────────────────────────────────

  /// Busca y devuelve el [Permiso] con el [id] indicado en el catálogo cargado.
  ///
  /// Devuelve `null` si el catálogo no contiene ningún permiso con ese ID
  /// (p. ej. si [fetchAll] aún no completó, o si el ID no existe en api-py).
  ///
  /// Se usa principalmente para resolver los IDs enteros almacenados en
  /// [GrupoPermissionMap.global] y [GrupoPermissionMap.sections] a objetos
  /// [Permiso] completos, necesarios para mostrar nombre y ámbito en la UI.
  ///
  /// Usa un bloque try-catch en lugar de `firstWhereOrNull` porque `firstWhere`
  /// lanza [StateError] cuando no encuentra coincidencia. El catch captura ese
  /// error y retorna `null` de forma segura.
  Permiso? getPermisoById(int id) {
    try {
      return _permisos.firstWhere((p) => p.id == id);
    } catch (_) {
      // StateError de firstWhere cuando no hay coincidencia: se trata como
      // "permiso no encontrado" en lugar de propagar el error.
      return null;
    }
  }

  // ── Invalidación de caché ───────────────────────────────────────────────────

  /// Invalida el caché forzando una recarga completa en el próximo [fetchAll].
  ///
  /// Debe llamarse tras cualquier operación de escritura sobre grupos (crear,
  /// editar, eliminar) para que la UI refleje los datos actualizados de api-py
  /// en lugar de los datos obsoletos del caché.
  ///
  /// Limpia las listas y el error, resetea [_loaded] a `false` y notifica a los
  /// listeners para que la UI transite al estado vacío antes de la recarga.
  /// El patrón habitual de uso es: `invalidate()` seguido de `fetchAll()`.
  void invalidate() {
    _loaded = false;
    _grupos = [];
    _permisos = [];
    _error = null;
    notifyListeners();
  }
}
