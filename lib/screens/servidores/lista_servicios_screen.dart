/// lista_servicios_screen.dart
///
/// Propósito:
///   Pantalla del catálogo de servicios monitorizados. Muestra todos los
///   [Servicio] registrados en api-py con su logo, nombre e ID, y debajo de cada
///   servicio los chips de hostname de los servidores cargados que lo usan.
///
/// Capa arquitectónica:
///   Capa de presentación — pantallas de servidores (screens/servidores/).
///
/// Clases definidas en este fichero:
///   - [ListaServiciosScreen]:      StatefulWidget raíz; gestiona la carga del catálogo.
///   - [_ListaServiciosScreenState]: Estado con FutureBuilder + Consumer.
///   - [_ServicioTile]:             Tarjeta de un servicio con sus servidores asociados.
///   - [_HostnameChip]:             Chip compacto con el hostname de un servidor.
///
/// Fuente de datos — preloadCaches:
///   Esta pantalla carga el catálogo de servicios llamando a
///   [ServidorProvider.preloadCaches], que también carga las secciones.
///   [preloadCaches] tiene un guard: si ambos cachés ya están poblados (p. ej.
///   porque el usuario pasó primero por [ListaServidoresScreen]), devuelve
///   inmediatamente sin realizar peticiones HTTP adicionales.
///
/// Patrón de carga — FutureBuilder + Consumer:
///   Idéntico al de [GruposScreen]:
///   1. [FutureBuilder] sobre [_future] (almacenado en estado): muestra spinner
///      mientras [preloadCaches] no completa. El Future se almacena en estado
///      para que rebuilds del widget no lo relancen.
///   2. [Consumer<ServidorProvider>]: una vez completado el Future, reacciona
///      a cambios posteriores del provider.
///   Los errores se detectan mediante `snapshot.hasError` (no `provider.error`)
///   porque [preloadCaches] no tiene try-catch interno y lanza excepciones
///   directamente al Future.
///
/// Asociación servicio → servidores (client-side):
///   [_ServicioTile] filtra `provider.servidores` (lista en memoria) para
///   encontrar los servidores que contienen el ID del servicio en su lista
///   `Servidor.servicios`. Esta asociación es client-side y solo cubre las
///   páginas de servidores ya cargadas. Si no se han cargado servidores (acceso
///   directo desde Home sin pasar por la lista de servidores), los chips de
///   hostname no aparecerán para ningún servicio.
///
/// Qué NO debe contener este fichero:
///   - Llamadas HTTP directas (pertenecen a ServicioService / ServidorProvider).
///   - Lógica de edición del catálogo de servicios.
///   - Widgets reutilizables fuera de esta pantalla.
library;

import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/core/widgets/shared_widgets.dart';
import 'package:metrics_servers_mobile/models/model_servicio.dart';
import 'package:metrics_servers_mobile/models/model_servidor.dart';
import 'package:metrics_servers_mobile/providers/servidor_provider.dart';
import 'package:provider/provider.dart';

/// Pantalla del catálogo de servicios con asociación a servidores.
///
/// Responsabilidad:
///   Cargar los cachés de servicios y secciones mediante [ServidorProvider.preloadCaches]
///   y mostrar la lista de servicios ordenada alfabéticamente, con los servidores
///   cargados que usan cada servicio como chips de hostname.
///
/// Ciclo de vida:
///   - [initState]: obtiene el provider con `context.read` y almacena el Future de
///     [preloadCaches] en [_future]. El guard interno de [preloadCaches] garantiza
///     que la carga sea un no-op si los cachés ya están en memoria.
///   - [_retry]: invalida el [_future] reemplazándolo con una nueva llamada a
///     [preloadCaches] mediante [setState], lo que re-dispara el [FutureBuilder].
///
/// Relación con otros módulos:
///   - [ServidorProvider.preloadCaches]: carga servicios y secciones en caché.
///   - [ServidorProvider.serviciosCache]: fuente de la lista de servicios a mostrar.
///   - [ServidorProvider.servidores]: lista de servidores cargados, usada por
///     [_ServicioTile] para calcular la asociación servicio → servidores.
class ListaServiciosScreen extends StatefulWidget {
  const ListaServiciosScreen({super.key});

  @override
  State<ListaServiciosScreen> createState() => _ListaServiciosScreenState();
}

class _ListaServiciosScreenState extends State<ListaServiciosScreen> {
  /// Future de la carga activa. Almacenado en estado para que los rebuilds
  /// del widget no relancen [preloadCaches].
  late Future<void> _future;

