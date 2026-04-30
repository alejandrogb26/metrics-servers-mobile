import 'package:metrics_servers_mobile/models/model_seccion.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';

class SeccionService {
  SeccionService._();
  static final SeccionService instance = SeccionService._();

  Future<List<Seccion>> getAll() async {
    final raw = await ApiService.instance.get(
      '/seccion',
      query: {'page': '0', 'size': '100'},
    );
    final map = raw as Map<String, dynamic>;
    final items = map['data'] as List<dynamic>? ?? [];
    return items.map((e) => Seccion.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Seccion> getById(int id) async {
    final data = await ApiService.instance.get('/seccion/$id');
    return Seccion.fromJson(data as Map<String, dynamic>);
  }
}
