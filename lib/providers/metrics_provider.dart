/// metrics_provider.dart
///
/// Propósito:
///   Define [MetricsProvider], el provider responsable de obtener y mantener
///   actualizada la serie temporal de métricas de un servidor concreto mediante
///   polling periódico a api-py. Gestiona el ciclo de vida completo del timer,
///   el rango de tiempo visualizado y el estado de carga/error para la UI.
///
/// Capa arquitectónica:
///   Capa de presentación — providers (providers/).
///   Actúa como intermediario entre [MetricsService] (capa de datos) y las
///   pantallas de métricas (capa de UI). No contiene lógica HTTP directa.
///
/// Responsabilidades principales:
///   - Iniciar y detener el polling periódico de métricas para un servidor.
///   - Ejecutar una carga inmediata al arrancar el polling (sin esperar el primer
///     tick del timer).
///   - Gestionar el rango de tiempo de visualización ([rangeMinutes]) y recargar
///     los datos cuando cambia.
///   - Exponer la serie temporal ([points]), el estado de carga y los errores
///     a la UI mediante [ChangeNotifier].
///   - Detener el polling limpiamente ante una respuesta 401 (sesión expirada),
///     coordinándose con [AuthProvider] que maneja la navegación al login.
///
/// Mecanismo de polling:
///   Usa [Timer.periodic] con intervalo de 30 segundos. Cuando se llama a
///   [startPolling], se ejecuta una carga inmediata ([_fetch]) y después el
///   timer dispara [_fetch] cada 30 segundos mientras la pantalla esté activa.
///   El timer se cancela en [stopPolling] (navegación) y en [dispose] (destrucción
///   del provider), previniendo llamadas HTTP o notificaciones tras desmontar la UI.
///
/// Coordinación con AuthProvider ante 401:
///   Si durante el polling api-py devuelve 401, el flujo es:
///     1. [ApiService] recibe el 401, llama a `onUnauthorized` (= [AuthProvider._invalidateSession]),
///        que resetea la sesión y notifica a sus listeners.
///     2. [ApiService] lanza [ApiException] con `statusCode == 401`.
///     3. [MetricsProvider._fetch] captura el 401, llama a [stopPolling] (limpia
///        el timer sin notificar) y sale del catch.
///     4. El bloque `finally` ejecuta `notifyListeners()`, actualizando la UI
///        de métricas con el estado limpio.
///   La navegación al login es responsabilidad de AuthProvider (paso 1), no de
///   este provider. Por eso no se muestra ningún mensaje de error al usuario.
///
/// Qué NO debe contener este fichero:
///   - Llamadas HTTP directas (pertenecen a MetricsService).
///   - Lógica de formateo de valores de métricas (bytes → GB, segundos → h:m:s).
///   - Lógica de navegación.
///   - Gestión de sesión o token (responsabilidad de AuthProvider / ApiService).
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/models/metrics/model_metrics.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';
import 'package:metrics_servers_mobile/services/metrics_service.dart';

/// Provider de métricas con polling periódico para la pantalla de monitorización.
///
/// Responsabilidad:
///   Mantiene actualizada la serie temporal de [MetricPoint] de un servidor
///   concreto, disparando una petición HTTP a api-py cada 30 segundos mientras
///   la pantalla de métricas está activa.
///
/// Ciclo de vida del estado:
///   1. Sin servidor activo: `_points = []`, `_loading = false`, `_timer = null`.
///   2. Tras [startPolling]: carga inmediata → `_loading = true` → datos o error.
///   3. Durante el polling: cada 30 s repite el ciclo loading → datos.
///   4. Tras [changeRange]: `_points = []` + notifica → nueva carga inmediata.
///   5. Tras [stopPolling] / 401 / [dispose]: estado completamente limpio.
///
/// Identificador de servidor:
///   [_currentServerId] almacena el `serverId` de tipo [String] (el identificador
///   de aplicación de [Servidor], no su clave primaria numérica `id`). Es el
///   mismo identificador que usa [MetricsService] para construir la URL del
///   endpoint de métricas de api-py.
///
/// Relación con otros módulos:
///   - [MetricsService]: ejecuta la petición HTTP y deserializa los [MetricPoint].
///   - [ApiService]: gestiona el 401 llamando a `onUnauthorized` antes de lanzar
///     [ApiException], lo que coordina la invalidación de sesión.
///   - [AuthProvider]: su `_invalidateSession` es invocado por [ApiService] ante
///     un 401 antes de que este provider lo capture.
///   - Pantalla de métricas: inicia el polling en su activación y lo detiene al
///     salir. Observa [points], [loading] y [error].
class MetricsProvider with ChangeNotifier {
  /// Serie temporal de puntos de métrica del servidor actualmente monitorizado.
  /// Se reemplaza completa en cada ciclo de polling (no se acumula).
  List<MetricPoint> _points = [];

