import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/core/widgets/shared_widgets.dart';
import 'package:metrics_servers_mobile/models/model_grupo.dart';
import 'package:metrics_servers_mobile/providers/grupo_provider.dart';
import 'package:metrics_servers_mobile/routes/app_routes.dart';
import 'package:provider/provider.dart';

class GruposScreen extends StatelessWidget {
  const GruposScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final grupoProvider = context.read<GrupoProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de grupos')),
      body: FutureBuilder(
        future: grupoProvider.fetchAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingWidget(message: 'Cargando grupos…');
          }
          if (snapshot.hasError) {
            return AppErrorWidget(message: snapshot.error.toString());
          }
          return Consumer<GrupoProvider>(
            builder: (_, provider, __) {
              final grupos = provider.grupos;
              if (grupos.isEmpty) {
                return const EmptyStateWidget(
                  message: 'No hay grupos registrados',
                  icon: Icons.group_outlined,
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: grupos.length,
                itemBuilder: (_, i) => _GrupoCard(grupo: grupos[i]),
              );
            },
          );
        },
      ),
    );
  }
}

class _GrupoCard extends StatelessWidget {
  final Grupo grupo;
  const _GrupoCard({required this.grupo});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            Navigator.pushNamed(context, AppRoutes.detalleGrupo, arguments: grupo),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icono
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: grupo.superAdmin
                      ? const Color(0xFFE3B341).withOpacity(0.12)
                      : const Color(0xFF1F6FEB).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  grupo.superAdmin
                      ? Icons.admin_panel_settings
                      : Icons.group_outlined,
                  color: grupo.superAdmin
                      ? const Color(0xFFE3B341)
                      : const Color(0xFF1F6FEB),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            grupo.nombre,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15),
                          ),
                        ),
                        if (grupo.superAdmin)
                          const StatusBadge(
                              label: 'SUPERADMIN',
                              color: Color(0xFFE3B341)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      grupo.dn,
                      style: const TextStyle(
                          color: Color(0xFF8B949E), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (grupo.permisos != null) ...[
                      const SizedBox(height: 6),
                      _PermsSummary(permisos: grupo.permisos!),
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

class _PermsSummary extends StatelessWidget {
  final GrupoPermissionMap permisos;
  const _PermsSummary({required this.permisos});

  @override
  Widget build(BuildContext context) {
    final totalGlobal = permisos.global.length;
    final totalSections = permisos.sections.values
        .fold<int>(0, (acc, list) => acc + list.length);

    return Wrap(spacing: 6, children: [
      if (totalGlobal > 0)
        _MiniChip(
            label: '$totalGlobal global${totalGlobal != 1 ? "es" : ""}',
            color: const Color(0xFF388BFD)),
      if (totalSections > 0)
        _MiniChip(
            label: '$totalSections por sección',
            color: const Color(0xFF3FB950)),
    ]);
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 10)),
    );
  }
}
