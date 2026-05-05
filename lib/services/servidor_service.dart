import 'package:metrics_servers_mobile/models/model_paged_response.dart';
import 'package:metrics_servers_mobile/models/model_servidor.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';

class ServidorService {
  ServidorService._();
  static final ServidorService instance = ServidorService._();

  Future<PagedResponse<Servidor>> getPage({
    required int page,
    required int size,
  }) async {
    final raw = await ApiService.instance.get(
      '/servidor',
      query: {'page': page.toString(), 'size': size.toString()},
    );
    final map = raw as Map<String, dynamic>;
    return PagedResponse.fromJson(
      map,
      (item) => Servidor.fromJson(item as Map<String, dynamic>),
    );
  }

  // Kept for callers that need a flat list (servicios cache, etc.).
  Future<List<Servidor>> getAll() async {
    final paged = await getPage(page: 0, size: 100);
    return paged.data;
  }

  Future<Servidor> getById(int id) async {
    final data = await ApiService.instance.get('/servidor/$id');
    return Servidor.fromJson(data as Map<String, dynamic>);
  }
}