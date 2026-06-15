/// detalle_servidor_screen.dart
///
/// Propósito:
///   Pantalla de detalle completo de un servidor. Muestra una cabecera visual
///   con la imagen del servidor (colapsable al hacer scroll), el estado de
///   conexión, la tarjeta de información técnica, la lista de servicios asociados
///   y un botón de acceso directo a la pantalla de métricas en tiempo real.
///
/// Capa arquitectónica:
///   Capa de presentación — pantallas de detalle de servidor
///   (screens/servidores/detalle_servidor/).
///
/// Patrón de scroll — CustomScrollView con SliverAppBar:
///   La pantalla usa un [CustomScrollView] con dos slivers:
///   1. [SliverAppBar] con `expandedHeight: 220` y `pinned: true`: cabecera
///      colapsable que contiene la imagen del servidor y el nombre como título.
///      Al hacer scroll, colapsa hasta la altura estándar de AppBar pero
///      permanece visible en la parte superior (`pinned`).
///   2. [SliverList] con [SliverChildListDelegate]: lista plana de widgets de
///      contenido (chip de estado, tarjetas y botón de métricas).
///
/// Recepción de datos:
///   - [Servidor]: recibido como argumento de ruta desde [ListaServidoresScreen].
///     El cast directo lanzará [TypeError] si se navega sin argumento.
///   - [Seccion]: resuelta sincrónicamente de `ServidorProvider.seccionesCache`
///     con `context.read`. Si el caché no está cargado, el valor es `null`.
///   - [Map] de servicios: `ServidorProvider.serviciosCache`, pasado directamente
///     a [DetalleServiciosList] para que resuelva los IDs de `Servidor.servicios`.
///
/// Diseño — StatelessWidget con context.read:
///   No necesita suscribirse a cambios del provider porque todos los datos que
///   usa (caché de secciones y servicios) se leen una sola vez al construir la
///   pantalla. Si los cachés se actualizasen, la pantalla no reflejaría los
///   nuevos datos sin ser reconstruida.
///
/// Navegación a métricas:
///   Hay dos puntos de acceso a [MetricasScreen], ambos pasando el mismo
///   [Servidor] como argumento:
///   - Botón en las acciones del [SliverAppBar] (icono de gráfica, siempre visible
///     incluso con la cabecera colapsada).
///   - [ElevatedButton] al pie del contenido (prominente, para el primer acceso).
///
/// Imagen de cabecera:
///   Usa `servidor.imagenUrl` (URL completa) con [FadeInImage.assetNetwork] y
///   placeholder `assets/no_image.png`. Si la URL es nula, vacía o la carga
///   falla, se muestra [_defaultBg] (fondo oscuro con icono de servidor).
///   Un gradiente vertical semitransparente cubre la imagen para garantizar
///   la legibilidad del título sobre cualquier imagen.
///
/// Qué NO debe contener este fichero:
///   - Llamadas HTTP directas.
///   - Lógica de edición o eliminación de servidores.
///   - Subwidgets reutilizables fuera de esta pantalla (pertenecen a
///     detalle_info_card.dart, detalle_servicios_list.dart o shared_widgets.dart).
library;

import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/core/widgets/shared_widgets.dart';
import 'package:metrics_servers_mobile/models/model_servidor.dart';
import 'package:metrics_servers_mobile/providers/servidor_provider.dart';
import 'package:metrics_servers_mobile/routes/app_routes.dart';
import 'package:metrics_servers_mobile/screens/servidores/detalle_servidor/detalle_info_card.dart';
import 'package:metrics_servers_mobile/screens/servidores/detalle_servidor/detalle_servicios_list.dart';
import 'package:provider/provider.dart';

/// Pantalla de detalle completo de un servidor con cabecera colapsable.
///
/// Responsabilidad:
///   Componer las tarjetas de detalle ([DetalleInfoCard], [DetalleServiciosList])
///   con una cabecera visual de imagen y gestionar la navegación a [MetricasScreen].
///
/// Diseño — StatelessWidget:
///   Todos los datos necesarios se obtienen sincrónicamente:
///   - El [Servidor] viene del argumento de ruta (objeto completo, ya cargado).
///   - Los cachés de secciones y servicios se leen del provider sin suscripción
///     (`context.read`), ya que la pantalla no necesita reconstruirse cuando
///     el provider cambia.
///
/// Relación con otros módulos:
///   - [ListaServidoresScreen]: pantalla origen; pasa el [Servidor] como argumento.
///   - [DetalleInfoCard]:       muestra los datos técnicos del servidor.
///   - [DetalleServiciosList]:  muestra los servicios asociados.
///   - [MetricasScreen]:        destino de navegación; recibe el mismo [Servidor].
///   - [ServidorProvider]:      fuente de los cachés de secciones y servicios.
class DetalleServidorScreen extends StatelessWidget {
  const DetalleServidorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // El Servidor se obtiene del argumento de ruta. El cast lanzará TypeError
    // si la pantalla se navega sin argumento o con un tipo incorrecto.
    final servidor = ModalRoute.of(context)!.settings.arguments as Servidor;

