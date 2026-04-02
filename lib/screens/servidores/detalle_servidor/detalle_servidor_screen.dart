import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/core/widgets/shared_widgets.dart';
import 'package:metrics_servers_mobile/models/model_servidor.dart';
import 'package:metrics_servers_mobile/providers/servidor_provider.dart';
import 'package:metrics_servers_mobile/routes/app_routes.dart';
import 'package:metrics_servers_mobile/screens/servidores/detalle_servidor/detalle_info_card.dart';
import 'package:metrics_servers_mobile/screens/servidores/detalle_servidor/detalle_servicios_list.dart';
import 'package:provider/provider.dart';

class DetalleServidorScreen extends StatelessWidget {
  const DetalleServidorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final servidor = ModalRoute.of(context)!.settings.arguments as Servidor;
    final srvProvider = context.read<ServidorProvider>();
    final seccion = srvProvider.seccionesCache[servidor.seccion];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar con imagen ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: const Color(0xFF161B22),
            actions: [
              // Botón → pantalla de métricas
              IconButton(
                tooltip: 'Ver métricas',
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F6FEB).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF1F6FEB).withOpacity(0.5),
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
                fit: StackFit.expand,
                children: [
                  // Imagen del servidor
                  if (servidor.imagenUrl != null &&
                      servidor.imagenUrl!.isNotEmpty)
                    FadeInImage.assetNetwork(
                      placeholder: 'assets/no_image.png',
                      image: servidor.imagenUrl!,
                      fit: BoxFit.cover,
                      imageErrorBuilder: (_, __, ___) => _defaultBg(),
                    )
                  else
                    _defaultBg(),
                  // Gradiente inferior
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC161B22)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Contenido ────────────────────────────────────────────────────
          SliverList(
            delegate: SliverChildListDelegate([
              // Chip de estado
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
                    StatusBadge(
                      label: servidor.serverId,
                      color: const Color(0xFF8B949E),
                    ),
                  ],
                ),
              ),

              // Tarjeta de información
              DetalleInfoCard(servidor: servidor, seccion: seccion),

              // Tabla de servicios
              DetalleServiciosList(
                servicioIds: servidor.servicios,
                serviciosCache: srvProvider.serviciosCache,
              ),

              // Botón grande a métricas
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

  Widget _defaultBg() {
    return Container(
      color: const Color(0xFF0D1117),
      child: const Center(
        child: Icon(Icons.dns_outlined, size: 80, color: Color(0xFF21262D)),
      ),
    );
  }
}
