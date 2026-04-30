import 'package:metrics_servers_mobile/models/model_permiso.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';

class PermisoService {
  PermisoService._();
  static final PermisoService instance = PermisoService._();

  Future<List<Permiso>> getAll() async {
    final raw = await ApiService.instance.get(
      '/permisos',
      query: {'page': '0', 'size': '100'},
    );
    final map = raw as Map<String, dynamic>;
    final items = map['data'] as List<dynamic>? ?? [];
    return items.map((e) => Permiso.fromJson(e as Map<String, dynamic>)).toList();
  }
}
