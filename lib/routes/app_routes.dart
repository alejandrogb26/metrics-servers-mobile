/// app_routes.dart
///
/// Propósito:
///   Define [AppRoutes], la clase de utilidad estática que centraliza todas las
///   rutas con nombre de la aplicación. Actúa como única fuente de verdad para
///   los identificadores de ruta, evitando strings literales dispersos por el
///   código y facilitando refactorizaciones de rutas.
///
/// Capa arquitectónica:
///   Capa de presentación — configuración de navegación (routes/).
///   Es consumido por [MonitoringApp] (core/material_app.dart) para registrar
///   el mapa de rutas en [MaterialApp], y por cualquier pantalla o widget que
///   necesite navegar usando `Navigator.pushNamed`.
///
/// Sistema de rutas empleado:
///   La app usa el sistema clásico de rutas con nombre de [MaterialApp]
///   (`routes` + `initialRoute`). Las rutas no tienen segmentos dinámicos
///   (p. ej. `/servidores/:id`) porque el sistema de [Navigator] 1.0 no los
///   soporta nativamente. Los argumentos se pasan al navegar mediante el
///   parámetro `arguments` de `Navigator.pushNamed` y se recuperan en la
///   pantalla destino con `ModalRoute.of(context)!.settings.arguments`.
///
/// Jerarquía de rutas:
///
///   Autenticación:
///     /login                    → LoginScreen
///
///   Panel principal:
///     /home                     → HomeScreen
///
///   Servidores:
///     /servidores               → ListaServidoresScreen
///     /servidores/detalle       → DetalleServidorScreen
///     /servidores/metricas      → MetricasScreen
///
///   Servicios:
///     /servicios                → ListaServiciosScreen
///
///   Administración:
///     /gestion/grupos           → GruposScreen
///     /gestion/grupos/detalle   → DetalleGrupoScreen
///
/// Control de acceso:
///   Este fichero no implementa guardas de ruta. El sistema de rutas con nombre
///   de [MaterialApp] no soporta redirecciones condicionales en el registro del
///   mapa. El control de acceso (comprobar si el usuario está autenticado o
///   tiene permisos) se realiza dentro de cada pantalla, no en la definición
///   de la ruta.
///
/// Qué NO debe contener este fichero:
///   - Lógica de negocio ni comprobaciones de permisos.
///   - Instanciación directa de widgets fuera de [getRoutes].
///   - Rutas específicas de una sola feature que no requieran ser referenciadas
///     desde otros módulos (aunque en la práctica todas las rutas de la app
///     se registran aquí centralizadamente).
library;

import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/screens/gestion/detalle_grupo_screen.dart';
import 'package:metrics_servers_mobile/screens/gestion/grupos_screen.dart';
import 'package:metrics_servers_mobile/screens/home/home_screen.dart';
import 'package:metrics_servers_mobile/screens/login/login_screen.dart';
import 'package:metrics_servers_mobile/screens/metricas/metricas_screen.dart';
import 'package:metrics_servers_mobile/screens/servidores/detalle_servidor/detalle_servidor_screen.dart';
import 'package:metrics_servers_mobile/screens/servidores/lista_servicios_screen.dart';
import 'package:metrics_servers_mobile/screens/servidores/lista_servidores_screen.dart';

/// Clase de utilidad estática con las constantes de ruta y el mapa de constructores.
///
/// Responsabilidad:
///   Centraliza en un único lugar los nombres de ruta (constantes string) y los
///   constructores de pantalla ([WidgetBuilder]) que [MaterialApp] necesita para
///   resolver la navegación. Al usar las constantes en lugar de strings literales,
///   el compilador detecta errores de tipografía en tiempo de compilación.
///
/// Uso de navegación:
///   ```dart
///   // Navegar a la lista de servidores:
///   Navigator.pushNamed(context, AppRoutes.listaServidores);
///
///   // Navegar al detalle de un servidor pasando argumentos:
///   Navigator.pushNamed(
///     context,
///     AppRoutes.detalleServidor,
///     arguments: servidor,  // Servidor recuperado con ModalRoute.of(context)!.settings.arguments
///   );
///   ```
///
/// Diseño:
///   Solo miembros estáticos; la clase no debe instanciarse. Dart no tiene
///   una palabra clave para clases puramente estáticas, pero la convención
///   es usar únicamente `static const` y `static` methods.
class AppRoutes {
  // ── Constantes de ruta ─────────────────────────────────────────────────────

  /// Ruta de la pantalla de login. Es la ruta inicial de la app
  /// (ver [MonitoringApp.initialRoute]).
  static const String login = '/login';

  /// Ruta del panel principal (home), visible tras autenticarse.
  static const String home = '/home';

  /// Ruta de la lista paginada de servidores.
  static const String listaServidores = '/servidores';

  /// Ruta del detalle de un servidor concreto.
  /// Espera un objeto [Servidor] como argumento de navegación.
  static const String detalleServidor = '/servidores/detalle';

  /// Ruta de la pantalla de métricas en tiempo real de un servidor.
  /// Ubicada bajo `/servidores/` porque las métricas son siempre
  /// específicas de un servidor concreto.
  /// Espera un objeto [Servidor] como argumento de navegación.
  static const String metricas = '/servidores/metricas';

  /// Ruta de la lista de servicios disponibles en el catálogo.
  static const String listaServicios = '/servicios';

  /// Ruta de la lista de grupos (pantalla de administración).
  /// Solo accesible para usuarios con permiso AUDIT_USER o superAdmin.
  static const String grupos = '/gestion/grupos';

  /// Ruta del detalle/edición de un grupo concreto.
  /// Solo accesible para usuarios con permiso AUDIT_USER o superAdmin.
  /// Espera un objeto [Grupo] como argumento de navegación.
  static const String detalleGrupo = '/gestion/grupos/detalle';

  // ── Mapa de constructores ──────────────────────────────────────────────────

  /// Devuelve el mapa `ruta → WidgetBuilder` para registrar en [MaterialApp.routes].
  ///
  /// Cada entrada asocia una constante de ruta con el constructor de la pantalla
  /// correspondiente. El `BuildContext` del [WidgetBuilder] (`_`) se descarta
  /// porque ninguna pantalla lo necesita en su constructor; todas lo reciben
  /// a través de su propio método `build(BuildContext context)`.
  ///
  /// Este método es llamado una vez desde [MonitoringApp.build]. Aunque
  /// `build` puede llamarse varias veces, [MaterialApp] cachea internamente
  /// el mapa de rutas, por lo que el impacto es negligible.
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
