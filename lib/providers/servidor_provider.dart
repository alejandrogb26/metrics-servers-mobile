import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/models/model_seccion.dart';
import 'package:metrics_servers_mobile/models/model_servicio.dart';
import 'package:metrics_servers_mobile/models/model_servidor.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';
import 'package:metrics_servers_mobile/services/seccion_service.dart';
import 'package:metrics_servers_mobile/services/servicio_service.dart';
import 'package:metrics_servers_mobile/services/servidor_service.dart';

class ServidorProvider with ChangeNotifier {
  List<Servidor> _servidores = [];
  Map<int, Servicio> _serviciosCache = {};
  Map<int, Seccion> _seccionesCache = {};

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasNext = false;
  int _currentPage = 0;
  String? _error;

  static const int _pageSize = 20;

  // ── Getters ────────────────────────────────────────────────────────────────

  List<Servidor> get servidores => _servidores;
  Map<int, Servicio> get serviciosCache => _serviciosCache;
  Map<int, Seccion> get seccionesCache => _seccionesCache;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasNext => _hasNext;
  String? get error => _error;

  // ── First page ─────────────────────────────────────────────────────────────

  Future<void> loadFirstPage() async {
    // Guard: already loading, or data already present (covers back-navigation).
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

  // ── Next page ──────────────────────────────────────────────────────────────

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

  // ── Caches ─────────────────────────────────────────────────────────────────

  Future<void> preloadCaches() async {
    if (_serviciosCache.isNotEmpty && _seccionesCache.isNotEmpty) return;

    final servicios = await ServicioService.instance.getAll();
    _serviciosCache = {for (final s in servicios) s.id: s};

    final secciones = await SeccionService.instance.getAll();
    _seccionesCache = {for (final s in secciones) s.id: s};

    notifyListeners();
  }

  // ── Search (client-side in accumulated pages) ──────────────────────────────

  List<Servidor> search(String query) {
    final q = query.toLowerCase();
    return _servidores.where((s) {
      return s.hostname.toLowerCase().contains(q) ||
          s.dns.toLowerCase().contains(q) ||
          s.serverId.toLowerCase().contains(q) ||
          (s.prettyOs?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  // ── Reset ──────────────────────────────────────────────────────────────────

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