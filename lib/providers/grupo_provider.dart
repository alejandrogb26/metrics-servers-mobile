import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/models/model_grupo.dart';
import 'package:metrics_servers_mobile/models/model_permiso.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';
import 'package:metrics_servers_mobile/services/grupo_service.dart';
import 'package:metrics_servers_mobile/services/permiso_service.dart';

class GrupoProvider with ChangeNotifier {
  List<Grupo> _grupos = [];
  List<Permiso> _permisos = [];
  bool _loaded = false;
  String? _error;

  List<Grupo> get grupos => _grupos;
  List<Permiso> get permisos => _permisos;
  String? get error => _error;

  Future<void> fetchAll() async {
    if (_loaded) return;
    _error = null;
    try {
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

  Permiso? getPermisoById(int id) {
    try {
      return _permisos.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  void invalidate() {
    _loaded = false;
    _grupos = [];
    _permisos = [];
    _error = null;
    notifyListeners();
  }
}