    // context.read: se leen los cachés una sola vez sin suscripción.
    // Si preloadCaches no se ejecutó previamente, ambas operaciones de lookup
    // devolverán null/mapa vacío silenciosamente.
    final srvProvider = context.read<ServidorProvider>();
    // Lookup O(1) del objeto Seccion usando el ID de clave foránea del servidor.
    final seccion = srvProvider.seccionesCache[servidor.seccion];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar colapsable con imagen ─────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            // pinned: true → la AppBar permanece visible (colapsada) al hacer scroll.
            pinned: true,
            backgroundColor: const Color(0xFF161B22),
            actions: [
              // Botón de métricas en la AppBar: accesible incluso con la
              // cabecera colapsada.
              IconButton(
                tooltip: 'Ver métricas',
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F6FEB).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF1F6FEB).withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Icon(
                    Icons.area_chart,
                    color: Color(0xFF1F6FEB),
                    size: 20,
                  ),
                ),
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.metricas,
                  arguments: servidor,
                ),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                servidor.hostname,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              background: Stack(
                // Obliga a todos tus hijos a estirarse y ocupar exactamente el mismo tamaño
                // que tiene la cabecera (los 220 píxeles de alto)".
                fit: StackFit.expand,
                children: [
                  // Imagen del servidor: usa imagenUrl (URL completa).
                  // Fallback a _defaultBg() si la URL es nula/vacía o la carga falla.
                  if (servidor.imagenUrl != null &&
                      servidor.imagenUrl!.isNotEmpty)
                    FadeInImage.assetNetwork(
                      placeholder: 'assets/no_image.png',
                      image: servidor.imagenUrl!,
                      fit: BoxFit.cover,
                      imageErrorBuilder: (context, error, _) => _defaultBg(),
                    )
                  else
                    _defaultBg(),
                  // Gradiente vertical sobre la imagen: asegura que el título
                  // blanco sea legible sobre cualquier imagen de servidor.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        // 0xCC = ~80% de opacidad; suficiente para leer el texto
                        // sin ocultar completamente la imagen.
                        colors: [Colors.transparent, Color(0xCC161B22)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Contenido de la pantalla ───────────────────────────────────
          SliverList(
            // SliverChildListDelegate para una lista plana de widgets conocidos
            // en tiempo de compilación (no requiere lazy building).
            delegate: SliverChildListDelegate([
              // Chip de estado — siempre muestra "En línea" (estado hardcodeado;
              // no refleja el estado real del servidor en tiempo real).
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 10,
                      color: Color(0xFF3FB950),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'En línea',
                      style: TextStyle(color: Color(0xFF3FB950), fontSize: 12),
                    ),
                    const Spacer(),
                    // Badge con el serverId como referencia de identificación rápida.
                    StatusBadge(
                      label: servidor.serverId,
                      color: const Color(0xFF8B949E),
                    ),
                  ],
                ),
              ),

              // Tarjeta de información técnica: Server ID, hostname, DNS, SO,
              // arquitectura, kernel y sección resuelta.
              DetalleInfoCard(servidor: servidor, seccion: seccion),

              // Lista de servicios asociados: resuelve servidor.servicios (List<int>)
              // usando serviciosCache para obtener los objetos Servicio completos.
              DetalleServiciosList(
                servicioIds: servidor.servicios,
                serviciosCache: srvProvider.serviciosCache,
              ),

              // Botón de acceso a métricas: alternativa al botón del AppBar,
              // más prominente y contextualizado al final del detalle.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.area_chart),
                  label: const Text('Ver métricas en tiempo real'),
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.metricas,
                    arguments: servidor,
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  /// Fondo por defecto para el [SliverAppBar] cuando no hay imagen disponible.
  ///
  /// Se usa en dos situaciones:
  /// 1. `servidor.imagenUrl` es `null` o vacía.
  /// 2. La imagen de red falla al cargar (`imageErrorBuilder`).
  Widget _defaultBg() {
    return Container(
      color: const Color(0xFF0D1117),
      child: const Center(
        child: Icon(Icons.dns_outlined, size: 80, color: Color(0xFF21262D)),
      ),
    );
  }
}