  /// `true` durante la ejecución de [_fetch]. Permite a la UI mostrar un
  /// indicador de carga mientras se espera la respuesta de api-py.
  bool _loading = false;

  /// Mensaje del último error de carga. `null` si la última petición fue exitosa
  /// o si el polling no ha comenzado. Se limpia al inicio de cada [_fetch].
  String? _error;

  /// `serverId` del servidor cuyas métricas se están consultando actualmente.
  /// `null` si el polling no está activo. Usado como guardia de idempotencia
  /// en [startPolling] para evitar reinicios innecesarios.
  String? _currentServerId;

  /// Ventana de tiempo de la consulta de métricas, en minutos hacia atrás desde
  /// el momento actual. Por defecto 60 minutos (última hora).
  int _rangeMinutes = 60;

  /// Timer del polling periódico. `null` si el polling está detenido.
  /// Se cancela en [stopPolling] y en [dispose] para evitar fugas de memoria
  /// y callbacks sobre widgets ya destruidos.
  Timer? _timer;

  // ── Getters públicos ────────────────────────────────────────────────────────

  /// Serie temporal de puntos de métrica, ordenada cronológicamente.
  /// Puede estar vacía si el polling no ha cargado datos aún o si no hay
  /// métricas para el rango seleccionado.
  List<MetricPoint> get points => _points;

  /// `true` mientras hay una petición HTTP de métricas en curso.
  bool get loading => _loading;

  /// Mensaje del último error de carga. `null` si no hay error activo.
  String? get error => _error;

  /// Rango de tiempo actualmente configurado para la consulta, en minutos.
  /// Expuesto para que la UI pueda inicializar el selector de rango con el
  /// valor correcto.
  int get rangeMinutes => _rangeMinutes;

  // ── Control del polling ─────────────────────────────────────────────────────

  /// Inicia el polling periódico de métricas para el servidor indicado.
  ///
  /// Si ya se está haciendo polling del mismo servidor con el mismo rango,
  /// retorna inmediatamente sin reiniciar nada. Esta guardia de idempotencia
  /// evita que reconstrucciones del widget reinicien el polling innecesariamente.
  ///
  /// Al iniciar un nuevo polling:
  ///   1. Cancela el timer anterior si existía.
  ///   2. Limpia los puntos del servidor anterior.
  ///   3. Ejecuta [_fetch] inmediatamente (sin esperar el primer tick).
  ///   4. Inicia [Timer.periodic] de 30 segundos para sucesivas actualizaciones.
  ///
  /// Parámetros:
  ///   - [serverId]: identificador de aplicación del servidor (`Servidor.serverId`).
  ///   - [rangeMinutes]: ventana de tiempo en minutos (por defecto 60).
  Future<void> startPolling(String serverId, {int rangeMinutes = 60}) async {
    // Guardia de idempotencia: no reiniciar si ya se está monitorizando el
    // mismo servidor con el mismo rango. Cubre rebuilds del widget llamador.
    if (_currentServerId == serverId && _rangeMinutes == rangeMinutes) return;
    _currentServerId = serverId;
    _rangeMinutes = rangeMinutes;
    _points = [];
    // Cancela cualquier polling activo de un servidor anterior.
    _timer?.cancel();
    // Carga inmediata: el usuario ve datos sin esperar 30 segundos.
    await _fetch();
    // Timer periódico: actualiza las métricas cada 30 segundos.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetch());
  }

