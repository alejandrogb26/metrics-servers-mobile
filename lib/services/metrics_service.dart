/// metrics_service.dart
///
/// Propósito:
///   Servicio de dominio para métricas de servidor. Consulta la serie temporal
///   de métricas de un servidor concreto durante una ventana de tiempo expresada
///   en minutos y devuelve la lista de puntos de métrica deserializados.
///
/// Capa arquitectónica:
///   Capa de servicios (services/). Actúa como adaptador entre [MetricasProvider]
///   (capa de estado/polling) y [ApiService] (capa de transporte HTTP).
///
/// Clases definidas en este fichero:
///   - [MetricsService]: singleton con el método [getMetrics].
///
/// Patrón singleton:
///   Constructor privado `MetricsService._()` + campo estático `instance`.
///   Mismo patrón que el resto de servicios de dominio.
///
/// Formato de respuesta de la API:
///   `GET /servidor/{id}/metrics?minutes={n}` devuelve un **array JSON directo**
///   (sin envelope paginado): `[ { ... }, { ... } ]`. Cada elemento se
///   deserializa en un [MetricPoint] mediante `MetricPoint.fromJson`.
///   Si no hay métricas disponibles, api-py puede devolver 204 No Content;
///   [ApiService._handle] mapea el 204 a `null`, que [getMetrics] convierte en
///   una lista vacía.
///
/// Ventana temporal:
///   El parámetro `minutes` define cuántos minutos hacia atrás se solicitan.
///   El valor por defecto es 60 (última hora). [MetricasProvider] puede pasar
///   un valor distinto si la pantalla de métricas implementa selección de rango.
///
/// Qué NO debe contener este fichero:
///   - Lógica de polling o schedulers (responsabilidad de [MetricasProvider]).
///   - Caché de puntos de métrica.
///   - Interpretación del significado de los valores numéricos (CPU %, bytes, etc.).
///   - Llamadas a otros servicios de dominio.
library;

import 'package:metrics_servers_mobile/models/metrics/model_metrics.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';

/// Servicio de consulta de métricas singleton.
///
/// Responsabilidad:
///   Solicitar la serie temporal de métricas de un servidor a api-py y
///   deserializar la respuesta en una lista de [MetricPoint].
///
/// Invocado periódicamente por [MetricasProvider] mediante [Timer.periodic]
/// para mantener la pantalla de métricas actualizada en tiempo real. El
/// intervalo de polling y el ciclo de vida del timer son responsabilidad
/// exclusiva de [MetricasProvider].
class MetricsService {
  MetricsService._();

  /// Instancia única compartida por toda la aplicación.
  static final MetricsService instance = MetricsService._();

  /// Obtiene la serie temporal de métricas del servidor identificado por [serverId].
  ///
  /// Realiza `GET /servidor/{serverId}/metrics?minutes={rangeMinutes}`.
  ///
  /// [serverId] es el identificador del servidor tal como lo almacena el modelo
  /// [Servidor] (tipo `String`).
  ///
  /// [rangeMinutes] controla la ventana temporal de los datos devueltos: api-py
  /// retorna todos los puntos registrados en los últimos [rangeMinutes] minutos.
  /// El valor por defecto es `60` (última hora). No se valida en cliente: si
  /// se pasa `0` o un valor negativo, se enviará sin guarda a api-py.
  ///
  /// Manejo de respuesta vacía:
  ///   La guarda `if (data == null) return []` cubre el caso 204 No Content
  ///   (sin métricas disponibles para el rango solicitado). El cast posterior
  ///   `data as List<dynamic>` asume que cualquier respuesta no nula es un
  ///   array JSON; si api-py devolviera un objeto JSON (contrato inesperado),
  ///   se lanzaría [TypeError] en lugar de [ApiException].
  ///
  /// Throws [ApiException] si [ApiService.get] falla por error de red, timeout
  /// o código HTTP de error (404 servidor no encontrado, etc.).
  Future<List<MetricPoint>> getMetrics(
    String serverId, {
    int rangeMinutes = 60,
  }) async {
    final data = await ApiService.instance.get(
      '/servidor/$serverId/metrics',
      query: {'minutes': rangeMinutes.toString()},
    );
    if (data == null) return [];
    return (data as List<dynamic>)
        .map((e) => MetricPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
