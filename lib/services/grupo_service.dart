import 'package:metrics_servers_mobile/models/model_grupo.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';

class GrupoService {
  GrupoService._();
  static final GrupoService instance = GrupoService._();

  Future<List<Grupo>> getAll() async {
    final data = await ApiService.instance.get('/grupos');
    return (data as List<dynamic>)
        .map((e) => Grupo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Grupo> getById(int id) async {
    final data = await ApiService.instance.get('/grupos/$id');
    return Grupo.fromJson(data as Map<String, dynamic>);
  }
}
