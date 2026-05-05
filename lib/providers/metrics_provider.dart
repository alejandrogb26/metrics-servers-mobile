import 'dart:async';
import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/models/metrics/model_metrics.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';
import 'package:metrics_servers_mobile/services/metrics_service.dart';

class MetricsProvider with ChangeNotifier {
  List<MetricPoint> _points = [];
  bool _loading = false;
  String? _error;
  String? _currentServerId;
  int _rangeMinutes = 60;
  Timer? _timer;

  List<MetricPoint> get points => _points;
  bool get loading => _loading;
  String? get error => _error;
  int get rangeMinutes => _rangeMinutes;

  Future<void> startPolling(String serverId, {int rangeMinutes = 60}) async {
    if (_currentServerId == serverId && _rangeMinutes == rangeMinutes) return;
    _currentServerId = serverId;
    _rangeMinutes = rangeMinutes;
    _points = [];
    _timer?.cancel();
    await _fetch();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetch());
  }

  Future<void> changeRange(int minutes) async {
    if (_rangeMinutes == minutes) return;
    _rangeMinutes = minutes;
    _points = [];
    notifyListeners();
    await _fetch();
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
    _currentServerId = null;
    _points = [];
    _error = null;
    _loading = false;
  }

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
        // La sesión ya fue invalidada por ApiService.onUnauthorized;
        // detenemos el polling sin mostrar error técnico al usuario.
        stopPolling();
        return;
      }
      _error = e.message;
    } catch (e) {
      _error = 'Error inesperado al cargar métricas';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
