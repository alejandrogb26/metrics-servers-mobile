import 'package:metrics_servers_mobile/models/model_seccion.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';

class SeccionService {
  SeccionService._();
  static final SeccionService instance = SeccionService._();

  Future<List<Seccion>> getAll() async {
    final data = await ApiService.instance.get('/seccion');
    return (data as List<dynamic>)
        .map((e) => Seccion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Seccion> getById(int id) async {
    final data = await ApiService.instance.get('/seccion/$id');
    return Seccion.fromJson(data as Map<String, dynamic>);
  }
}