  /// Referencia directa al provider, obtenida con `context.read` en [initState].
  late ServidorProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<ServidorProvider>();
    _future = _provider.preloadCaches();
  }

  /// Relanza la carga de cachés.
  ///
  /// [preloadCaches] recargará ambos cachés siempre que al menos uno esté vacío.
  /// Si el error anterior dejó uno de los cachés parcialmente poblado, esta
  /// llamada los recarga a ambos (el guard de [preloadCaches] requiere que
  /// los dos estén no vacíos para omitir la carga).
  void _retry() {
    setState(() {
      _future = _provider.preloadCaches();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Servicios')),
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          // Mientras el Future no completa, mostrar spinner.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingWidget(message: 'Cargando servicios…');
          }
          // preloadCaches lanza excepciones directamente (sin try-catch interno),
          // por lo que los errores se detectan aquí con snapshot.hasError.
          if (snapshot.hasError) {
            return AppErrorWidget(
              message: 'Error al cargar servicios',
              onRetry: _retry,
            );
          }

          // Una vez cargado el caché, el Consumer reacciona a cambios posteriores.
          return Consumer<ServidorProvider>(
            builder: (context, provider, _) {
              // Ordenación alfabética por nombre en cada rebuild.
              // Se trabaja sobre una copia de los valores del mapa para no mutar el caché.
              final servicios = provider.serviciosCache.values.toList()
                ..sort((a, b) => a.nombre.compareTo(b.nombre));

              if (servicios.isEmpty) {
                return const EmptyStateWidget(
                  message: 'No hay servicios registrados',
                  icon: Icons.settings_outlined,
                );
              }

              return RefreshIndicator(
                onRefresh: () async => _retry(),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: servicios.length,
                  // Se pasa provider.servidores para la asociación client-side
                  // servicio → servidores (solo los ya cargados en memoria).
                  itemBuilder: (_, i) => _ServicioTile(
                    servicio: servicios[i],
                    servidoresCargados: provider.servidores,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Tarjeta de servicio ────────────────────────────────────────────────────────

/// Tarjeta de un servicio del catálogo con sus servidores asociados.
///
/// Responsabilidad:
///   Mostrar el logo, nombre e ID del [servicio], y debajo una fila de chips
///   [_HostnameChip] para cada servidor de [servidoresCargados] que use el servicio.
///
/// Asociación servicio → servidores:
///   Se filtra [servidoresCargados] buscando aquellos cuya lista `Servidor.servicios`
///   contiene `servicio.id`. Esta operación es O(n × m) donde n = número de
///   servidores cargados y m = número de servicios por servidor.
///
/// Limitación de alcance:
///   [servidoresCargados] son únicamente las páginas cargadas en memoria
///   ([ServidorProvider.servidores]). Si el usuario no navegó por la lista
///   de servidores antes de abrir esta pantalla, la lista estará vacía y
///   ningún servicio mostrará chips de hostname. No hay aviso de esta limitación.
class _ServicioTile extends StatelessWidget {
  final Servicio servicio;

  /// Lista de servidores cargados en memoria (puede ser subconjunto del total).
  final List<Servidor> servidoresCargados;

  const _ServicioTile({
    required this.servicio,
    required this.servidoresCargados,
  });

  @override
  Widget build(BuildContext context) {
    // Filtro client-side: servidores que tienen este servicio en su lista de IDs.
    final coincidentes = servidoresCargados
        .where((s) => s.servicios.contains(servicio.id))
        .toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // ── Logo del servicio ────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ServiceLogo(logoUrl: servicio.logo, size: 44),
            ),
            const SizedBox(width: 16),

            // ── Nombre y chips de servidores ─────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    servicio.nombre,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  // Los chips solo se muestran si hay servidores cargados que
                  // usen este servicio. Si coincidentes está vacío, el nombre
                  // aparece solo sin espacio adicional.
                  if (coincidentes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: coincidentes
                          .map((s) => _HostnameChip(hostname: s.hostname))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),

            // ── ID del servicio ───────────────────────────────────────────
            // Mostrado en gris tenue como referencia técnica, no información primaria.
            Text(
              '#${servicio.id}',
              style: const TextStyle(color: Color(0xFF484F58), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chip de hostname ───────────────────────────────────────────────────────────

/// Chip compacto con icono DNS y hostname de un servidor.
///
/// Responsabilidad:
///   Identificar visualmente un servidor asociado a un servicio dentro de
///   [_ServicioTile]. No es interactivo: solo muestra información, no navega.
///
/// Estilo: fondo `0xFF21262D` (nivel 3 de la paleta GitHub Dark), borde gris,
/// icono DNS de 11 px + texto gris de 11 px. Similar a [_MiniChip] de
/// grupos_screen.dart pero con prefijo de icono en lugar de solo color.
class _HostnameChip extends StatelessWidget {
  final String hostname;

  const _HostnameChip({required this.hostname});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.dns_outlined, size: 11, color: Color(0xFF8B949E)),
          const SizedBox(width: 4),
          Text(
            hostname,
            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