  /// Cambia el rango de tiempo de visualización y recarga los datos.
  ///
  /// Si el nuevo rango es igual al actual, retorna inmediatamente.
  /// Al cambiar el rango:
  ///   1. Actualiza [_rangeMinutes].
  ///   2. Limpia [_points] y notifica (la UI transita a estado vacío/carga).
  ///   3. Ejecuta [_fetch] inmediatamente con el nuevo rango.
  ///   El timer existente continúa activo y usará el nuevo rango en sucesivos
  ///   ticks, ya que [_rangeMinutes] se lee en el momento de cada [_fetch].
  ///
  /// Parámetros:
  ///   - [minutes]: nuevo rango en minutos (p. ej. 30, 60, 120, 1440).
  Future<void> changeRange(int minutes) async {
    if (_rangeMinutes == minutes) return;
    _rangeMinutes = minutes;
    // Limpia los puntos del rango anterior antes de notificar, para que la UI
    // no muestre brevemente datos obsoletos de un rango diferente.
    _points = [];
    notifyListeners();
    await _fetch();
  }

  /// Detiene el polling y resetea el estado del provider a su condición inicial.
  ///
  /// Se llama típicamente cuando la pantalla de métricas se desmonta (navegar
  /// hacia atrás) o cuando se recibe un 401 durante el polling.
  ///
  /// No llama a [notifyListeners]: cuando se desmonta la pantalla, notificar
  /// sería inútil (no hay listeners activos) o podría causar errores si los
  /// widgets ya están destruidos. En el caso del 401, el bloque `finally` de
  /// [_fetch] se encarga de la notificación tras [stopPolling].
  void stopPolling() {
    _timer?.cancel();
    _timer = null;
    _currentServerId = null;
    _points = [];
    _error = null;
    _loading = false;
  }

  // ── Fetch interno ───────────────────────────────────────────────────────────

  /// Ejecuta una petición de métricas a api-py y actualiza el estado.
  ///
  /// Es el núcleo del polling: se llama tanto en la carga inicial de
  /// [startPolling] como en cada tick del timer periódico.
  ///
  /// Flujo:
  ///   1. Marca `_loading = true` y notifica (spinner en UI).
  ///   2. Solicita los puntos de métrica a [MetricsService] para [_currentServerId]
  ///      y [_rangeMinutes] actuales.
  ///   3. En éxito: reemplaza [_points] con los nuevos datos.
  ///   4. En [ApiException] con status 401: llama a [stopPolling] y sale
  ///      (sin mensaje de error; AuthProvider ya gestionó la sesión).
  ///   5. En [ApiException] con otro status: almacena el mensaje en [_error].
  ///   6. En error inesperado: almacena mensaje genérico en [_error].
  ///   7. `finally`: siempre resetea `_loading = false` y llama a [notifyListeners].
  ///
  /// Nota sobre el 401 y el bloque `finally`:
  ///   Incluso cuando se captura un 401 y se llama `return` dentro del catch,
  ///   el bloque `finally` se ejecuta. Esto es correcto: [stopPolling] no llama
  ///   a [notifyListeners], por lo que `finally` es el responsable de notificar
  ///   a la UI el estado limpio resultante del 401.
  Future<void> _fetch() async {
    if (_currentServerId == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _points = await MetricsService.instance.getMetrics(
        _currentServerId!,
        rangeMinutes: _rangeMinutes,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        // La sesión ya fue invalidada por ApiService.onUnauthorized (AuthProvider);
        // detenemos el polling sin mostrar error técnico al usuario.
        // El bloque finally aún se ejecutará tras este return.
        stopPolling();
        return;
      }
      _error = e.message;
    } catch (e) {
      _error = 'Error inesperado al cargar métricas';
    } finally {
      // Siempre resetea el indicador de carga y notifica, tanto en éxito como
      // en error. En el caso del 401, notifica el estado limpio de stopPolling.
      _loading = false;
      notifyListeners();
    }
  }

  // ── Ciclo de vida del provider ──────────────────────────────────────────────

  /// Cancela el timer periódico al destruir el provider.
  ///
  /// Imprescindible para evitar que el timer siga disparando [_fetch] después
  /// de que el provider y sus widgets asociados hayan sido destruidos, lo que
  /// causaría errores del tipo "setState called after dispose" o llamadas HTTP
  /// innecesarias.
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
