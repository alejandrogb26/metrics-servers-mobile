/// providers.dart
///
/// Propósito:
///   Cumple dos funciones en un solo fichero:
///
///   1. **Barrel file**: re-exporta todos los providers de la aplicación para
///      que cualquier pantalla pueda importarlos con una sola línea.
///
///   2. **Raíz del árbol de providers**: define el widget [Providers], que
///      envuelve [MonitoringApp] con un [MultiProvider] y registra todos los
///      [ChangeNotifierProvider] globales de la app.
///
/// Capa arquitectónica:
///   Capa de presentación — punto de composición de providers (providers/).
///   Es instanciado directamente desde `main.dart`, siendo el widget más externo
///   del árbol de la aplicación (por encima de [MonitoringApp] y del enrutador).
///
/// Providers registrados y su alcance:
///   Todos los providers se registran con alcance global (toda la app), lo que
///   significa que sus instancias viven durante toda la sesión de la aplicación:
///
///   - [AuthProvider]:    sesión, token y comprobaciones de acceso.
///   - [ServidorProvider]: lista paginada de servidores y catálogos de resolución.
///   - [GrupoProvider]:   catálogo de grupos y permisos para administración.
///   - [MetricsProvider]: serie temporal de métricas con polling periódico.
///
/// Decisión de diseño — providers globales vs. por pantalla:
///   [MetricsProvider] podría haberse creado a nivel de pantalla (scoped), pero
///   se registra globalmente para que el estado del polling (y los datos ya
///   cargados) sobreviva a navigaciones internas sin reiniciarse. El provider
///   permanece inactivo (sin timer) cuando ninguna pantalla ha iniciado el
///   polling; el estado se gestiona explícitamente con `startPolling`/`stopPolling`.
///
/// Coordinación entre providers:
///   Los providers no se referencian entre sí a través del mecanismo de
///   [ProxyProvider] de Flutter. La coordinación entre [AuthProvider] y
///   [MetricsProvider] ante un 401 se realiza indirectamente a través de
///   `ApiService` como singleton compartido (ver auth_provider.dart y
///   metrics_provider.dart para el detalle del flujo).
///
/// Orden de los providers en [MultiProvider]:
///   El orden es top-down. Aunque en esta implementación ningún provider usa
///   `context.read` sobre otro durante su construcción, [AuthProvider] se
///   registra primero por ser el de mayor prioridad arquitectónica. Si en el
///   futuro se añaden [ProxyProvider]s, el provider dependiente debe aparecer
///   después del que provee.
///
/// Qué NO debe contener este fichero:
///   - Lógica de negocio ni inicialización de servicios.
///   - Providers que no sean globales (los de alcance de pantalla se crean
///     en cada screen mediante su propio [ChangeNotifierProvider] local).
library;

import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/core/material_app.dart';
import 'package:metrics_servers_mobile/providers/auth_provider.dart';
import 'package:metrics_servers_mobile/providers/grupo_provider.dart';
import 'package:metrics_servers_mobile/providers/metrics_provider.dart';
import 'package:metrics_servers_mobile/providers/servidor_provider.dart';
import 'package:provider/provider.dart';

export 'auth_provider.dart';
export 'servidor_provider.dart';
export 'grupo_provider.dart';
export 'metrics_provider.dart';

/// Widget raíz que inyecta todos los providers globales en el árbol de widgets.
///
/// Responsabilidad:
///   Envolver [MonitoringApp] con [MultiProvider] para que todas las pantallas
///   de la aplicación tengan acceso a los cuatro providers globales mediante
///   `context.read<T>()` o `context.watch<T>()`.
///
/// Ciclo de vida:
///   Es un [StatelessWidget]: no tiene estado propio. Los providers se crean
///   mediante la función `create: (_)` de [ChangeNotifierProvider], que los
///   instancia de forma lazy la primera vez que son accedidos. En la práctica,
///   todos se instancian al arrancar la app porque [MonitoringApp] y las primeras
///   pantallas los consumen inmediatamente.
///
/// Relación con `main.dart`:
///   `main.dart` llama a `runApp(const Providers())`, lo que convierte a este
///   widget en la raíz del árbol completo de la aplicación.
class Providers extends StatelessWidget {
  const Providers({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // AuthProvider primero: gestiona la sesión activa y el token Bearer.
        // Su estado es consultado por las demás capas (aunque no directamente
        // por los otros providers en tiempo de construcción).
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        // ServidorProvider: lista paginada y catálogos de resolución de IDs.
        ChangeNotifierProvider(create: (_) => ServidorProvider()),

        // GrupoProvider: catálogo de grupos y permisos para la pantalla de admin.
        ChangeNotifierProvider(create: (_) => GrupoProvider()),

        // MetricsProvider: polling de métricas. Registrado globalmente para
        // que el estado del polling sobreviva a navegaciones internas.
        ChangeNotifierProvider(create: (_) => MetricsProvider()),
      ],
      // MonitoringApp contiene el enrutador y el tema; al ser hijo del
      // MultiProvider, todas sus pantallas descendientes tienen acceso a
      // los providers registrados arriba.
      child: const MonitoringApp(),
    );
  }
}
