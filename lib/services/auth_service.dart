import 'package:metrics_servers_mobile/models/model_session.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  Future<LoginResponse> login(String username, String password) async {
    final data = await ApiService.instance.post('/auth/login', {
      'username': username,
      'password': password,
    });
    return LoginResponse.fromJson(data as Map<String, dynamic>);
  }
}
