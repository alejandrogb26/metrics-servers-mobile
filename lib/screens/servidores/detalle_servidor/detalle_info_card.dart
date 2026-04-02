import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/core/widgets/shared_widgets.dart';
import 'package:metrics_servers_mobile/models/model_seccion.dart';
import 'package:metrics_servers_mobile/models/model_servidor.dart';

class DetalleInfoCard extends StatelessWidget {
  final Servidor servidor;
  final Seccion? seccion;

  const DetalleInfoCard({
    super.key,
    required this.servidor,
    required this.seccion,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
                title: 'Información del sistema', icon: Icons.info_outline),
            InfoRow(
              icon: Icons.badge_outlined,
              label: 'Server ID',
              value: servidor.serverId,
            ),
            InfoRow(
              icon: Icons.computer,
              label: 'Hostname',
              value: servidor.hostname,
            ),
            InfoRow(
              icon: Icons.language,
              label: 'DNS',
              value: servidor.dns,
            ),
            if (servidor.prettyOs != null)
              InfoRow(
                icon: Icons.terminal,
                label: 'Sistema operativo',
                value: servidor.prettyOs!,
              ),
            if (servidor.arch != null)
              InfoRow(
                icon: Icons.memory,
                label: 'Arquitectura',
                value: servidor.arch!,
              ),
            if (servidor.kernel != null)
              InfoRow(
                icon: Icons.layers_outlined,
                label: 'Kernel',
                value: servidor.kernel!,
              ),
            if (seccion != null)
              InfoRow(
                icon: Icons.folder_outlined,
                label: 'Sección',
                value: seccion!.nombre +
                    (seccion!.descripcion != null
                        ? '\n${seccion!.descripcion}'
                        : ''),
              ),
          ],
        ),
      ),
    );
  }
}
