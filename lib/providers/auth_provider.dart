import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/models/model_session.dart';
import 'package:metrics_servers_mobile/services/api_service.dart';
import 'package:metrics_servers_mobile/services/auth_service.dart';

enum AuthStatus { initial, loading, authenticated, error }

class AuthProvider with ChangeNotifier {
  AuthStatus _status = AuthStatus.initial;
  Session? _session;
  String? _errorMessage;

  AuthStatus get status => _status;
  Session? get session => _session;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<bool> login(String username, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await AuthService.instance.login(username, password);

      _session = response.session;
      ApiService.instance.setToken(response.token);

      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.message;
      debugPrint('ApiException en login: $e');
      notifyListeners();
      return false;
    } catch (e, st) {
      _status = AuthStatus.error;
      _errorMessage = 'Error inesperado: $e';
      debugPrint('Error inesperado en login: $e');
      debugPrint('Stack trace: $st');
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _session = null;
    ApiService.instance.clearToken();
    _status = AuthStatus.initial;
    notifyListeners();
  }

  bool get isSuperAdmin => _session?.isSuperAdmin ?? false;

  bool canViewUserManagement() => _session?.canViewUserManagement() ?? false;

  bool canViewAnyServer() => _session?.canViewAnyServer() ?? false;

  bool canViewServersInSection(String seccionId) =>
      _session?.canViewServersInSection(seccionId) ?? false;
}
