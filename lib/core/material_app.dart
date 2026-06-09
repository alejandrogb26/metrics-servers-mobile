/// material_app.dart
///
/// Propósito:
///   Define [MonitoringApp], el widget raíz de la aplicación Metrics Manager.
///   Configura el [MaterialApp] con el tema visual global y el sistema de rutas
///   con nombre, actuando como punto de entrada de la capa de presentación.
///
/// Capa arquitectónica:
///   Capa de presentación — raíz de la aplicación (core/).
///   Este fichero es instanciado directamente desde `main.dart`, que envuelve
///   [MonitoringApp] con los providers globales necesarios (autenticación,
///   datos, etc.). La separación entre providers y app widget es deliberada:
///   [MonitoringApp] solo conoce el tema y las rutas, nunca los providers.
///
/// Responsabilidades principales:
///   - Definir el widget raíz [MonitoringApp] que inicializa [MaterialApp].
///   - Establecer el tema visual oscuro unificado para toda la aplicación.
///   - Registrar el sistema de rutas con nombre y declarar la ruta inicial.
///
/// Qué NO debe contener este fichero:
///   - Lógica de negocio ni acceso a servicios o repositorios.
///   - Providers ni estado global (eso pertenece a `main.dart` o a capas superiores).
///   - Definición de rutas individuales (eso pertenece a `app_routes.dart`).
///   - Lógica de autenticación ni redirección condicional por sesión.
library;

import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/routes/app_routes.dart';

/// Widget raíz de la aplicación Metrics Manager.
///
/// Responsabilidad:
///   Configura y lanza el [MaterialApp] con el tema visual y el sistema de
///   rutas con nombre. Es un [StatelessWidget] puro: no gestiona estado,
///   no escucha providers y no contiene lógica de negocio.
///
/// Relación con otros módulos:
///   - `main.dart`: instancia [MonitoringApp] y lo envuelve con [MultiProvider]
///     para inyectar los providers globales antes de que el árbol de widgets
///     se construya.
///   - `app_routes.dart`: proporciona los nombres de ruta ([AppRoutes]) y el
///     mapa de constructores de pantalla ([AppRoutes.getRoutes]).
///
/// Decisión de diseño — rutas con nombre vs. GoRouter:
///   La app usa el sistema clásico de rutas con nombre de [MaterialApp]
///   (`routes` + `initialRoute`) en lugar de GoRouter o Navigator 2.0. Esto
///   simplifica la configuración y es suficiente para una app móvil sin deep
///   linking ni routing declarativo complejo. Si en el futuro se necesita
///   routing condicional por estado de autenticación (guard de rutas), habría
///   que migrar a [MaterialApp.router] con GoRouter o similar.
///
/// Decisión de diseño — ruta inicial:
///   La ruta inicial es siempre [AppRoutes.login], lo que garantiza que cada
///   arranque en frío exige autenticación. La persistencia de sesión (si existe)
///   debe gestionarse dentro de la propia pantalla de login o en el provider de
///   autenticación, no alterando la ruta inicial aquí.
class MonitoringApp extends StatelessWidget {
  const MonitoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Server Monitor',
      // Oculta el banner rojo de debug en modo desarrollo para evitar que
      // interfiera con capturas de pantalla y pruebas de UI.
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      // La app siempre arranca en la pantalla de login. La gestión de sesión
      // persistida (token guardado) se delega al LoginScreen o al AuthProvider.
      initialRoute: AppRoutes.login,
      routes: AppRoutes.getRoutes(),
    );
  }

  /// Construye y devuelve el [ThemeData] global de la aplicación.
  ///
  /// Define un tema oscuro coherente inspirado en la paleta GitHub Dark,
  /// aplicado a todos los componentes Material de la app. Centralizar el tema
  /// aquí garantiza consistencia visual sin necesidad de especificar colores
  /// en cada widget individual.
  ///
  /// Paleta de colores empleada:
  ///   - `0xFF0D1117` — fondo principal del scaffold (negro-azulado GitHub).
  ///   - `0xFF161B22` — superficie de cards, AppBar y Drawer (capa intermedia).
  ///   - `0xFF21262D` — fondo de inputs y chips (capa elevada sobre superficie).
  ///   - `0xFF30363D` — color de bordes y separadores (gris oscuro).
  ///   - `0xFF8B949E` — texto y iconos secundarios (gris claro).
  ///   - `0xFF1F6FEB` — acento azul primario (botones, foco de inputs, iconos).
  ///
  /// Nota sobre Material 3:
  ///   Se activa [useMaterial3] con un [ColorScheme.fromSeed] de semilla azul
  ///   profundo (`0xFF1565C0`) y [Brightness.dark]. El color semilla influye en
  ///   los tonos generados automáticamente por M3 para variantes de color, pero
  ///   los colores críticos de UI se sobreescriben explícitamente en cada
  ///   sub-tema para garantizar fidelidad exacta a la paleta GitHub Dark.
  ThemeData _buildTheme() {
    // Color semilla para el sistema de color de Material 3. Genera la paleta
    // de tonos automática del esquema, pero los componentes críticos usan
    // colores explícitos para control total sobre el aspecto visual.
    const seedColor = Color(0xFF1565C0); // azul profundo
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ),

      // Fondo del Scaffold: el tono más oscuro de la paleta, usado en todas
      // las pantallas como base del contenido.
      scaffoldBackgroundColor: const Color(0xFF0D1117),

      // Cards sin elevación (sombra) y con borde explícito: en temas oscuros
      // la elevación mediante sombra no es perceptible, por lo que el borde
      // `0xFF30363D` es el mecanismo visual que delimita las cards del fondo.
      cardTheme: CardThemeData(
        color: const Color(0xFF161B22),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF30363D)),
        ),
      ),

      // AppBar sin elevación y con título alineado a la izquierda (centerTitle: false),
      // siguiendo la convención de apps de gestión/dashboard donde el título
      // actúa como encabezado de sección, no como nombre centrado de la app.
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF161B22),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),

      // Drawer con el mismo color de superficie que AppBar y cards,
      // manteniendo coherencia visual entre todos los contenedores de nivel 1.
      drawerTheme: const DrawerThemeData(backgroundColor: Color(0xFF161B22)),

      // Campos de texto: fondo relleno para distinguirlos del scaffold,
      // borde neutro en reposo y borde azul de 2px al obtener el foco.
      // El foco con borde de 2px es la señal visual principal de activación,
      // más clara que un cambio de color de fondo en tema oscuro.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF21262D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1F6FEB), width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF8B949E)),
      ),

      // Botones primarios con fondo azul acento y texto blanco. El padding
      // vertical de 14px y el peso de fuente w600 garantizan que el botón
      // sea suficientemente prominente en pantallas de acción (login, formularios).
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1F6FEB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      // Chips compactos usados en filtros y etiquetas de grupos/servicios.
      // Border radius de 6px (menos redondeado que inputs y botones) para
      // diferenciar visualmente los chips de los controles interactivos.
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF21262D),
        labelStyle: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
        side: const BorderSide(color: Color(0xFF30363D)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      ),
    );
  }
}
