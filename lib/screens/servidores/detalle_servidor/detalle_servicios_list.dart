/// detalle_servicios_list.dart
///
/// Propósito:
///   Tarjeta de la lista de servicios asociados a un servidor dentro de la
///   pantalla de detalle. Recibe los IDs de servicio del servidor y el caché
///   de objetos [Servicio] para resolverlos, y los renderiza como una tabla
///   con logo, nombre e ID.
///
/// Capa arquitectónica:
///   Capa de presentación — componente de detalle de servidor
///   (screens/servidores/detalle_servidor/).
///   Es un widget de presentación pura: no accede a providers ni realiza
///   peticiones HTTP. La resolución de IDs ocurre en este widget usando el
///   caché recibido como parámetro.
///
/// Patrón de resolución de IDs:
///   [Servidor.servicios] es una `List<int>` de claves foráneas. Este widget
///   recibe esa lista junto con `Map<int, Servicio> serviciosCache` (de
///   `ServidorProvider.serviciosCache`) y resuelve cada ID mediante lookup O(1)
///   en el mapa. Si el ID no existe en el caché, se usa un fallback textual.
///
/// Estado vacío:
///   Si [servicioIds] está vacío se renderiza una tarjeta simplificada con el
///   texto "Sin servicios asociados". El título de la cabecera cambia de
///   "Servicios asociados" (con datos) a "Servicios" (estado vacío).
///
/// Qué NO debe contener este fichero:
///   - Acceso a providers ni peticiones HTTP.
///   - Lógica de navegación.
///   - Presentación de datos de otras entidades (métricas, sección, etc.).
library;

import 'package:flutter/material.dart';
import 'package:metrics_servers_mobile/core/widgets/shared_widgets.dart';
import 'package:metrics_servers_mobile/models/model_servicio.dart';

/// Tarjeta con la lista de servicios asociados a un servidor.
///
/// Responsabilidad:
///   Mostrar en una [Table] de tres columnas (logo, nombre, ID) los servicios
///   cuyo ID aparece en [servicioIds], resolviendo cada ID al objeto [Servicio]
///   correspondiente mediante [serviciosCache].
///
/// Estructura de la tabla:
///   - Columna 0 — Logo:   [FixedColumnWidth] 48 px; contiene [ServiceLogo].
///   - Columna 1 — Nombre: [FlexColumnWidth] (espacio restante); nombre del servicio.
///   - Columna 2 — ID:     [FixedColumnWidth] 60 px; ID numérico con prefijo `#`.
///
/// Fallback por servicio no encontrado en caché:
///   Si `serviciosCache[id]` devuelve `null` (caché no cargado o ID inexistente):
///   - Nombre: `'Servicio $id'` como referencia textual al ID.
///   - Logo: `ServiceLogo(logoUrl: null)` muestra el placeholder del widget.
///
/// Relación con otros módulos:
///   - [DetalleServidorScreen]: instancia este widget pasando
///     `servidor.servicios` como [servicioIds] y
///     `ServidorProvider.serviciosCache` como [serviciosCache].
///   - [ServiceLogo]: widget compartido que carga la imagen del logo desde URL
///     o muestra un placeholder si la URL es `null` o falla la carga.
class DetalleServiciosList extends StatelessWidget {
  /// Lista de IDs de servicio del servidor ([Servidor.servicios]).
  final List<int> servicioIds;

  /// Caché `id → Servicio` para resolución O(1).
  /// Proviene de [ServidorProvider.serviciosCache].
  final Map<int, Servicio> serviciosCache;

  const DetalleServiciosList({
    super.key,
    required this.servicioIds,
    required this.serviciosCache,
  });

  @override
  Widget build(BuildContext context) {
    // Estado vacío: el servidor no tiene servicios asociados.
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
              Text(
                'Sin servicios asociados',
                style: TextStyle(color: Color(0xFF8B949E)),
              ),
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
              icon: Icons.settings_outlined,
            ),
            // ── Tabla de servicios ────────────────────────────────────────
            Table(
              columnWidths: const {
                0: FixedColumnWidth(
                  48,
                ), // Logo: ancho fijo para iconos uniformes
                1: FlexColumnWidth(), // Nombre: ocupa el espacio restante
                2: FixedColumnWidth(60), // ID: ancho fijo para el badge #id
              },
              children: [
                // Fila de cabecera con borde inferior como separador.
                const TableRow(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF30363D)),
                    ),
                  ),
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Logo',
                        style: TextStyle(
                          color: Color(0xFF8B949E),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Nombre',
                        style: TextStyle(
                          color: Color(0xFF8B949E),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'ID',
                        style: TextStyle(
                          color: Color(0xFF8B949E),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                // Una fila por cada ID de servicio.
                // Si el ID no está en el caché, se usan los fallbacks descritos.
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
                        // Si servicio es null, logoUrl es null y ServiceLogo
                        // muestra su placeholder interno.
                        child: ServiceLogo(logoUrl: servicio?.logo, size: 28),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        // Fallback: "Servicio {id}" si el ID no está en el caché.
                        child: Text(
                          servicio?.nombre ?? 'Servicio $id',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        // ID numérico con prefijo # para referencia/depuración.
                        child: Text(
                          '#$id',
                          style: const TextStyle(
                            color: Color(0xFF8B949E),
                            fontSize: 12,
                          ),
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
