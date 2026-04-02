import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/core/widgets/shared_widgets.dart';
import 'package:metrics_servers_mobile/models/model_servicio.dart';
import 'package:metrics_servers_mobile/models/model_servidor.dart';
import 'package:metrics_servers_mobile/providers/servidor_provider.dart';
import 'package:provider/provider.dart';

class ListaServiciosScreen extends StatelessWidget {
  const ListaServiciosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final srvProvider = context.read<ServidorProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Servicios')),
      body: FutureBuilder(
        future: srvProvider.preloadCaches(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingWidget(message: 'Cargando servicios…');
          }
          if (snapshot.hasError) {
            return AppErrorWidget(message: snapshot.error.toString());
          }

          return Consumer<ServidorProvider>(
            builder: (_, provider, __) {
              final servicios = provider.serviciosCache.values.toList()
                ..sort((a, b) => a.nombre.compareTo(b.nombre));

              if (servicios.isEmpty) {
                return const EmptyStateWidget(
                  message: 'No hay servicios registrados',
                  icon: Icons.settings_outlined,
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: servicios.length,
                itemBuilder: (_, i) => _ServicioTile(
                  servicio: servicios[i],
                  servidoresCache: provider.servidores,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ServicioTile extends StatelessWidget {
  final Servicio servicio;
  final List<Servidor> servidoresCache;

  const _ServicioTile({required this.servicio, required this.servidoresCache});

  @override
  Widget build(BuildContext context) {
    // Servidores que tienen este servicio
    final servidoresConServicio = servidoresCache
        .where((s) => s.servicios.contains(servicio.id))
        .toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // ── Logo ──────────────────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ServiceLogo(logoUrl: servicio.logo, size: 44),
            ),
            const SizedBox(width: 16),

            // ── Info ──────────────────────────────────────────────────────────
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
                  const SizedBox(height: 6),
                  // Servidores que usan este servicio
                  if (servidoresConServicio.isEmpty)
                    const Text(
                      'Sin servidores asignados',
                      style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: servidoresConServicio
                          .map((s) => _HostnameChip(hostname: s.hostname))
                          .toList(),
                    ),
                ],
              ),
            ),

            // ── ID ────────────────────────────────────────────────────────────
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
