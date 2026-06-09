/// screens.dart
///
/// Propósito:
///   Barrel file de la capa de pantallas. Re-exporta todos los ficheros de
///   screens para que cualquier módulo pueda importar cualquier pantalla o
///   widget de screen con una sola línea de import.
///
/// Capa arquitectónica:
///   Capa de presentación — punto de entrada único para screens/.
///
/// Pantallas y widgets exportados (12 ficheros):
///
///   Autenticación:
///     - login/login_screen.dart       → [LoginScreen]
///
///   Panel principal:
///     - home/home_screen.dart         → [HomeScreen]
///     - home/home_user_card.dart      → [HomeUserCard]
///
///   Servidores:
///     - servidores/lista_servidores_screen.dart               → [ListaServidoresScreen], [ServidorCard]
///     - servidores/busqueda_servidores.dart                   → [ServidorSearchDelegate]
///     - servidores/lista_servicios_screen.dart                → [ListaServiciosScreen]
///     - servidores/detalle_servidor/detalle_servidor_screen.dart → [DetalleServidorScreen]
///     - servidores/detalle_servidor/detalle_info_card.dart       → [DetalleInfoCard]
///     - servidores/detalle_servidor/detalle_servicios_list.dart  → [DetalleServiciosList]
///
///   Métricas:
///     - metricas/metricas_screen.dart → [MetricasScreen]
///
///   Gestión:
///     - gestion/grupos_screen.dart        → [GruposScreen]
///     - gestion/detalle_grupo_screen.dart → [DetalleGrupoScreen]
///
/// Qué NO debe contener este fichero:
///   - Ninguna lógica, clase ni definición de widget.
///   - Re-exportaciones de otras capas (providers, models, services).
library;

export 'login/login_screen.dart';
export 'home/home_screen.dart';
export 'home/home_user_card.dart';
export 'servidores/lista_servidores_screen.dart';
export 'servidores/busqueda_servidores.dart';
export 'servidores/detalle_servidor/detalle_servidor_screen.dart';
export 'servidores/detalle_servidor/detalle_info_card.dart';
export 'servidores/detalle_servidor/detalle_servicios_list.dart';
export 'metricas/metricas_screen.dart';
export 'gestion/grupos_screen.dart';
export 'gestion/detalle_grupo_screen.dart';
export 'servidores/lista_servicios_screen.dart';
