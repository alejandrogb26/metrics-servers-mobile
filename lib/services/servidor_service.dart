import 'package:metrics_servers_mobile/models/model_servidor.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';

class ServidorService {
  ServidorService._();
  static final ServidorService instance = ServidorService._();

  Future<List<Servidor>> getAll() async {
    final raw = await ApiService.instance.get(
      '/servidor',
      query: {'page': '0', 'size': '100'},
    );
    final map = raw as Map<String, dynamic>;
    final items = map['data'] as List<dynamic>? ?? [];
    return items.map((e) => Servidor.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Servidor> getById(int id) async {
    final data = await ApiService.instance.get('/servidor/$id');
    return Servidor.fromJson(data as Map<String, dynamic>);
  }
}
