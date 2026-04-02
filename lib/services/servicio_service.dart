import 'package:metrics_servers_mobile/models/model_servicio.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';

class ServicioService {
  ServicioService._();
  static final ServicioService instance = ServicioService._();

  Future<List<Servicio>> getAll() async {
    final data = await ApiService.instance.get('/servicio');
    return (data as List<dynamic>)
        .map((e) => Servicio.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Servicio> getById(int id) async {
    final data = await ApiService.instance.get('/servicio/$id');
    return Servicio.fromJson(data as Map<String, dynamic>);
  }
}
