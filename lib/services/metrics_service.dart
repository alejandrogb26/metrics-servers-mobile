import 'package:metrics_servers_mobile/models/metrics/model_metrics.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';

class MetricsService {
  MetricsService._();
  static final MetricsService instance = MetricsService._();

  Future<List<MetricPoint>> getMetrics(String serverId,
      {int rangeMinutes = 60}) async {
    final data = await ApiService.instance.get(
      '/servidor/$serverId/metrics',
      query: {'range': rangeMinutes.toString()},
    );
    if (data == null) return [];
    return (data as List<dynamic>)
        .map((e) => MetricPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
