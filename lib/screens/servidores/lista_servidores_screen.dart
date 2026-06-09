/// lista_servidores_screen.dart
///
/// Propósito:
///   Pantalla de listado paginado de servidores, agrupados por sección. Carga la
///   primera página al abrirse, permite scroll infinito para cargar páginas
///   adicionales, y ofrece búsqueda rápida mediante [ServidorSearchDelegate].
///   Opcionalmente puede abrirse directamente con la búsqueda activa si el
///   argumento de ruta es `true`.
///
/// Capa arquitectónica:
///   Capa de presentación — pantallas de servidores (screens/servidores/).
///
/// Clases definidas en este fichero:
///   - [ListaServidoresScreen]:      StatefulWidget raíz; gestiona scroll y carga.
///   - [_ListaServidoresScreenState]: Estado con ScrollController e inicialización.
///   - [_SeccionHeader]:             Cabecera de sección con nombre, descripción y contador.
///   - [ServidorCard]:               Tarjeta de servidor (pública; puede reutilizarse).
///   - [_InfoChip]:                  Chip compacto de información auxiliar de la tarjeta.
///
/// Argumento de ruta — apertura automática de búsqueda:
///   Si `ModalRoute.of(context)?.settings.arguments` es `true` (booleano), la
///   pantalla abre automáticamente el overlay de búsqueda ([showSearch]) al
///   terminar el primer frame. Este mecanismo lo usa la tile "Buscar servidor"
///   de [HomeScreen] para llevar al usuario directamente al modo de búsqueda.
///   Si el argumento es `false`, `null` o no es `bool`, la pantalla abre en modo
///   de lista normal.
///
/// Scroll infinito:
///   Un [ScrollController] escucha el evento de scroll. Cuando el usuario se
///   encuentra a menos de 300 px del fondo de la lista, se llama a
///   [ServidorProvider.loadNextPage] de forma preventiva (antes de que el usuario
///   llegue al final), creando la sensación de lista continua.
///
/// Agrupación por sección:
///   Los servidores se agrupan por `Servidor.seccion` (ID entero) usando un
///   [Map] que preserva el orden de inserción. Cada grupo genera un
///   [_SeccionHeader] y un [SliverList] de tarjetas. El ID se resuelve a
///   [Seccion] mediante `provider.seccionesCache`; si no se encuentra, la
///   cabecera muestra `"Sin sección"`.
///
/// Paginación y estados:
///   - `isLoading` → spinner de pantalla completa (primera página en curso).
///   - `error && servidores.isEmpty` → error con botón de reintento.
///   - `servidores.isEmpty` (sin carga ni error) → estado vacío.
///   - Con datos: lista agrupada con footer de paginación al final.
///   El footer muestra un spinner inline si `isLoadingMore` o un botón
///   "Cargar más" si `hasNext`, como fallback manual al scroll automático.
///
/// Diseño — Consumer envuelve el Scaffold completo:
///   A diferencia de otras pantallas, el [Consumer] envuelve el [Scaffold] entero
///   (no solo el body). Esto es necesario porque la acción de búsqueda del [AppBar]
///   necesita acceder a `provider` dentro del closure del Consumer para crear
///   el [ServidorSearchDelegate].
///
/// Qué NO debe contener este fichero:
///   - Llamadas HTTP directas (pertenecen a [ServidorProvider]).
///   - Lógica de detalle de servidor (pertenece a [DetalleServidorScreen]).
///   - Widgets reutilizables fuera del dominio de listado de servidores.
library;

import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/core/widgets/shared_widgets.dart';
import 'package:metrics_servers_mobile/models/model_seccion.dart';
import 'package:metrics_servers_mobile/models/model_servicio.dart';
import 'package:metrics_servers_mobile/models/model_servidor.dart';
import 'package:metrics_servers_mobile/providers/servidor_provider.dart';
import 'package:metrics_servers_mobile/routes/app_routes.dart';
import 'package:metrics_servers_mobile/screens/servidores/busqueda_servidores.dart';
import 'package:provider/provider.dart';

/// Pantalla de listado paginado de servidores agrupados por sección.
///
/// Responsabilidad:
///   Inicializar la carga de datos, gestionar el scroll infinito y componer la
///   UI a partir del estado del [ServidorProvider].
///
/// Ciclo de vida:
///   - [initState]: crea y adjunta el [ScrollController]; difiere la carga de
///     datos y la apertura automática de búsqueda al primer frame con
///     [WidgetsBinding.instance.addPostFrameCallback].
///   - [dispose]: libera el [ScrollController] para evitar memory leaks.
///   - [_onScroll]: carga la siguiente página cuando el scroll se acerca al fondo.
///
/// Relación con otros módulos:
///   - [ServidorProvider]: fuente de datos paginados, cachés y flags de estado.
///   - [ServidorSearchDelegate]: delegate de búsqueda; recibe el provider como parámetro.
///   - [DetalleServidorScreen]: destino de navegación al pulsar un [ServidorCard].
class ListaServidoresScreen extends StatefulWidget {
  const ListaServidoresScreen({super.key});

