import 'package:metrics_servers_mobile/models/model_permiso.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';

class PermisoService {
  PermisoService._();
  static final PermisoService instance = PermisoService._();

  Future<List<Permiso>> getAll() async {
    final data = await ApiService.instance.get('/permisos');
    return (data as List<dynamic>)
        .map((e) => Permiso.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
