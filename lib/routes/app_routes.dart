import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/screens/gestion/detalle_grupo_screen.dart';
import 'package:metrics_servers_mobile/screens/gestion/grupos_screen.dart';
import 'package:metrics_servers_mobile/screens/home/home_screen.dart';
import 'package:metrics_servers_mobile/screens/login/login_screen.dart';
import 'package:metrics_servers_mobile/screens/metricas/metricas_screen.dart';
import 'package:metrics_servers_mobile/screens/servidores/detalle_servidor/detalle_servidor_screen.dart';
import 'package:metrics_servers_mobile/screens/servidores/lista_servicios_screen.dart';
import 'package:metrics_servers_mobile/screens/servidores/lista_servidores_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String listaServidores = '/servidores';
  static const String detalleServidor = '/servidores/detalle';
  static const String metricas = '/servidores/metricas';
  static const String listaServicios = '/servicios';
  static const String grupos = '/gestion/grupos';
  static const String detalleGrupo = '/gestion/grupos/detalle';

  static Map<String, WidgetBuilder> getRoutes() => {
    login: (_) => const LoginScreen(),
    home: (_) => const HomeScreen(),
    listaServidores: (_) => const ListaServidoresScreen(),
    detalleServidor: (_) => const DetalleServidorScreen(),
    metricas: (_) => const MetricasScreen(),
    listaServicios: (_) => const ListaServiciosScreen(),
    grupos: (_) => const GruposScreen(),
    detalleGrupo: (_) => const DetalleGrupoScreen(),
  };
}
