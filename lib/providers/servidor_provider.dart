import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/models/model_seccion.dart';
import 'package:metrics_servers_mobile/models/model_servicio.dart';
import 'package:metrics_servers_mobile/models/model_servidor.dart';
import 'package:metrics_servers_mobile/providers/auth_provider.dart';
import 'package:metrics_servers_mobile/services/seccion_service.dart';
import 'package:metrics_servers_mobile/services/servicio_service.dart';
import 'package:metrics_servers_mobile/services/servidor_service.dart';

class ServidorProvider with ChangeNotifier {
  List<Servidor> _servidores = [];
  Map<int, Servicio> _serviciosCache = {};
  Map<int, Seccion> _seccionesCache = {};
  bool _loaded = false;

  List<Servidor> get servidores => _servidores;
  Map<int, Servicio> get serviciosCache => _serviciosCache;
  Map<int, Seccion> get seccionesCache => _seccionesCache;

  Future<List<Servidor>> fetchAll(AuthProvider auth) async {
    if (_loaded) return _servidores;

    final all = await ServidorService.instance.getAll();

    // Filtrar según permisos
    _servidores = all.where((s) {
      return auth.canViewServersInSection(s.seccion.toString());
    }).toList();

    _loaded = true;
    notifyListeners();
    return _servidores;
  }

  Future<void> preloadCaches() async {
    if (_serviciosCache.isNotEmpty && _seccionesCache.isNotEmpty) return;

    final servicios = await ServicioService.instance.getAll();
    _serviciosCache = {for (final s in servicios) s.id: s};

    final secciones = await SeccionService.instance.getAll();
    _seccionesCache = {for (final s in secciones) s.id: s};

    notifyListeners();
  }

  List<Servidor> search(String query) {
    final q = query.toLowerCase();
    return _servidores.where((s) {
      return s.hostname.toLowerCase().contains(q) ||
          s.dns.toLowerCase().contains(q) ||
          s.serverId.toLowerCase().contains(q) ||
          (s.prettyOs?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  void invalidate() {
    _loaded = false;
    _servidores = [];
  }
}