  @override
  State<ListaServidoresScreen> createState() => _ListaServidoresScreenState();
}

class _ListaServidoresScreenState extends State<ListaServidoresScreen> {
  /// Controlador de scroll para detectar cuándo cargar la siguiente página.
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // Se difiere la carga al primer frame para evitar llamar a métodos del
    // provider durante la fase de build del initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final srv = context.read<ServidorProvider>();
      // Carga los catálogos de servicios y secciones (no-op si ya están en caché).
      srv.preloadCaches();
      // Carga la primera página de servidores (no-op si ya hay datos en memoria).
      srv.loadFirstPage();

      // Argumento de ruta `true`: la tile "Buscar servidor" de HomeScreen activa
      // la apertura automática del overlay de búsqueda al entrar en la pantalla.
      final openSearch =
          ModalRoute.of(context)?.settings.arguments as bool? ?? false;
      if (openSearch) {
        showSearch(
          context: context,
          delegate: ServidorSearchDelegate(servidorProvider: srv),
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Carga la siguiente página cuando el usuario se acerca al final de la lista.
  ///
  /// El umbral de 300 px es preventivo: carga antes de que el usuario llegue
  /// al fondo visible, evitando que la lista "se detenga" esperando la respuesta.
  /// [ServidorProvider.loadNextPage] tiene guards internos contra re-entrada y
  /// contra llamadas cuando no hay más páginas.
  void _onScroll() {
    if (!mounted) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      context.read<ServidorProvider>().loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Consumer envuelve el Scaffold completo porque la acción de búsqueda del
    // AppBar necesita `provider` para instanciar ServidorSearchDelegate.
    return Consumer<ServidorProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Servidores'),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => showSearch(
                  context: context,
                  delegate: ServidorSearchDelegate(servidorProvider: provider),
                ),
              ),
            ],
          ),
          body: _buildBody(context, provider),
        );
      },
    );
  }

  /// Construye el cuerpo de la pantalla según el estado del [ServidorProvider].
  ///
  /// Prioridad de estados:
  ///   1. [ServidorProvider.isLoading]: primera página en curso → spinner.
  ///   2. Error con lista vacía: fallo en la carga inicial → error con reintento.
  ///   3. Lista vacía sin error: api-py no devuelve servidores → estado vacío.
  ///   4. Lista con datos: agrupación por sección + footer de paginación.
  ///
  /// El reintento invalida el estado del provider y relanza desde la primera página,
  /// lo que garantiza una carga limpia sin datos residuales de intentos anteriores.
  Widget _buildBody(BuildContext context, ServidorProvider provider) {
    if (provider.isLoading) {
      return const AppLoadingWidget(message: 'Cargando servidores…');
    }

    // Error en carga inicial: solo se muestra si la lista está vacía para no
    // ocultar datos previos cargados correctamente (si hay datos, el error de
    // un poll posterior es silencioso).
    if (provider.error != null && provider.servidores.isEmpty) {
      return AppErrorWidget(
        message: provider.error!,
        onRetry: () {
          provider.invalidate();
          provider.loadFirstPage();
        },
      );
    }

    if (provider.servidores.isEmpty) {
      return const EmptyStateWidget(
        message: 'No hay servidores disponibles',
        icon: Icons.dns_outlined,
      );
    }

    // Agrupación por ID de sección preservando el orden de inserción de la API.
    // Los servidores aparecen en el orden devuelto por api-py, agrupados por
    // su campo `seccion` (ID entero de clave foránea).
    final grupos = <int, List<Servidor>>{};
    for (final s in provider.servidores) {
      grupos.putIfAbsent(s.seccion, () => []).add(s);
    }

    return RefreshIndicator(
      onRefresh: () async {
        provider.invalidate();
        await provider.loadFirstPage();
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          for (final entry in grupos.entries) ...[
            // Cabecera de sección: nombre resuelto del caché + contador de
            // servidores en este grupo (no total de la sección en el sistema).
            SliverToBoxAdapter(
              child: _SeccionHeader(
                seccion: provider.seccionesCache[entry.key],
                count: entry.value.length,
              ),
            ),
            // Lista lazy de tarjetas de servidor para esta sección.
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => ServidorCard(
                  servidor: entry.value[i],
                  serviciosCache: provider.serviciosCache,
                  seccionesCache: provider.seccionesCache,
                ),
                childCount: entry.value.length,
              ),
            ),
          ],

          // ── Footer de paginación ─────────────────────────────────────────
          // El spinner aparece mientras se carga la siguiente página (activado
          // automáticamente por _onScroll). El botón es un fallback manual
          // por si el scroll automático no se disparó.
          if (provider.isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (provider.hasNext)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                child: OutlinedButton(
                  onPressed: () => provider.loadNextPage(),
                  child: const Text('Cargar más'),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}

// ── Cabecera de sección ────────────────────────────────────────────────────────

/// Cabecera visual de una sección de servidores en la lista.
///
/// Responsabilidad:
///   Mostrar el nombre, la descripción opcional y el conteo de servidores de
///   una sección, seguido de un divisor horizontal. Se inserta como
///   [SliverToBoxAdapter] entre grupos de tarjetas.
///
/// Fallback de nombre:
///   Si [seccion] es `null` (ID de sección no encontrado en el caché, o servidor
///   con `seccion == null`), el nombre mostrado es `'Sin sección'`.
///
/// Contador:
///   [count] es el número de servidores de esta sección en las páginas ya
///   cargadas, no el total de la sección en el sistema. Con más páginas por
///   cargar, el contador puede aumentar.
class _SeccionHeader extends StatelessWidget {
  /// Sección resuelta del caché, o `null` si el ID no tiene correspondencia.
  final Seccion? seccion;

  /// Número de servidores de esta sección en las páginas cargadas.
  final int count;

  const _SeccionHeader({required this.seccion, required this.count});

  @override
  Widget build(BuildContext context) {
    final nombre = seccion?.nombre ?? 'Sin sección';
    final descripcion = seccion?.descripcion;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.folder_outlined,
                size: 16,
                color: Color(0xFF1F6FEB),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  nombre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // Contador de servidores en esta sección (páginas cargadas).
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F6FEB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Color(0xFF1F6FEB),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          // Descripción opcional: solo se muestra si existe y no está vacía.
          // Sangría de 24 px para alinearse visualmente con el texto del nombre.
          if (descripcion != null && descripcion.isNotEmpty) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text(
                descripcion,
                style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 6),
          const Divider(color: Color(0xFF30363D), height: 1),
        ],
      ),
    );
  }
}

