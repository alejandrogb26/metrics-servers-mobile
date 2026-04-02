import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/core/widgets/shared_widgets.dart';
import 'package:metrics_servers_mobile/models/model_seccion.dart';
import 'package:metrics_servers_mobile/models/model_servicio.dart';
import 'package:metrics_servers_mobile/models/model_servidor.dart';
import 'package:metrics_servers_mobile/providers/auth_provider.dart';
import 'package:metrics_servers_mobile/providers/servidor_provider.dart';
import 'package:metrics_servers_mobile/routes/app_routes.dart';
import 'package:metrics_servers_mobile/screens/servidores/busqueda_servidores.dart';
import 'package:provider/provider.dart';

class ListaServidoresScreen extends StatefulWidget {
  const ListaServidoresScreen({super.key});

  @override
  State<ListaServidoresScreen> createState() => _ListaServidoresScreenState();
}

class _ListaServidoresScreenState extends State<ListaServidoresScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final srv = context.read<ServidorProvider>();
      srv.preloadCaches();
      // Si se pasa arguments: true, abrir búsqueda directamente
      final openSearch =
          ModalRoute.of(context)?.settings.arguments as bool? ?? false;
      if (openSearch) {
        showSearch(
          context: context,
          delegate: ServidorSearchDelegate(
            servidorProvider: context.read<ServidorProvider>(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final srvProvider = context.read<ServidorProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Servidores'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => showSearch(
              context: context,
              delegate: ServidorSearchDelegate(servidorProvider: srvProvider),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Servidor>>(
        future: srvProvider.fetchAll(auth),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingWidget(message: 'Cargando servidores…');
          }
          if (snapshot.hasError) {
            return AppErrorWidget(
              message: snapshot.error.toString(),
              onRetry: () {
                srvProvider.invalidate();
                setState(() {});
              },
            );
          }
          final servidores = snapshot.data ?? [];
          if (servidores.isEmpty) {
            return const EmptyStateWidget(
              message: 'No hay servidores disponibles',
              icon: Icons.dns_outlined,
            );
          }

          return Consumer<ServidorProvider>(
            builder: (_, provider, __) {
              // Agrupar servidores por sección manteniendo el orden de aparición
              final grupos = <int, List<Servidor>>{};
              for (final s in provider.servidores) {
                grupos.putIfAbsent(s.seccion, () => []).add(s);
              }

              return RefreshIndicator(
                onRefresh: () async {
                  provider.invalidate();
                  await provider.fetchAll(auth);
                },
                child: CustomScrollView(
                  slivers: [
                    for (final entry in grupos.entries) ...[
                      // ── Cabecera de sección ──────────────────────────────
                      SliverToBoxAdapter(
                        child: _SeccionHeader(
                          seccion: provider.seccionesCache[entry.key],
                          count: entry.value.length,
                        ),
                      ),
                      // ── Servidores de esa sección ────────────────────────
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
                    // Padding inferior
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Cabecera de sección ────────────────────────────────────────────────────────
class _SeccionHeader extends StatelessWidget {
  final Seccion? seccion;
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F6FEB).withOpacity(0.12),
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
class ServidorCard extends StatelessWidget {
  final Servidor servidor;
  final Map<int, Servicio> serviciosCache;
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
              // ── Imagen ─────────────────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ServerImage(
                  imageUrl: servidor.imagenUrl,
                  width: 64,
                  height: 64,
                ),
              ),
              const SizedBox(width: 14),

              // ── Info ───────────────────────────────────────────────────────
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
