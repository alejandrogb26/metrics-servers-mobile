import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/core/widgets/shared_widgets.dart';
import 'package:metrics_servers_mobile/models/model_grupo.dart';
import 'package:metrics_servers_mobile/providers/grupo_provider.dart';
import 'package:provider/provider.dart';

class DetalleGrupoScreen extends StatelessWidget {
  const DetalleGrupoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final grupo = ModalRoute.of(context)!.settings.arguments as Grupo;
    final grupoProvider = context.read<GrupoProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(grupo.nombre),
        actions: [
          if (grupo.superAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: StatusBadge(
                    label: 'SUPERADMIN', color: const Color(0xFFE3B341)),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info general ───────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                        title: 'Información del grupo',
                        icon: Icons.group_outlined),
                    InfoRow(
                        icon: Icons.badge_outlined,
                        label: 'ID',
                        value: grupo.id.toString()),
                    InfoRow(
                        icon: Icons.label_outline,
                        label: 'Nombre',
                        value: grupo.nombre),
                    InfoRow(
                        icon: Icons.account_tree_outlined,
                        label: 'DN (Distinguished Name)',
                        value: grupo.dn),
                    InfoRow(
                        icon: Icons.admin_panel_settings_outlined,
                        label: 'Superadmin',
                        value: grupo.superAdmin ? 'Sí' : 'No'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Permisos ───────────────────────────────────────────────────
            if (grupo.permisos != null) ...[
              // Permisos globales
              if (grupo.permisos!.global.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                            title: 'Permisos globales',
                            icon: Icons.public),
                        _PermisosTable(
                          permisoIds: grupo.permisos!.global,
                          grupoProvider: grupoProvider,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Permisos por sección
              if (grupo.permisos!.sections.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                            title: 'Permisos por sección',
                            icon: Icons.folder_outlined),
                        ...grupo.permisos!.sections.entries.map(
                          (entry) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.folder,
                                        size: 14,
                                        color: Color(0xFF8B949E)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Sección ${entry.key}',
                                      style: const TextStyle(
                                          color: Color(0xFF8B949E),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              _PermisosTable(
                                permisoIds: entry.value,
                                grupoProvider: grupoProvider,
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ] else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_open_outlined,
                          color: Color(0xFF8B949E)),
                      const SizedBox(width: 12),
                      const Text('Sin permisos asignados',
                          style: TextStyle(color: Color(0xFF8B949E))),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Tabla de permisos ──────────────────────────────────────────────────────────
class _PermisosTable extends StatelessWidget {
  final List<int> permisoIds;
  final GrupoProvider grupoProvider;

  const _PermisosTable({
    required this.permisoIds,
    required this.grupoProvider,
  });

  @override
  Widget build(BuildContext context) {
    if (permisoIds.isEmpty) {
      return const Text('Sin permisos',
          style: TextStyle(color: Color(0xFF8B949E), fontSize: 13));
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(3),
        2: FlexColumnWidth(1.5),
      },
      children: [
        // Cabecera
        const TableRow(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
          ),
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text('Nombre',
                  style: TextStyle(
                      color: Color(0xFF8B949E), fontSize: 11)),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text('Descripción',
                  style: TextStyle(
                      color: Color(0xFF8B949E), fontSize: 11)),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text('Ámbito',
                  style: TextStyle(
                      color: Color(0xFF8B949E), fontSize: 11)),
            ),
          ],
        ),
        // Filas
        ...permisoIds.map((id) {
          final permiso = grupoProvider.getPermisoById(id);
          return TableRow(
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFF21262D))),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  permiso?.nombre ?? '#$id',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  permiso?.descripcion ?? '-',
                  style: const TextStyle(
                      color: Color(0xFF8B949E), fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: permiso != null
                    ? StatusBadge(
                        label: permiso.ambito.nombre,
                        color: _ambitoColor(permiso.ambito.nombre),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          );
        }),
      ],
    );
  }

  Color _ambitoColor(String ambito) {
    switch (ambito.toUpperCase()) {
      case 'SERV':
        return const Color(0xFF388BFD);
      case 'USER':
        return const Color(0xFF3FB950);
      case 'SYS':
        return const Color(0xFFE3B341);
      default:
        return const Color(0xFF8B949E);
    }
  }
}