// ── Tarjeta de servidor ────────────────────────────────────────────────────────

/// Tarjeta de presentación de un servidor en el listado.
///
/// Responsabilidad:
///   Mostrar la imagen, hostname, DNS, sistema operativo (si disponible) y el
///   número de servicios del [servidor]. Al pulsar navega a [AppRoutes.detalleServidor]
///   pasando el objeto [Servidor] completo como argumento.
///
/// Visibilidad pública:
///   A diferencia del resto de widgets privados de este fichero, [ServidorCard]
///   es público (sin prefijo `_`) por si necesita instanciarse desde otros
///   contextos.
///
/// Parámetros [serviciosCache] y [seccionesCache]:
///   Se reciben como parámetro pero actualmente no se usan en el método [build]:
///   la tarjeta solo muestra el recuento de servicios (`servidor.servicios.length`),
///   no los nombres ni logos. Están declarados para una posible extensión futura
///   de la tarjeta (mostrar logos de servicios en línea, p. ej.).
class ServidorCard extends StatelessWidget {
  final Servidor servidor;

  /// Caché `id → Servicio`. Recibido pero actualmente no usado en el build.
  final Map<int, Servicio> serviciosCache;

  /// Caché `id → Seccion`. Recibido pero actualmente no usado en el build.
  final Map<int, Seccion> seccionesCache;

  const ServidorCard({
    super.key,
    required this.servidor,
    required this.serviciosCache,
    required this.seccionesCache,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(
          context,
          AppRoutes.detalleServidor,
          arguments: servidor,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // ── Imagen del servidor ──────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ServerImage(
                  imageUrl: servidor.imagenUrl,
                  width: 64,
                  height: 64,
                ),
              ),
              const SizedBox(width: 14),

              // ── Datos del servidor ───────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      servidor.hostname,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      servidor.dns,
                      style: const TextStyle(
                        color: Color(0xFF8B949E),
                        fontSize: 12,
                      ),
                    ),
                    // prettyOs solo se muestra si api-py lo incluyó en la respuesta.
                    if (servidor.prettyOs != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        servidor.prettyOs!,
                        style: const TextStyle(
                          color: Color(0xFF8B949E),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    // Chip de conteo de servicios: pluralización manual.
                    if (servidor.servicios.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _InfoChip(
                        icon: Icons.settings_outlined,
                        label:
                            '${servidor.servicios.length} servicio${servidor.servicios.length != 1 ? "s" : ""}',
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF8B949E)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chip de información ────────────────────────────────────────────────────────

/// Chip compacto con icono y etiqueta de texto para información auxiliar.
///
/// Responsabilidad:
///   Mostrar datos secundarios de un servidor (número de servicios) de forma
///   visual compacta dentro de [ServidorCard]. No es interactivo.
///
/// Estilo idéntico a [_HostnameChip] de lista_servicios_screen.dart:
/// fondo `0xFF21262D`, borde `0xFF30363D`, icono + texto en gris.
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

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
          Icon(icon, size: 11, color: const Color(0xFF8B949E)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
