import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/models/model_grupo.dart';
import 'package:metrics_servers_mobile/models/model_permiso.dart';
import 'package:metrics_servers_mobile/services/grupo_service.dart';
import 'package:metrics_servers_mobile/services/permiso_service.dart';

class GrupoProvider with ChangeNotifier {
  List<Grupo> _grupos = [];
  List<Permiso> _permisos = [];
  bool _loaded = false;

  List<Grupo> get grupos => _grupos;
  List<Permiso> get permisos => _permisos;

  Future<void> fetchAll() async {
    if (_loaded) return;
    final results = await Future.wait([
      GrupoService.instance.getAll(),
      PermisoService.instance.getAll(),
    ]);
    _grupos = results[0] as List<Grupo>;
    _permisos = results[1] as List<Permiso>;
    _loaded = true;
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
  }
}
