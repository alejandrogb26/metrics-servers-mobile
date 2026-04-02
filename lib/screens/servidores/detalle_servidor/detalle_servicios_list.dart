import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/core/widgets/shared_widgets.dart';
import 'package:metrics_servers_mobile/models/model_servicio.dart';

class DetalleServiciosList extends StatelessWidget {
  final List<int> servicioIds;
  final Map<int, Servicio> serviciosCache;

  const DetalleServiciosList({
    super.key,
    required this.servicioIds,
    required this.serviciosCache,
  });

  @override
  Widget build(BuildContext context) {
    if (servicioIds.isEmpty) {
      return const Card(
        margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: 'Servicios', icon: Icons.settings_outlined),
              SizedBox(height: 8),
              Text('Sin servicios asociados',
                  style: TextStyle(color: Color(0xFF8B949E))),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
                title: 'Servicios asociados',
                icon: Icons.settings_outlined),
            // ── Tabla de servicios ─────────────────────────────────────────
            Table(
              columnWidths: const {
                0: FixedColumnWidth(48),
                1: FlexColumnWidth(),
                2: FixedColumnWidth(60),
              },
              children: [
                // Cabecera
                const TableRow(
                  decoration:
                      BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF30363D)))),
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('Logo',
                          style: TextStyle(
                              color: Color(0xFF8B949E), fontSize: 12)),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('Nombre',
                          style: TextStyle(
                              color: Color(0xFF8B949E), fontSize: 12)),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('ID',
                          style: TextStyle(
                              color: Color(0xFF8B949E), fontSize: 12)),
                    ),
                  ],
                ),
                // Filas de servicios
                ...servicioIds.map((id) {
                  final servicio = serviciosCache[id];
                  return TableRow(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF21262D)),
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: ServiceLogo(
                            logoUrl: servicio?.logo, size: 28),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          servicio?.nombre ?? 'Servicio $id',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          '#$id',
                          style: const TextStyle(
                              color: Color(0xFF8B949E), fontSize: 12),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
